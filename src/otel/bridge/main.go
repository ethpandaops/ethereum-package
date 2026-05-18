// Package main runs the otel-bridge: streams logs from the Kurtosis engine
// into ClickHouse using the OTel-logs schema.
package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"
	"time"
)

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
	engineClient := newEngineClient(httpClient, cfg.engineEndpoint)

	if err := waitForEngine(ctx, engineClient); err != nil {
		log.Fatalf("engine not reachable at %s: %v", cfg.engineEndpoint, err)
	}
	if err := waitForClickHouse(ctx, cfg.clickhouseEndpoint); err != nil {
		log.Fatalf("clickhouse not ready: %v", err)
	}

	enclaveUUID, enclaveName, ownUUID, err := discoverSelf(ctx, engineClient, httpClient)
	if err != nil {
		log.Fatalf("self-discovery: %v", err)
	}
	log.Printf("enclave=%s (%s) own_service_uuid=%s", enclaveName, enclaveUUID, ownUUID)

	checkpoints := loadCheckpoints(filepath.Join(cfg.stateDir, checkpointFileName))
	log.Printf("loaded %d checkpoints from %s", checkpoints.size(), checkpoints.path)

	var checkpointWg sync.WaitGroup
	checkpointWg.Add(1)
	go func() { defer checkpointWg.Done(); runCheckpointFlusher(ctx, checkpoints) }()

	records := make(chan otelLogRecord, channelCapacity)
	var writerWg sync.WaitGroup
	writerWg.Add(1)
	go func() { defer writerWg.Done(); runWriter(cfg.clickhouseEndpoint, records) }()

	// Drain streams before closing records — otherwise mid-send panics.
	var streamWg sync.WaitGroup
	runServiceMux(ctx, engineClient, httpClient, enclaveUUID, enclaveName, ownUUID, cfg.excludeNames, checkpoints, records, &streamWg)
	streamWg.Wait()

	close(records)
	writerWg.Wait()
	checkpointWg.Wait()
	if err := checkpoints.flush(); err != nil {
		log.Printf("final checkpoint flush: %v", err)
	}
	log.Printf("shutdown complete")
}

// ----- timing helpers -----

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

func resetTimer(t *time.Timer, d time.Duration) {
	if !t.Stop() {
		select {
		case <-t.C:
		default:
		}
	}
	t.Reset(d)
}

func boolPtr(b bool) *bool { return &b }

// counter rate-limits drop warnings under backpressure.
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
