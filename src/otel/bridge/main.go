// otel-bridge streams logs from the Kurtosis engine's GetServiceLogs
// gRPC RPC and inserts them into ClickHouse via HTTP using the OTel-logs schema.
//
// Self-discovery: at startup, finds the engine via /proc/net/route default gateway,
// then calls engine.GetEnclaves() and each enclave's API container GetServices()
// to identify which enclave it is running in (by matching its own IPv4 to a
// service's private_ip_addr). The matched service UUID is the self-exclusion key.
//
// Restart semantics: bridge restart replays history with return_all_logs=true.
// The ClickHouse table is ReplacingMergeTree keyed on a content-aware ORDER BY,
// so duplicates collapse at merge time. Queries needing strict dedup use FINAL.
package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"connectrpc.com/connect"
	apic "github.com/kurtosis-tech/kurtosis/api/golang/core/kurtosis_core_rpc_api_bindings"
	apicconnect "github.com/kurtosis-tech/kurtosis/api/golang/core/kurtosis_core_rpc_api_bindings/kurtosis_core_rpc_api_bindingsconnect"
	engineapi "github.com/kurtosis-tech/kurtosis/api/golang/engine/kurtosis_engine_rpc_api_bindings"
	engineconnect "github.com/kurtosis-tech/kurtosis/api/golang/engine/kurtosis_engine_rpc_api_bindings/kurtosis_engine_rpc_api_bindingsconnect"
	"golang.org/x/net/http2"
	"google.golang.org/protobuf/types/known/emptypb"
)

const (
	servicePollInterval = 10 * time.Second
	batchMaxRecords     = 1000
	batchMaxBytes       = 5 * 1024 * 1024
	batchMaxAge         = 5 * time.Second
	channelCapacity     = 10000
	streamBackoffMin    = 1 * time.Second
	streamBackoffMax    = 30 * time.Second
	chHTTPTimeout       = 15 * time.Second
	chReadyTimeout      = 2 * time.Minute
)

type otelLogRecord struct {
	Timestamp          string            `json:"Timestamp"`
	ServiceName        string            `json:"ServiceName"`
	Body               string            `json:"Body"`
	ResourceAttributes map[string]string `json:"ResourceAttributes"`
	LogAttributes      map[string]string `json:"LogAttributes"`
}

type serviceMeta struct {
	uuid string
	name string
}

type config struct {
	engineEndpoint     string
	clickhouseEndpoint string
	excludeNames       map[string]bool
}

func main() {
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)

	cfg := loadConfig()
	log.Printf("config: engine=%s clickhouse=%s exclude=%v",
		cfg.engineEndpoint, cfg.clickhouseEndpoint, mapKeys(cfg.excludeNames))

	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		s := <-sigCh
		log.Printf("received %s, shutting down", s)
		cancel()
	}()

	httpClient := newHTTP2Client()
	engineClient := engineconnect.NewEngineServiceClient(httpClient, cfg.engineEndpoint)

	log.Printf("probing engine at %s", cfg.engineEndpoint)
	if err := waitForEngine(ctx, engineClient); err != nil {
		log.Fatalf("engine not reachable at %s: %v", cfg.engineEndpoint, err)
	}
	log.Printf("engine reachable")

	log.Printf("waiting for ClickHouse at %s", cfg.clickhouseEndpoint)
	if err := waitForClickHouse(ctx, cfg.clickhouseEndpoint); err != nil {
		log.Fatalf("clickhouse not ready: %v", err)
	}
	log.Printf("ClickHouse ready")

	enclaveUUID, enclaveName, ownUUID, err := discoverSelf(ctx, engineClient, httpClient)
	if err != nil {
		log.Fatalf("self-discovery: %v", err)
	}
	log.Printf("self-discovered: enclave=%s (%s), own_service_uuid=%s",
		enclaveName, enclaveUUID, ownUUID)

	records := make(chan otelLogRecord, channelCapacity)
	var writerWg sync.WaitGroup
	writerWg.Add(1)
	go func() {
		defer writerWg.Done()
		runWriter(ctx, cfg.clickhouseEndpoint, records)
	}()

	// streamWg tracks every stream goroutine started inside runServiceMux. We
	// must drain them all before closing records, otherwise a worker still
	// mid-send hits "send on closed channel".
	var streamWg sync.WaitGroup
	runServiceMux(ctx, engineClient, httpClient, enclaveUUID, enclaveName, ownUUID, cfg.excludeNames, records, &streamWg)
	streamWg.Wait()

	close(records)
	writerWg.Wait()
	log.Printf("shutdown complete")
}

