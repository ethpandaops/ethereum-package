shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")

SERVICE_NAME = "tempo"

# Tempo standard ports
HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 3200
GRPC_PORT_ID = "grpc"
GRPC_PORT_NUMBER = 9095
OTLP_GRPC_PORT_ID = "otlp-grpc"
OTLP_GRPC_PORT_NUMBER = 4317
OTLP_HTTP_PORT_ID = "otlp-http"
OTLP_HTTP_PORT_NUMBER = 4318

TEMPO_CONFIG_FILENAME = "tempo.yaml"
TEMPO_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/etc/tempo"

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    GRPC_PORT_ID: shared_utils.new_port_spec(
        GRPC_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
    ),
    OTLP_GRPC_PORT_ID: shared_utils.new_port_spec(
        OTLP_GRPC_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
    ),
    OTLP_HTTP_PORT_ID: shared_utils.new_port_spec(
        OTLP_HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}


def launch_tempo(
    plan,
    config_template,
    global_node_selectors,
    global_tolerations,
    tempo_params,
    port_publisher,
    index,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    config_files_artifact_name = get_tempo_config_dir_artifact_uuid(
        plan,
        config_template,
        tempo_params,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        HTTP_PORT_ID,
        index,
        1,
    )

    config = get_config(
        config_files_artifact_name,
        global_node_selectors,
        tolerations,
        tempo_params,
        public_ports,
    )

    service = plan.add_service(SERVICE_NAME, config)

    # Return connection info for other services
    return struct(
        service_name=SERVICE_NAME,
        ip_addr=service.name,
        http_port_num=HTTP_PORT_NUMBER,
        grpc_port_num=GRPC_PORT_NUMBER,
        otlp_grpc_port_num=OTLP_GRPC_PORT_NUMBER,
        otlp_http_port_num=OTLP_HTTP_PORT_NUMBER,
        http_url="http://{}:{}".format(service.name, HTTP_PORT_NUMBER),
        grpc_url="{}:{}".format(service.name, GRPC_PORT_NUMBER),
        otlp_grpc_url="{}:{}".format(SERVICE_NAME, OTLP_GRPC_PORT_NUMBER),
        otlp_http_url="http://{}:{}".format(SERVICE_NAME, OTLP_HTTP_PORT_NUMBER),
    )


def get_tempo_config_dir_artifact_uuid(
    plan,
    config_template,
    tempo_params,
):
    template_data = new_config_template_data(tempo_params)

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[TEMPO_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "tempo-config"
    )

    return config_files_artifact_name


def get_config(
    config_files_artifact_name,
    node_selectors,
    tolerations,
    tempo_params,
    public_ports,
):
    config_file_path = shared_utils.path_join(
        TEMPO_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        TEMPO_CONFIG_FILENAME,
    )

    return ServiceConfig(
        image=tempo_params.image,
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            TEMPO_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=[
            "-config.file={}".format(config_file_path),
        ],
        min_cpu=tempo_params.min_cpu,
        max_cpu=tempo_params.max_cpu,
        min_memory=tempo_params.min_mem,
        max_memory=tempo_params.max_mem,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )


def new_config_template_data(tempo_params):
    return {
        "HTTPPort": HTTP_PORT_NUMBER,
        "GRPCPort": GRPC_PORT_NUMBER,
        "OTLPGRPCPort": OTLP_GRPC_PORT_NUMBER,
        "OTLPHTTPPort": OTLP_HTTP_PORT_NUMBER,
        "RetentionDuration": tempo_params.retention_duration,
        "IngestionRateLimit": tempo_params.ingestion_rate_limit,
        "IngestionBurstLimit": tempo_params.ingestion_burst_limit,
        "MaxSearchDuration": tempo_params.max_search_duration,
        "MaxBytesPerTrace": tempo_params.max_bytes_per_trace,
    }
