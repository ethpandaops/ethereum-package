shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
el_context = import_module("../el/el_context.star")
snooper_engine_context = import_module("../snooper/snooper_engine_context.star")

SNOOPER_ENGINE_RPC_PORT_NUM = 8561
SNOOPER_ENGINE_RPC_PORT_ID = "http"
SNOOPER_BINARY_COMMAND = "./json_rpc_snoop"

SNOOPER_USED_PORTS = {
    SNOOPER_ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(
        SNOOPER_ENGINE_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL, wait="5s"
    ),
}


# The min/max CPU/memory that snooper can use
MIN_CPU = 10
MAX_CPU = 100
MIN_MEMORY = 10
MAX_MEMORY = 600


def launch(plan, service_name, el_context, node_selectors):
    snooper_service_name = "{0}".format(service_name)

    snooper_config = get_config(service_name, el_context, node_selectors)

    snooper_service = plan.add_service(snooper_service_name, snooper_config)
    snooper_http_port = snooper_service.ports[SNOOPER_ENGINE_RPC_PORT_ID]
    return snooper_engine_context.new_snooper_engine_client_context(
        snooper_service.ip_address, SNOOPER_ENGINE_RPC_PORT_NUM
    )


def get_config(service_name, el_context, node_selectors):
    engine_rpc_port_num = "http://{0}:{1}".format(
        el_context.ip_addr,
        el_context.engine_rpc_port_num,
    )
    cmd = [
        SNOOPER_BINARY_COMMAND,
        "-b=0.0.0.0",
        "-p={0}".format(SNOOPER_ENGINE_RPC_PORT_NUM),
        "{0}".format(engine_rpc_port_num),
    ]

    return ServiceConfig(
        image=constants.DEFAULT_SNOOPER_IMAGE,
        ports=SNOOPER_USED_PORTS,
        cmd=cmd,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
