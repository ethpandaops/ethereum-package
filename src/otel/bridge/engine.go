package main

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"time"

	"connectrpc.com/connect"
	apic "github.com/kurtosis-tech/kurtosis/api/golang/core/kurtosis_core_rpc_api_bindings"
	apicconnect "github.com/kurtosis-tech/kurtosis/api/golang/core/kurtosis_core_rpc_api_bindings/kurtosis_core_rpc_api_bindingsconnect"
	engineconnect "github.com/kurtosis-tech/kurtosis/api/golang/engine/kurtosis_engine_rpc_api_bindings/kurtosis_engine_rpc_api_bindingsconnect"
	"golang.org/x/net/http2"
	"google.golang.org/protobuf/types/known/emptypb"
)

// newHTTP2Client returns an h2c HTTP client so Connect streaming works against
// engines published over plain HTTP.
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

// newAPICClient dials the per-enclave API container, which speaks gRPC only
// (HTTP/2 + application/grpc), not Connect's JSON/proto-over-HTTP/1.
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

// discoverSelf finds the enclave the bridge is running in by matching its own
// IPv4 to a service's private_ip_addr returned by each enclave's API container.
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
