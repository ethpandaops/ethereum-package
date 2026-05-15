package main

import (
	"context"
	"log"
	"net/http"
	"sync"
	"time"

	"connectrpc.com/connect"
	apic "github.com/kurtosis-tech/kurtosis/api/golang/core/kurtosis_core_rpc_api_bindings"
	engineconnect "github.com/kurtosis-tech/kurtosis/api/golang/engine/kurtosis_engine_rpc_api_bindings/kurtosis_engine_rpc_api_bindingsconnect"
)

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
