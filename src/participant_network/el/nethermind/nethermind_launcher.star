shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")
parse_input = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/parse_input.star")
el_client_context = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/el/el_client_context.star")
el_admin_node_info = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/el/el_admin_node_info.star")

package_io = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/constants.star")

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/execution-data"

GENESIS_DATA_MOUNT_DIRPATH = "/genesis"

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551

# Port IDs
RPC_PORT_ID = "rpc"
WS_PORT_ID = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID = "engine-rpc"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
	RPC_PORT_ID: shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
	WS_PORT_ID: shared_utils.new_port_spec(WS_PORT_NUM, shared_utils.TCP_PROTOCOL),
	TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL),
	ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(ENGINE_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL)
}

NETHERMIND_LOG_LEVELS = {
	package_io.GLOBAL_CLIENT_LOG_LEVEL.error: "ERROR",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.warn:  "WARN",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.info:  "INFO",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.debug: "DEBUG",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.trace: "TRACE",
}


def launch(
	plan,
	launcher,
	service_name,
	image,
	participant_log_level,
	global_log_level,
	existing_el_clients,
	extra_params):

	log_level = parse_input.get_client_log_level_or_default(participant_log_level, global_log_level, NETHERMIND_LOG_LEVELS)

	config = get_config(launcher.el_genesis_data, image, existing_el_clients, log_level, extra_params)

	service = plan.add_service(service_name, config)

	enode = el_admin_node_info.get_enode_for_node(plan, service_name, RPC_PORT_ID)

	return el_client_context.new_el_client_context(
		"nethermind",
		"", # nethermind has no ENR in the eth2-merge-kurtosis-module either
		# Nethermind node info endpoint doesn't return ENR field https://docs.nethermind.io/nethermind/ethereum-client/json-rpc/admin
		enode,
		service.ip_address,
		RPC_PORT_NUM,
		WS_PORT_NUM,
		ENGINE_RPC_PORT_NUM,
	)


def get_config(genesis_data, image, existing_el_clients, log_level, extra_params):
	if len(existing_el_clients) < 2:
		fail("Nethermind node cannot be boot nodes, and due to a bug it requires two nodes to exist beforehand")

	bootnode_1 = existing_el_clients[0]
	bootnode_2 = existing_el_clients[1]

	genesis_json_filepath_on_client = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.nethermind_genesis_json_relative_filepath)
	jwt_secret_json_filepath_on_client = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.jwt_secret_relative_filepath)

	command_args = [
		"--config=kiln",
		"--log=" + log_level,
		"--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
		"--Init.ChainSpecPath=" + genesis_json_filepath_on_client,
		"--Init.WebSocketsEnabled=true",
		"--Init.DiagnosticMode=None",
		"--JsonRpc.Enabled=true",
		"--JsonRpc.EnabledModules=net,eth,consensus,subscribe,web3,admin",
		"--JsonRpc.Host=0.0.0.0",
		# TODO(old) Set Eth isMining?
		"--JsonRpc.Port={0}".format(RPC_PORT_NUM),
		"--JsonRpc.WebSocketsPort={0}".format(WS_PORT_NUM),
		"--Network.ExternalIp={0}".format(PRIVATE_IP_ADDRESS_PLACEHOLDER),
		"--Network.LocalIp={0}".format(PRIVATE_IP_ADDRESS_PLACEHOLDER),
		"--Network.DiscoveryPort={0}".format(DISCOVERY_PORT_NUM),
		"--Network.P2PPort={0}".format(DISCOVERY_PORT_NUM),
		"--Merge.Enabled=true",
		"--Merge.TerminalTotalDifficulty=0", # merge has happened already
		"--Merge.TerminalBlockNumber=null",
		"--JsonRpc.JwtSecretFile={0}".format(jwt_secret_json_filepath_on_client),
		"--JsonRpc.AdditionalRpcUrls=[\"http://0.0.0.0:{0}|http;ws|net;eth;subscribe;engine;web3;client\"]".format(ENGINE_RPC_PORT_NUM),
		"--Network.OnlyStaticPeers=true",
		"--Network.StaticPeers={0},{1}".format(
			bootnode_1.enode,
			bootnode_2.enode,
		),
	]

	if len(extra_params) > 0:
		# we do this as extra_params is a repeated proto aray
		command_args.extend([param for param in extra_params])

	return ServiceConfig(
		image = image,
		ports = USED_PORTS,
		cmd = command_args,
		files = {
			GENESIS_DATA_MOUNT_DIRPATH: genesis_data.files_artifact_uuid,
		},
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER,
	)


def new_nethermind_launcher(el_genesis_data):
	return struct(
		el_genesis_data = el_genesis_data
	)
