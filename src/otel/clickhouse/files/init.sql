CREATE DATABASE IF NOT EXISTS otel;

CREATE TABLE IF NOT EXISTS otel.otel_logs
(
    Timestamp          DateTime64(9) CODEC(Delta(8), ZSTD(1)),
    TraceId            String CODEC(ZSTD(1)),
    SpanId             String CODEC(ZSTD(1)),
    TraceFlags         UInt8,
    SeverityText       LowCardinality(String) CODEC(ZSTD(1)),
    SeverityNumber     UInt8,
    ServiceName        LowCardinality(String) CODEC(ZSTD(1)),
    Body               String CODEC(ZSTD(1)),
    ResourceSchemaUrl  LowCardinality(String) CODEC(ZSTD(1)),
    ResourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    ScopeSchemaUrl     LowCardinality(String) CODEC(ZSTD(1)),
    ScopeName          String CODEC(ZSTD(1)),
    ScopeVersion       LowCardinality(String) CODEC(ZSTD(1)),
    ScopeAttributes    Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    LogAttributes      Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    EventName          String CODEC(ZSTD(1)),
    INDEX idx_trace_id TraceId TYPE bloom_filter(0.001)     GRANULARITY 1,
    INDEX idx_body     Body    TYPE tokenbf_v1(32768, 3, 0) GRANULARITY 4
)
ENGINE = ReplacingMergeTree
PARTITION BY toDate(Timestamp)
ORDER BY (toStartOfFiveMinutes(Timestamp), ServiceName, Timestamp, cityHash64(Body))
-- TTL is approximate, not strict: ttl_only_drop_parts=1 means whole parts are
-- dropped when their max Timestamp is past TTL, so retention can lag by up to
-- one part's age (minutes-to-hours on a busy devnet). Fine for devnets.
TTL toDateTime(Timestamp) + INTERVAL 6 HOUR DELETE
SETTINGS index_granularity = 8192, ttl_only_drop_parts = 1;
