shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
cl_context = import_module("../cl/cl_context.star")
snooper_beacon_context = import_module("../snooper/snooper_beacon_context.star")

SNOOPER_BEACON_RPC_PORT_NUM = 8562
SNOOPER_BEACON_RPC_PORT_ID = "http"
SNOOPER_BINARY_COMMAND = "./json_rpc_snoop"

SNOOPER_USED_PORTS = {
    SNOOPER_BEACON_RPC_PORT_ID: shared_utils.new_port_spec(
        SNOOPER_BEACON_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL, wait="5s"
    ),
}

# The min/max CPU/memory that snooper can use
MIN_CPU = 10
MAX_CPU = 100
MIN_MEMORY = 10
MAX_MEMORY = 600


def launch(plan, service_name, cl_context, node_selectors):
    snooper_service_name = "{0}".format(service_name)

    snooper_config = get_config(service_name, cl_context, node_selectors)

    snooper_service = plan.add_service(snooper_service_name, snooper_config)
    snooper_http_port = snooper_service.ports[SNOOPER_BEACON_RPC_PORT_ID]
    return snooper_beacon_context.new_snooper_beacon_client_context(
        snooper_service.ip_address, SNOOPER_BEACON_RPC_PORT_NUM
    )


def get_config(service_name, cl_context, node_selectors):
    beacon_rpc_port_num = "{0}".format(
        cl_context.beacon_http_url,
    )
    cmd = [
        SNOOPER_BINARY_COMMAND,
        "-b=0.0.0.0",
        "-p={0}".format(SNOOPER_BEACON_RPC_PORT_NUM),
        "{0}".format(beacon_rpc_port_num),
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
