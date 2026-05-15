// Package main runs the otel-bridge: streams logs from the Kurtosis engine
// into ClickHouse, using the OTel-logs schema.
package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"
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

	// Wait for all stream workers before closing records, otherwise a worker
	// mid-send hits "send on closed channel".
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
