package main

import (
	"context"
	"log"
	"sync"
	"time"
)

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

// counter rate-limits drop warnings so backpressure doesn't fill stdout.
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