func loadConfig() config {
	endpoint := os.Getenv("KURTOSIS_ENGINE_ENDPOINT")
	if endpoint == "" {
		gw, err := defaultGateway()
		if err != nil {
			log.Fatalf("could not discover default gateway for engine endpoint: %v", err)
		}
		endpoint = fmt.Sprintf("http://%s:9710", gw)
	}
	excludeRaw := getenv("BRIDGE_EXCLUDE_NAMES", "otel-clickhouse,otel-bridge")
	exclude := map[string]bool{}
	for _, n := range strings.Split(excludeRaw, ",") {
		if n = strings.TrimSpace(n); n != "" {
			exclude[n] = true
		}
	}
	return config{
		engineEndpoint:     endpoint,
		clickhouseEndpoint: getenv("CLICKHOUSE_ENDPOINT", "http://otel-clickhouse:8123"),
		excludeNames:       exclude,
	}
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func mapKeys(m map[string]bool) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

// defaultGateway returns the IPv4 address of the container's default gateway,
// which on Docker bridge networks is the host where the Kurtosis engine has its
// port published. Reads /proc/net/route directly so the binary stays static.
func defaultGateway() (string, error) {
	f, err := os.Open("/proc/net/route")
	if err != nil {
		return "", err
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Scan() // header
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) < 4 || fields[1] != "00000000" {
			continue
		}
		raw, err := hex.DecodeString(fields[2])
		if err != nil || len(raw) != 4 {
			continue
		}
		return net.IPv4(raw[3], raw[2], raw[1], raw[0]).String(), nil
	}
	return "", errors.New("no default route in /proc/net/route")
}

// newHTTP2Client returns an HTTP client that speaks h2c so ConnectRPC streaming
// works against Kurtosis engines published over plain HTTP.
func newHTTP2Client() *http.Client {
	return &http.Client{
		Transport: &http2.Transport{
			AllowHTTP: true,
			DialTLSContext: func(ctx context.Context, network, addr string, _ *tls.Config) (net.Conn, error) {
				var d net.Dialer
				return d.DialContext(ctx, network, addr)
			},
		},
	}
}

// discoverSelf enumerates running enclaves, dials each one's API container, and
// finds the service whose private IP matches one of the bridge's own IPv4s.
func discoverSelf(ctx context.Context, engineClient engineconnect.EngineServiceClient, httpClient *http.Client) (string, string, string, error) {
	ownIPs, err := ownIPv4s()
	if err != nil {
		return "", "", "", fmt.Errorf("own ipv4s: %w", err)
	}
	log.Printf("own IPv4 addresses: %v", mapKeys(ownIPs))

	backoff := time.Second
	deadline := time.Now().Add(2 * time.Minute)
	for time.Now().Before(deadline) {
		if ctx.Err() != nil {
			return "", "", "", ctx.Err()
		}

		resp, err := engineClient.GetEnclaves(ctx, connect.NewRequest(&emptypb.Empty{}))
		if err != nil {
			log.Printf("GetEnclaves: %v (retry in %s)", err, backoff)
			sleepCtx(ctx, backoff)
			backoff = nextBackoff(backoff)
			continue
		}

		for uuid, info := range resp.Msg.EnclaveInfo {
			if info.ApiContainerInfo == nil {
				continue
			}
			apicAddr := fmt.Sprintf("http://%s:%d",
				info.ApiContainerInfo.IpInsideEnclave,
				info.ApiContainerInfo.GrpcPortInsideEnclave)
			apicClient := apicconnect.NewApiContainerServiceClient(httpClient, apicAddr, connect.WithGRPC())

			callCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
			svcResp, err := apicClient.GetServices(callCtx, connect.NewRequest(&apic.GetServicesArgs{}))
			cancel()
			if err != nil {
				log.Printf("GetServices on enclave %s: %v", info.Name, err)
				continue
			}
			for _, svc := range svcResp.Msg.ServiceInfo {
				if ownIPs[svc.PrivateIpAddr] {
					return uuid, info.Name, svc.ServiceUuid, nil
				}
			}
		}

		sleepCtx(ctx, backoff)
		backoff = nextBackoff(backoff)
	}
	return "", "", "", errors.New("self-discovery timed out")
}

