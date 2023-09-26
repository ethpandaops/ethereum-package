shared_utils = import_module(
    "github.com/kurtosis-tech/eth-network-package/shared_utils/shared_utils.star"
)
input_parser = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/input_parser.star"
)
el_client_context = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/el_client_context.star"
)
el_admin_node_info = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/el_admin_node_info.star"
)
package_io = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/constants.star"
)
snooper_engine_context = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/snooper/snooper_engine_context.star"
)

SNOOPER_ENGINE_RPC_PORT_NUM = 8561
SNOOPER_ENGINE_RPC_PORT_ID = "http"
SNOOPER_BINARY_COMMAND = "./json_rpc_snoop"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

SNOOPER_USED_PORTS = {
    SNOOPER_ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(
        SNOOPER_ENGINE_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL, wait="5s"
    ),
}


def launch(plan, service_name, image, el_client_context):
    snooper_service_name = "{0}".format(service_name)

    snooper_config = get_config(image, service_name, el_client_context)

    snooper_service = plan.add_service(snooper_service_name, snooper_config)
    snooper_http_port = snooper_service.ports[SNOOPER_ENGINE_RPC_PORT_ID]
    return snooper_engine_context.new_snooper_engine_client_context(
        snooper_service.ip_address, SNOOPER_ENGINE_RPC_PORT_NUM
    )


def get_config(image, service_name, el_client_context):
    engine_rpc_port_num = "http://{0}:{1}".format(
        el_client_context.ip_addr,
        el_client_context.engine_rpc_port_num,
    )
    cmd = [
        SNOOPER_BINARY_COMMAND,
        "-b=0.0.0.0",
        "-p={0}".format(SNOOPER_ENGINE_RPC_PORT_NUM),
        "{0}".format(engine_rpc_port_num),
    ]

    return ServiceConfig(
        image=image,
        ports=SNOOPER_USED_PORTS,
        cmd=cmd,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
