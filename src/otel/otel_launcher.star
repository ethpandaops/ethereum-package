clickhouse_launcher = import_module("./clickhouse/launcher.star")
bridge_launcher = import_module("./bridge/launcher.star")

CLICKHOUSE_SERVICE_NAME = clickhouse_launcher.SERVICE_NAME
CLICKHOUSE_HTTP_PORT = clickhouse_launcher.HTTP_PORT


def launch(plan):
    plan.print("Launching ClickHouse for OTel log capture...")
    clickhouse_launcher.launch(plan)

    ch_endpoint = "http://{}:{}".format(
        clickhouse_launcher.SERVICE_NAME,
        clickhouse_launcher.HTTP_PORT,
    )
    plan.print("Launching log bridge -> " + ch_endpoint)
    bridge_launcher.launch(plan, ch_endpoint)

    plan.print(
        "otel ready. Query logs via {}. Schema is otel.otel_logs (ReplacingMergeTree). ".format(ch_endpoint)
        + "Use SELECT ... FROM otel.otel_logs FINAL for strict dedup on restart-replay duplicates."
    )
