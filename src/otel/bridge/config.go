package main

import (
	"bufio"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"net"
	"os"
	"strings"
	"time"
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
	checkpointFlushAge  = 30 * time.Second
	checkpointFileName  = "checkpoints.json"
)

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

// defaultGateway returns the IPv4 address of the container's default gateway.
// On Docker bridge networks this is the host where the Kurtosis engine has
// its port published.
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
