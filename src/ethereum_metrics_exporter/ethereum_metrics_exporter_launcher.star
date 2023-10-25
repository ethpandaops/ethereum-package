shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
static_files = import_module("../static_files/static_files.star")
ethereum_metrics_exporter_context = import_module(
    "../ethereum_metrics_exporter/ethereum_metrics_exporter_context.star"
)

HTTP_PORT_ID = "http"
METRICS_PORT_NUMBER = 9090


def launch(
    plan,
    pair_name,
    ethereum_metrics_exporter_service_name,
    el_client_context,
    cl_client_context,
):
    exporter_service = plan.add_service(
        ethereum_metrics_exporter_service_name,
        ServiceConfig(
            image=constants.DEFAULT_ETHEREUM_METRICS_EXPORTER_IMAGE,
            ports={
                HTTP_PORT_ID: shared_utils.new_port_spec(
                    METRICS_PORT_NUMBER,
                    shared_utils.TCP_PROTOCOL,
                    shared_utils.HTTP_APPLICATION_PROTOCOL,
                )
            },
            cmd=[
                "--metrics-port",
                str(METRICS_PORT_NUMBER),
                "--consensus-url",
                "http://{}:{}".format(
                    cl_client_context.ip_addr,
                    cl_client_context.http_port_num,
                ),
                "--execution-url",
                "http://{}:{}".format(
                    el_client_context.ip_addr,
                    el_client_context.rpc_port_num,
                ),
            ],
        ),
    )

    return ethereum_metrics_exporter_context.new_ethereum_metrics_exporter_context(
        pair_name,
        exporter_service.ip_address,
        METRICS_PORT_NUMBER,
        cl_client_context.client_name,
        el_client_context.client_name,
    )
