shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

PROVER_METRICS_PORT_NUM = 8080
METRICS_PATH = "/metrics"

PROVER_USED_PORTS = {
    constants.METRICS_PORT_ID: shared_utils.new_port_spec(
        PROVER_METRICS_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}
