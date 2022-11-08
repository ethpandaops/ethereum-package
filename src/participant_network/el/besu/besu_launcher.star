load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/opt/besu/execution-data"

GENESIS_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/opt/besu/genesis"

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_HTTP_RPC_PORT_NUM = 8550
ENGINE_WS_RPC_PORT_NUM = 8551

# Port IDs
RPC_PORT_ID = "rpc"
WS_PORT_ID = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_HTTP_RPC_PORT_ID = "engineHttpRpc"
ENGINE_WS_RPC_PORT_ID = "engineWsRpc"

GET_NODE_INFO_MAX_RETRIES = 20
GET_NODE_INFO_TIME_BETWEEN_RETRIES = 1 * time.second

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_PRIVATE_IP_ADDR_PLACEHOLDER"

# TODO push this into shared_utils
TCP_PROTOCOL = "TCP"
UDP_PROTOCOL = "TCP"

USED_PORTS = {
	RPC_PORT_ID: new_port_spec(RPC_PORT_NUM, TCP_PROTOCOL),
	WS_PORT_ID: new_port_spec(WS_PORT_NUM, TCP_PROTOCOL),
	TCP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, UDP_PROTOCOL),
	ENGINE_HTTP_RPC_PORT_ID: new_port_spec(ENGINE_WS_RPC_PORT_NUM, TCP_PROTOCOL)
	ENGINE_WS_RPC_PORT_ID: new_port_spec(ENGINE_WS_RPC_PORT_NUM, TCP_PROTOCOL)
}

ENTRYPOINT_ARGS = ["sh", "-c"]

BESU_LOG_LEVELS = {
	module_io.GlobalClientLogLevel.error: "ERROR",
	module_io.GlobalClientLogLeve.warn:  "WARN",
	module_io.GlobalClientLogLeve.info:  "INFO",
	module_io.GlobalClientLogLevel.debug: "DEBUG",
	module_io.GlobalClientLogLevel.trace: "TRACE",
}