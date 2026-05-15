package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"sync"
	"time"
)

// checkpointStore persists "last seen timestamp" per service so restarts skip
// already-processed history. ReplacingMergeTree absorbs records that slip
// through between flush and crash.
type checkpointStore struct {
	mu    sync.Mutex
	data  map[string]int64 // service_uuid -> unix nanos
	path  string
	dirty bool
}

func loadCheckpoints(path string) *checkpointStore {
	s := &checkpointStore{path: path, data: map[string]int64{}}
	b, err := os.ReadFile(path)
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			log.Printf("checkpoint load: %v (starting fresh)", err)
		}
		return s
	}
	if err := json.Unmarshal(b, &s.data); err != nil {
		log.Printf("checkpoint parse: %v (starting fresh)", err)
		s.data = map[string]int64{}
	}
	return s
}

func (s *checkpointStore) get(uuid string) time.Time {
	s.mu.Lock()
	defer s.mu.Unlock()
	ns, ok := s.data[uuid]
	if !ok {
		return time.Time{}
	}
	return time.Unix(0, ns).UTC()
}

func (s *checkpointStore) update(uuid string, ts time.Time) {
	tsNs := ts.UnixNano()
	s.mu.Lock()
	defer s.mu.Unlock()
	if cur, ok := s.data[uuid]; !ok || tsNs > cur {
		s.data[uuid] = tsNs
		s.dirty = true
	}
}

func (s *checkpointStore) size() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.data)
}

func (s *checkpointStore) flush() error {
	s.mu.Lock()
	if !s.dirty {
		s.mu.Unlock()
		return nil
	}
	b, err := json.Marshal(s.data)
	s.mu.Unlock()
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return fmt.Errorf("write tmp: %w", err)
	}
	if err := os.Rename(tmp, s.path); err != nil {
		return fmt.Errorf("rename: %w", err)
	}
	s.mu.Lock()
	s.dirty = false
	s.mu.Unlock()
	return nil
}

func runCheckpointFlusher(ctx context.Context, s *checkpointStore) {
	ticker := time.NewTicker(checkpointFlushAge)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := s.flush(); err != nil {
				log.Printf("checkpoint flush: %v", err)
			}
		}
	}
}