func ownIPv4s() (map[string]bool, error) {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return nil, err
	}
	out := map[string]bool{}
	for _, a := range addrs {
		ipn, ok := a.(*net.IPNet)
		if !ok || ipn.IP.IsLoopback() {
			continue
		}
		if ip4 := ipn.IP.To4(); ip4 != nil {
			out[ip4.String()] = true
		}
	}
	return out, nil
}

// runServiceMux maintains one stream worker per service in the enclave,
// reconciling against periodic GetServices calls on the API container.
//
// streamWg tracks every stream goroutine so the caller can wait for them to
// drain before closing the output channel.
func runServiceMux(
	ctx context.Context,
	engineClient engineconnect.EngineServiceClient,
	httpClient *http.Client,
	enclaveUUID, enclaveName, ownUUID string,
	excludeNames map[string]bool,
	out chan<- otelLogRecord,
	streamWg *sync.WaitGroup,
) {
	apicAddr, err := getAPICAddr(ctx, engineClient, enclaveUUID)
	if err != nil {
		log.Fatalf("resolve API container address: %v", err)
	}
	// API container speaks gRPC only (HTTP/2 + application/grpc), not Connect's
	// JSON/proto-over-HTTP/1. The engine accepts both, but the API container is
	// strict — confirmed empirically via 415 from Connect, 200 from gRPC.
	apicClient := apicconnect.NewApiContainerServiceClient(httpClient, apicAddr, connect.WithGRPC())

	var mu sync.Mutex
	workers := map[string]context.CancelFunc{}
	// noLogsServices marks UUIDs the engine has told us have no log file paths
	// (e.g., one-shot keystore-generation jobs). Suppressed permanently.
	noLogsServices := map[string]bool{}

	markNoLogs := func(uuid string) {
		mu.Lock()
		defer mu.Unlock()
		noLogsServices[uuid] = true
	}

	removeWorker := func(uuid string) {
		mu.Lock()
		defer mu.Unlock()
		delete(workers, uuid)
	}

	startWorker := func(meta serviceMeta) {
		mu.Lock()
		if _, exists := workers[meta.uuid]; exists || noLogsServices[meta.uuid] {
			mu.Unlock()
			return
		}
		workerCtx, cancel := context.WithCancel(ctx)
		workers[meta.uuid] = cancel
		mu.Unlock()

		streamWg.Add(1)
		go func() {
			defer streamWg.Done()
			defer removeWorker(meta.uuid)
			streamServiceLogs(workerCtx, engineClient, enclaveUUID, enclaveName, meta, out, markNoLogs)
		}()
	}

	stopWorker := func(uuid string) {
		mu.Lock()
		defer mu.Unlock()
		if c, ok := workers[uuid]; ok {
			c()
		}
	}

	reconcile := func() {
		callCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		resp, err := apicClient.GetServices(callCtx, connect.NewRequest(&apic.GetServicesArgs{}))
		if err != nil {
			log.Printf("reconcile GetServices: %v", err)
			return
		}
		alive := map[string]bool{}
		for _, svc := range resp.Msg.ServiceInfo {
			if svc.ServiceUuid == ownUUID || excludeNames[svc.Name] {
				continue
			}
			alive[svc.ServiceUuid] = true
			startWorker(serviceMeta{uuid: svc.ServiceUuid, name: svc.Name})
		}
		mu.Lock()
		var dead []string
		for uuid := range workers {
			if !alive[uuid] {
				dead = append(dead, uuid)
			}
		}
		mu.Unlock()
		for _, uuid := range dead {
			log.Printf("service %s removed; stopping worker", uuid)
			stopWorker(uuid)
		}
	}

	reconcile()
	ticker := time.NewTicker(servicePollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			mu.Lock()
			for _, c := range workers {
				c()
			}
			mu.Unlock()
			return
		case <-ticker.C:
			reconcile()
		}
	}
}

func getAPICAddr(ctx context.Context, engineClient engineconnect.EngineServiceClient, enclaveUUID string) (string, error) {
	resp, err := engineClient.GetEnclaves(ctx, connect.NewRequest(&emptypb.Empty{}))
	if err != nil {
		return "", err
	}
	info, ok := resp.Msg.EnclaveInfo[enclaveUUID]
	if !ok || info.ApiContainerInfo == nil {
		return "", fmt.Errorf("no API container info for enclave %s", enclaveUUID)
	}
	return fmt.Sprintf("http://%s:%d",
		info.ApiContainerInfo.IpInsideEnclave,
		info.ApiContainerInfo.GrpcPortInsideEnclave), nil
}

