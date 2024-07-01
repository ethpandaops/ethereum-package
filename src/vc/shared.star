shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

VALIDATOR_HTTP_PORT_NUM = 5056
VALIDATOR_CLIENT_METRICS_PORT_NUM = 8080
METRICS_PATH = "/metrics"

VALIDATOR_CLIENT_USED_PORTS = {
    constants.METRICS_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_CLIENT_METRICS_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

VALIDATOR_KEYMANAGER_USED_PORTS = {
    constants.VALIDATOR_HTTP_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_HTTP_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}
