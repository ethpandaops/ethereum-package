package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type otelLogRecord struct {
	Timestamp          string            `json:"Timestamp"`
	ServiceName        string            `json:"ServiceName"`
	Body               string            `json:"Body"`
	ResourceAttributes map[string]string `json:"ResourceAttributes"`
	LogAttributes      map[string]string `json:"LogAttributes"`
}

// runWriter drains the records channel into batched JSONEachRow POSTs. Exits
// only when the channel closes; main() closes it after every stream worker has
// stopped, so SIGTERM doesn't drop records still in flight.
func runWriter(chEndpoint string, in <-chan otelLogRecord) {
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