// streamServiceLogs holds one long-lived GetServiceLogs stream for a single
// service, reconnecting with exponential backoff. First connect uses
// return_all_logs=true to backfill history; subsequent reconnects do not.
// If the engine reports the service has no log files (e.g. one-shot keystore
// generation), markNoLogs is called and the worker exits.
func streamServiceLogs(
	ctx context.Context,
	engineClient engineconnect.EngineServiceClient,
	enclaveUUID, enclaveName string,
	meta serviceMeta,
	out chan<- otelLogRecord,
	markNoLogs func(string),
) {
	log.Printf("start stream: service=%s (%s)", meta.name, meta.uuid)
	defer log.Printf("stop stream:  service=%s (%s)", meta.name, meta.uuid)

	resourceAttrs := map[string]string{
		"service.name":          meta.name,
		"kurtosis.enclave_uuid": enclaveUUID,
		"kurtosis.enclave_name": enclaveName,
		"kurtosis.service_uuid": meta.uuid,
	}

	backoff := streamBackoffMin
	historicalReplayed := false
	for ctx.Err() == nil {
		// Replay history until a stream confirms it received something. Flipping
		// the flag only on a confirmed receive means a transient open error on
		// first attempt doesn't skip backfill on the next attempt.
		returnAll := !historicalReplayed

		req := connect.NewRequest(&engineapi.GetServiceLogsArgs{
			EnclaveIdentifier: enclaveUUID,
			ServiceUuidSet:    map[string]bool{meta.uuid: true},
			FollowLogs:        boolPtr(true),
			ReturnAllLogs:     boolPtr(returnAll),
		})

		stream, err := engineClient.GetServiceLogs(ctx, req)
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			log.Printf("open stream service=%s: %v (retry in %s)", meta.name, err, backoff)
			sleepCtx(ctx, backoff)
			backoff = nextBackoff(backoff)
			continue
		}
		backoff = streamBackoffMin

		for stream.Receive() {
			historicalReplayed = true
			msg := stream.Msg()
			lines := msg.ServiceLogsByServiceUuid[meta.uuid]
			if lines == nil {
				continue
			}
			ts := time.Now().UTC()
			if lines.Timestamp != nil {
				ts = lines.Timestamp.AsTime().UTC()
			}
			tsStr := ts.Format("2006-01-02 15:04:05.000000000")
			for _, line := range lines.Line {
				rec := otelLogRecord{
					Timestamp:          tsStr,
					ServiceName:        meta.name,
					Body:               line,
					ResourceAttributes: resourceAttrs,
					LogAttributes:      map[string]string{},
				}
				select {
				case out <- rec:
				case <-ctx.Done():
					_ = stream.Close()
					return
				default:
					dropCounter.inc()
				}
			}
		}
		streamErr := stream.Err()
		_ = stream.Close()
		if ctx.Err() != nil {
			return
		}
		if streamErr != nil && strings.Contains(streamErr.Error(), "No logs file paths") {
			log.Printf("service=%s has no log files; suppressing", meta.name)
			markNoLogs(meta.uuid)
			return
		}
		if streamErr != nil && !errors.Is(streamErr, context.Canceled) {
			log.Printf("stream service=%s closed with: %v (retry in %s)", meta.name, streamErr, backoff)
		}
		sleepCtx(ctx, backoff)
		backoff = nextBackoff(backoff)
	}
}

// runWriter drains the bounded channel into batched JSONEachRow POSTs.
func runWriter(ctx context.Context, chEndpoint string, in <-chan otelLogRecord) {
	insertURL := mustInsertURL(chEndpoint)
	client := &http.Client{Timeout: chHTTPTimeout}

	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	count := 0
	timer := time.NewTimer(batchMaxAge)
	defer timer.Stop()

	flush := func() {
		if count == 0 {
			buf.Reset()
			resetTimer(timer, batchMaxAge)
			return
		}
		payload := append([]byte(nil), buf.Bytes()...)
		if err := sendBatch(client, insertURL, payload); err != nil {
			log.Printf("clickhouse insert failed: %v (dropped %d records)", err, count)
			batchDropCounter.add(count)
		}
		buf.Reset()
		count = 0
		resetTimer(timer, batchMaxAge)
	}

	for {
		select {
		case <-ctx.Done():
			flush()
			return
		case rec, ok := <-in:
			if !ok {
				flush()
				return
			}
			if err := enc.Encode(rec); err != nil {
				log.Printf("encode record: %v", err)
				continue
			}
			count++
			if count >= batchMaxRecords || buf.Len() >= batchMaxBytes {
				flush()
			}
		case <-timer.C:
			flush()
		}
	}
}

