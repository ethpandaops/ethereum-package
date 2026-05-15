SERVICE_NAME = "otel-bridge"
STATE_DIR = "/state"


def launch(plan, clickhouse_endpoint):
    return plan.add_service(
        name = SERVICE_NAME,
        config = ServiceConfig(
            image = ImageBuildSpec(
                image_name = "ethereum-package-otel-bridge",
                build_context_dir = "./",
            ),
            env_vars = {
                "CLICKHOUSE_ENDPOINT": clickhouse_endpoint,
                "BRIDGE_STATE_DIR": STATE_DIR,
            },
            files = {
                STATE_DIR: Directory(persistent_key = "otel-bridge-state"),
            },
        ),
    )
