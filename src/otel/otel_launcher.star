clickhouse_launcher = import_module("./clickhouse/launcher.star")
bridge_launcher = import_module("./bridge/launcher.star")
collector_launcher = import_module("./collector/launcher.star")

CLICKHOUSE_SERVICE_NAME = clickhouse_launcher.SERVICE_NAME
CLICKHOUSE_HTTP_PORT = clickhouse_launcher.HTTP_PORT
COLLECTOR_SERVICE_NAME = collector_launcher.SERVICE_NAME
COLLECTOR_OTLP_GRPC_PORT = collector_launcher.OTLP_GRPC_PORT
COLLECTOR_OTLP_HTTP_PORT = collector_launcher.OTLP_HTTP_PORT


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

    otlp_endpoint = "http://{}:{}".format(
        collector_launcher.SERVICE_NAME, collector_launcher.OTLP_GRPC_PORT,
    )
    plan.print(
        "otel ready. " +
        "Logs auto-collected into otel.otel_logs (via bridge). " +
        "Traces table otel.otel_traces accepts OTLP at " + otlp_endpoint + " — " +
        "point your clients at it via cl_extra_env_vars/el_extra_env_vars " +
        "(e.g. OTEL_EXPORTER_OTLP_ENDPOINT=" + otlp_endpoint + ").",
    )
