clickhouse_launcher = import_module("./clickhouse/launcher.star")
bridge_launcher = import_module("./bridge/launcher.star")
collector_launcher = import_module("./collector/launcher.star")

CLICKHOUSE_SERVICE_NAME = clickhouse_launcher.SERVICE_NAME
CLICKHOUSE_HTTP_PORT = clickhouse_launcher.HTTP_PORT
COLLECTOR_SERVICE_NAME = collector_launcher.SERVICE_NAME
COLLECTOR_OTLP_GRPC_PORT = collector_launcher.OTLP_GRPC_PORT


def launch(plan):
    plan.print("Launching ClickHouse for OTel signal capture...")
    clickhouse_launcher.launch(plan)

    ch_endpoint = "http://{}:{}".format(
        clickhouse_launcher.SERVICE_NAME,
        clickhouse_launcher.HTTP_PORT,
    )
    plan.print("Launching log bridge -> " + ch_endpoint)
    bridge_launcher.launch(plan, ch_endpoint)

    plan.print("Launching otel-collector (OTLP receiver for traces)")
    collector_launcher.launch(plan)

    plan.print(
        "otel ready. Logs: otel.otel_logs (ReplacingMergeTree). " +
        "Traces: otel.otel_traces (MergeTree). " +
        "OTLP endpoint for clients: {}:{}".format(collector_launcher.SERVICE_NAME, collector_launcher.OTLP_GRPC_PORT),
    )
