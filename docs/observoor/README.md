# observoor profiling → engine OTel ClickHouse

The `observoor` additional_service runs the [observoor](https://github.com/ethpandaops/observoor)
eBPF agent (privileged, host PID namespace) to collect kernel-level performance
metrics — CPU, memory, disk I/O, network I/O, scheduler latency, syscalls — for
every Ethereum client process, with **zero client modifications**.

## Single ClickHouse, no extra backend

observoor does **not** run its own ClickHouse. Like the `otel` tracing service,
it ships data to the **engine OTel ClickHouse** published on the Docker host by
`kurtosis otel start`. The package discovers that stack via the default gateway
and points observoor at its native endpoint. observoor writes to its own
`observoor` database, alongside the `otel` database (traces/logs) — one
ClickHouse instance, two databases.

```
geth/besu/...  ──OTLP──▶ OTel Collector ─┐
                                          ├──▶ engine OTel ClickHouse
observoor      ──native TCP (9000)────────┘     (otel DB + observoor DB)
```

## Engine-side requirement (kurtosis otel)

observoor's sink speaks the ClickHouse **native binary protocol**, and its
embedded schema uses `ReplicatedReplacingMergeTree` + `ON CLUSTER '{cluster}'`.
For observoor to land in the engine OTel ClickHouse, that ClickHouse must:

1. **Publish the native TCP port** (9000) on the Docker host as `19000`
   (matching `ENGINE_OTEL_CLICKHOUSE_NATIVE_PORT` in `main.star`). It already
   publishes HTTP as `18123`.
2. **Apply single-node cluster config** — macros (`{cluster}`, `{installation}`,
   `{shard}`, `{replica}`), a single-replica `remote_servers` entry, and an
   embedded ClickHouse Keeper. See [`engine-clickhouse-cluster.xml`](./engine-clickhouse-cluster.xml).
3. **Allow remote access for the default user** — see
   [`engine-clickhouse-users.xml`](./engine-clickhouse-users.xml).
4. **Pre-create the `observoor` database** (observoor's migrator does not create
   the database itself).

The two XML files in this directory are the exact config used to verify the
integration locally and serve as the spec for the engine-side
(`kurtosis-tech/kurtosis#3122`) change.