func resetTimer(t *time.Timer, d time.Duration) {
	if !t.Stop() {
		select {
		case <-t.C:
		default:
		}
	}
	t.Reset(d)
}

func mustInsertURL(endpoint string) string {
	u, err := url.Parse(endpoint)
	if err != nil {
		log.Fatalf("clickhouse endpoint: %v", err)
	}
	q := u.Query()
	q.Set("query", "INSERT INTO otel.otel_logs (Timestamp,ServiceName,Body,ResourceAttributes,LogAttributes) FORMAT JSONEachRow")
	q.Set("date_time_input_format", "best_effort")
	u.RawQuery = q.Encode()
	return u.String()
}

func sendBatch(client *http.Client, urlStr string, payload []byte) error {
	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		req, err := http.NewRequest(http.MethodPost, urlStr, bytes.NewReader(payload))
		if err != nil {
			return err
		}
		req.Header.Set("Content-Type", "application/x-ndjson")
		resp, err := client.Do(req)
		if err == nil && resp.StatusCode < 300 {
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
			return nil
		}
		if resp != nil {
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
			resp.Body.Close()
			lastErr = fmt.Errorf("status=%d body=%s", resp.StatusCode, string(body))
		} else {
			lastErr = err
		}
		if attempt == 0 {
			time.Sleep(time.Second)
		}
	}
	return lastErr
}

func waitForClickHouse(ctx context.Context, endpoint string) error {
	pingURL := strings.TrimRight(endpoint, "/") + "/ping"
	existsURL := strings.TrimRight(endpoint, "/") + "/?query=" + url.QueryEscape("EXISTS TABLE otel.otel_logs")
	client := &http.Client{Timeout: 5 * time.Second}

	deadline := time.Now().Add(chReadyTimeout)
	backoff := time.Second
	for time.Now().Before(deadline) {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if resp, err := client.Get(pingURL); err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			if resp2, err := client.Get(existsURL); err == nil && resp2.StatusCode == 200 {
				body, _ := io.ReadAll(resp2.Body)
				resp2.Body.Close()
				if strings.TrimSpace(string(body)) == "1" {
					return nil
				}
			} else if resp2 != nil {
				resp2.Body.Close()
			}
		} else if resp != nil {
			resp.Body.Close()
		}
		sleepCtx(ctx, backoff)
		backoff = nextBackoff(backoff)
	}
	return errors.New("clickhouse readiness check timed out")
}

// waitForEngine probes the engine via GetEngineInfo so a bad endpoint fails
// fast rather than after the 2-minute self-discovery deadline.
func waitForEngine(ctx context.Context, engineClient engineconnect.EngineServiceClient) error {
	deadline := time.Now().Add(30 * time.Second)
	backoff := time.Second
	var lastErr error
	for time.Now().Before(deadline) {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		callCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		_, err := engineClient.GetEngineInfo(callCtx, connect.NewRequest(&emptypb.Empty{}))
		cancel()
		if err == nil {
			return nil
		}
		lastErr = err
		sleepCtx(ctx, backoff)
		backoff = nextBackoff(backoff)
	}
	if lastErr != nil {
		return lastErr
	}
	return errors.New("engine probe timed out")
}

func nextBackoff(b time.Duration) time.Duration {
	b *= 2
	if b > streamBackoffMax {
		b = streamBackoffMax
	}
	return b
}

func sleepCtx(ctx context.Context, d time.Duration) {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
	case <-t.C:
	}
}

func boolPtr(b bool) *bool { return &b }

// counter is a tiny rate-limited drop counter so the bridge doesn't spam its own
// stdout under sustained backpressure.
type counter struct {
	mu       sync.Mutex
	count    uint64
	lastLog  time.Time
	logEvery time.Duration
	prefix   string
}

func (c *counter) inc() { c.add(1) }
func (c *counter) add(n int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.count += uint64(n)
	if time.Since(c.lastLog) < c.logEvery {
		return
	}
	c.lastLog = time.Now()
	log.Printf("%s: %d cumulative", c.prefix, c.count)
}

var (
	dropCounter      = &counter{logEvery: time.Minute, prefix: "WARN dropped record (channel full)"}
	batchDropCounter = &counter{logEvery: time.Minute, prefix: "WARN dropped batch (clickhouse insert failed)"}
)
