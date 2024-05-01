shared_utils = import_module("../shared_utils/shared_utils.star")

VALIDATOR_HTTP_PORT_NUM = 5056
VALIDATOR_HTTP_PORT_ID = "vc-http"

VALIDATOR_CLIENT_METRICS_PORT_NUM = 8080
VALIDATOR_CLIENT_METRICS_PORT_ID = "metrics"
METRICS_PATH = "/metrics"

VALIDATOR_CLIENT_USED_PORTS = {
    VALIDATOR_CLIENT_METRICS_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_CLIENT_METRICS_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

VALIDATOR_KEYMANAGER_USED_PORTS = {
    VALIDATOR_HTTP_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_HTTP_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}
