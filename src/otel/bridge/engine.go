package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"connectrpc.com/connect"
	apic "github.com/kurtosis-tech/kurtosis/api/golang/core/kurtosis_core_rpc_api_bindings"
	apicconnect "github.com/kurtosis-tech/kurtosis/api/golang/core/kurtosis_core_rpc_api_bindings/kurtosis_core_rpc_api_bindingsconnect"
	engineapi "github.com/kurtosis-tech/kurtosis/api/golang/engine/kurtosis_engine_rpc_api_bindings"
	engineconnect "github.com/kurtosis-tech/kurtosis/api/golang/engine/kurtosis_engine_rpc_api_bindings/kurtosis_engine_rpc_api_bindingsconnect"
	"golang.org/x/net/http2"
	"google.golang.org/protobuf/types/known/emptypb"
)

// ----- constants -----

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
	checkpointFlushAge  = 30 * time.Second
	checkpointFileName  = "checkpoints.json"
)

// ----- config -----

type config struct {
	engineEndpoint     string
	clickhouseEndpoint string
	excludeNames       map[string]bool
	stateDir           string
}

func loadConfig() config {
	endpoint := os.Getenv("KURTOSIS_ENGINE_ENDPOINT")
	if endpoint == "" {
		gw, err := defaultGateway()
		if err != nil {
			log.Fatalf("discover default gateway: %v", err)
		}
		endpoint = fmt.Sprintf("http://%s:9710", gw)
	}
	exclude := map[string]bool{}
	for _, n := range strings.Split(getenv("BRIDGE_EXCLUDE_NAMES", "otel-clickhouse,otel-bridge"), ",") {
		if n = strings.TrimSpace(n); n != "" {
			exclude[n] = true
		}
	}
	return config{
		engineEndpoint:     endpoint,
		clickhouseEndpoint: getenv("CLICKHOUSE_ENDPOINT", "http://otel-clickhouse:8123"),
		excludeNames:       exclude,
		stateDir:           getenv("BRIDGE_STATE_DIR", "/state"),
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

// ----- network discovery -----

// defaultGateway returns the IPv4 of the container's default gateway — i.e.
// the Docker host, where the Kurtosis engine publishes its gRPC port.
func defaultGateway() (string, error) {
	f, err := os.Open("/proc/net/route")
	if err != nil {
		return "", err
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	scanner.Scan()
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

// ----- Kurtosis Connect clients -----

// newHTTP2Client returns an h2c client for Connect streaming over plain HTTP.
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

func newEngineClient(httpClient *http.Client, endpoint string) engineconnect.EngineServiceClient {
	return engineconnect.NewEngineServiceClient(httpClient, endpoint)
}

// newAPICClient dials the per-enclave API container. It only speaks gRPC,
// not Connect's other transports — confirmed empirically (HTTP 415 otherwise).
func newAPICClient(httpClient *http.Client, addr string) apicconnect.ApiContainerServiceClient {
	return apicconnect.NewApiContainerServiceClient(httpClient, addr, connect.WithGRPC())
}

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

// discoverSelf identifies the bridge's own enclave by matching its IPv4 to a
// service's private_ip_addr in each enclave's GetServices response.
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
			apicAddr := fmt.Sprintf("http://%s:%d", info.ApiContainerInfo.IpInsideEnclave, info.ApiContainerInfo.GrpcPortInsideEnclave)
			apicClient := newAPICClient(httpClient, apicAddr)
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

func getAPICAddr(ctx context.Context, engineClient engineconnect.EngineServiceClient, enclaveUUID string) (string, error) {
	resp, err := engineClient.GetEnclaves(ctx, connect.NewRequest(&emptypb.Empty{}))
	if err != nil {
		return "", err
	}
	info, ok := resp.Msg.EnclaveInfo[enclaveUUID]
	if !ok || info.ApiContainerInfo == nil {
		return "", fmt.Errorf("no API container info for enclave %s", enclaveUUID)
	}
	return fmt.Sprintf("http://%s:%d", info.ApiContainerInfo.IpInsideEnclave, info.ApiContainerInfo.GrpcPortInsideEnclave), nil
}

// ----- service mux -----

type serviceMeta struct {
	uuid string
	name string
}

// runServiceMux keeps one stream worker per service in the enclave, reconciled
// against the API container's GetServices on a fixed interval.
func runServiceMux(
	ctx context.Context,
	engineClient engineconnect.EngineServiceClient,
	httpClient *http.Client,
	enclaveUUID, enclaveName, ownUUID string,
	excludeNames map[string]bool,
	checkpoints *checkpointStore,
	out chan<- otelLogRecord,
	streamWg *sync.WaitGroup,
) {
	apicAddr, err := getAPICAddr(ctx, engineClient, enclaveUUID)
	if err != nil {
		log.Fatalf("resolve API container address: %v", err)
	}
	apicClient := newAPICClient(httpClient, apicAddr)

	var mu sync.Mutex
	workers := map[string]context.CancelFunc{}
	noLogs := map[string]bool{}

	markNoLogs := func(uuid string) {
		mu.Lock()
		defer mu.Unlock()
		noLogs[uuid] = true
	}
	removeWorker := func(uuid string) {
		mu.Lock()
		defer mu.Unlock()
		delete(workers, uuid)
	}

	startWorker := func(meta serviceMeta) {
		mu.Lock()
		if _, exists := workers[meta.uuid]; exists || noLogs[meta.uuid] {
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
			streamServiceLogs(workerCtx, engineClient, enclaveUUID, enclaveName, meta, checkpoints, out, markNoLogs)
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

// ----- per-service stream worker -----

// streamServiceLogs holds one GetServiceLogs stream per service. Records older
// than the persisted checkpoint are dropped; ReturnAllLogs=true on every connect
// so reconnects after a disconnect window don't miss lines the engine kept. If
// the engine reports "no log files" (one-shot tasks), the worker exits via
// markNoLogs.
func streamServiceLogs(
	ctx context.Context,
	engineClient engineconnect.EngineServiceClient,
	enclaveUUID, enclaveName string,
	meta serviceMeta,
	checkpoints *checkpointStore,
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
	for ctx.Err() == nil {
		skipBefore := checkpoints.get(meta.uuid)
		req := connect.NewRequest(&engineapi.GetServiceLogsArgs{
			EnclaveIdentifier: enclaveUUID,
			ServiceUuidSet:    map[string]bool{meta.uuid: true},
			FollowLogs:        boolPtr(true),
			ReturnAllLogs:     boolPtr(true),
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
			lines := stream.Msg().ServiceLogsByServiceUuid[meta.uuid]
			if lines == nil {
				continue
			}
			ts := time.Now().UTC()
			if lines.Timestamp != nil {
				ts = lines.Timestamp.AsTime().UTC()
			}
			if !ts.After(skipBefore) {
				continue
			}
			tsStr := ts.Format("2006-01-02 15:04:05.000000000")
			for i, line := range lines.Line {
				rec := otelLogRecord{
					Timestamp:          tsStr,
					ServiceName:        meta.name,
					Body:               line,
					ResourceAttributes: resourceAttrs,
					// line_index separates identical bodies in one batch (one timestamp, many lines).
					LogAttributes: map[string]string{"kurtosis.line_index": strconv.Itoa(i)},
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
			checkpoints.update(meta.uuid, ts)
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
			log.Printf("stream service=%s closed: %v (retry in %s)", meta.name, streamErr, backoff)
		}
		sleepCtx(ctx, backoff)
		backoff = nextBackoff(backoff)
	}
}
