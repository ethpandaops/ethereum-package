shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
ethereum_metrics_exporter_context = import_module(
    "../ethereum_metrics_exporter/ethereum_metrics_exporter_context.star"
)
HTTP_PORT_ID = "http"
METRICS_PORT_NUMBER = 9090

DEFAULT_ETHEREUM_METRICS_EXPORTER_IMAGE = "ethpandaops/ethereum-metrics-exporter:latest"

# The min/max CPU/memory that ethereum-metrics-exporter can use
MIN_CPU = 10
MAX_CPU = 100
MIN_MEMORY = 16
MAX_MEMORY = 128


def launch(
    plan,
    pair_name,
    ethereum_metrics_exporter_service_name,
    el_context,
    cl_context,
    node_selectors,
    port_publisher,
    global_other_index,
    docker_cache_params,
):
    public_ports = shared_utils.get_other_public_port(
        port_publisher,
        HTTP_PORT_ID,
        global_other_index,
        0,
    )

    exporter_service = plan.add_service(
        ethereum_metrics_exporter_service_name,
        ServiceConfig(
            image=shared_utils.docker_cache_image_calc(
                docker_cache_params,
                DEFAULT_ETHEREUM_METRICS_EXPORTER_IMAGE,
            ),
            ports={
                HTTP_PORT_ID: shared_utils.new_port_spec(
                    METRICS_PORT_NUMBER,
                    shared_utils.TCP_PROTOCOL,
                    shared_utils.HTTP_APPLICATION_PROTOCOL,
                )
            },
            public_ports=public_ports,
            cmd=[
                "--metrics-port",
                str(METRICS_PORT_NUMBER),
                "--consensus-url",
                "{0}".format(
                    cl_context.beacon_http_url,
                ),
                "--execution-url",
                "http://{}:{}".format(
                    el_context.ip_addr,
                    el_context.rpc_port_num,
                ),
            ],
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    return ethereum_metrics_exporter_context.new_ethereum_metrics_exporter_context(
        pair_name,
        exporter_service.ip_address,
        METRICS_PORT_NUMBER,
        cl_context.client_name,
        el_context.client_name,
    )
