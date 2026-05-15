SERVICE_NAME = "otel-clickhouse"
IMAGE = "clickhouse/clickhouse-server:26.3-alpine"

HTTP_PORT = 8123
NATIVE_PORT = 9000

HTTP_PORT_ID = "http"
NATIVE_PORT_ID = "native"

INIT_SQL_DIR = "/docker-entrypoint-initdb.d"


def launch(plan):
    init_sql = plan.upload_files(
        src = "./files/init.sql",
        name = "otel-clickhouse-init-sql",
    )

    return plan.add_service(
        name = SERVICE_NAME,
        config = ServiceConfig(
            image = IMAGE,
            ports = {
                HTTP_PORT_ID: PortSpec(
                    number = HTTP_PORT,
                    transport_protocol = "TCP",
                    application_protocol = "http",
                ),
                NATIVE_PORT_ID: PortSpec(
                    number = NATIVE_PORT,
                    transport_protocol = "TCP",
                ),
            },
            files = {
                INIT_SQL_DIR: init_sql,
            },
            env_vars = {
                "CLICKHOUSE_DB": "otel",
                "CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT": "1",
            },
            ready_conditions = ReadyCondition(
                recipe = GetHttpRequestRecipe(
                    port_id = HTTP_PORT_ID,
                    endpoint = "/ping",
                ),
                field = "code",
                assertion = "==",
                target_value = 200,
                timeout = "2m",
                interval = "2s",
            ),
        ),
    )
