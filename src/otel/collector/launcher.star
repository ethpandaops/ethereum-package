SERVICE_NAME = "otel-collector"
IMAGE = "otel/opentelemetry-collector-contrib:0.117.0"

OTLP_GRPC_PORT = 4317
OTLP_HTTP_PORT = 4318

CONFIG_MOUNT_DIR = "/etc/otelcol"


def launch(plan):
    config = plan.upload_files(
        src="./files/config.yaml",
        name="otel-collector-config",
    )

    return plan.add_service(
        name=SERVICE_NAME,
        config=ServiceConfig(
            image=IMAGE,
            cmd=["--config={}/config.yaml".format(CONFIG_MOUNT_DIR)],
            ports={
                "otlp-grpc": PortSpec(
                    number=OTLP_GRPC_PORT,
                    transport_protocol="TCP",
                    application_protocol="grpc",
                ),
                "otlp-http": PortSpec(
                    number=OTLP_HTTP_PORT,
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                CONFIG_MOUNT_DIR: config,
            },
        ),
    )
