SERVICE_NAME = "otel-bridge"


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
            },
        ),
    )
