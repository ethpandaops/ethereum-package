package main

import (
	"context"
	"errors"
	"log"
	"strconv"
	"strings"
	"time"

	"connectrpc.com/connect"
	engineapi "github.com/kurtosis-tech/kurtosis/api/golang/engine/kurtosis_engine_rpc_api_bindings"
	engineconnect "github.com/kurtosis-tech/kurtosis/api/golang/engine/kurtosis_engine_rpc_api_bindings/kurtosis_engine_rpc_api_bindingsconnect"
)

// streamServiceLogs holds one GetServiceLogs stream per service. Records older
// than the persisted checkpoint are dropped on replay. If the engine reports
// "no log files" (one-shot tasks), the worker calls markNoLogs and exits.
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

	skipBefore := checkpoints.get(meta.uuid)
	if !skipBefore.IsZero() {
		log.Printf("service=%s: skipping records at or before %s", meta.name, skipBefore.Format(time.RFC3339Nano))
	}

	backoff := streamBackoffMin
	// Flip only after a confirmed Receive so a transient open error doesn't skip backfill.
	historicalReplayed := false
	for ctx.Err() == nil {
		req := connect.NewRequest(&engineapi.GetServiceLogsArgs{
			EnclaveIdentifier: enclaveUUID,
			ServiceUuidSet:    map[string]bool{meta.uuid: true},
			FollowLogs:        boolPtr(true),
			ReturnAllLogs:     boolPtr(!historicalReplayed),
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
