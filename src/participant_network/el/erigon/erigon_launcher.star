load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec", "path_join", "TCP_PROTOCOL", "UDP_PROTOCOL")
load("github.com/kurtosis-tech/eth2-module/src/module_io/parse_input.star", "get_client_log_level_or_default")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/el/el_client_context.star", "new_el_client_context")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/home/erigon/execution-data"

GENESIS_DATA_MOUNT_DIRPATH = "/genesis"

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8550

# Port IDs
RPC_PORT_ID = "rpc"
WS_PORT_ID = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID = "engine-rpc"


PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
	RPC_PORT_ID: new_port_spec(RPC_PORT_NUM, TCP_PROTOCOL),
	WS_PORT_ID: new_port_spec(WS_PORT_NUM, TCP_PROTOCOL),
	TCP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, UDP_PROTOCOL),
}

ENTRYPOINT_ARGS = ["sh", "-c"]

ERIGON_LOG_LEVELS = {
	module_io.GlobalClientLogLevel.error: "1",
	module_io.GlobalClientLogLevel.warn:  "2",
	module_io.GlobalClientLogLevel.info:  "3",
	module_io.GlobalClientLogLevel.debug: "4",
	module_io.GlobalClientLogLevel.trace: "5",
}

ENR_FACT_NAME = "enr-fact"
ENODE_FACT_NAME = "enode-fact"

def launch(
	launcher,
	service_id,
	image,
	participant_log_level,
	global_log_level,
	existing_el_clients,
	extra_params):

	log_level = get_client_log_level_or_default(participant_log_level, global_log_level, ERIGON_LOG_LEVELS)

	config = get_config(launcher.network_id, launcher.el_genesis_data,
                                    image, existing_el_clients, log_level, extra_params)

	service = add_service(service_id, config)

	define_fact(service_id = service_id, fact_name = ENR_FACT_NAME, fact_recipe = struct(method= "POST", endpoint = "", field_extractor = ".result.enr", body = '{"method":"admin_nodeInfo","params":[],"id":1,"jsonrpc":"2.0"}', content_type = "application/json", port_id = RPC_PORT_ID))
	enr = wait(service_id = service_id, fact_name = ENR_FACT_NAME)

	define_fact(service_id = service_id, fact_name = ENODE_FACT_NAME, fact_recipe = struct(method= "POST", endpoint = "", field_extractor = ".result.enode", body = '{"method":"admin_nodeInfo","params":[],"id":1,"jsonrpc":"2.0"}', content_type = "application/json", port_id = RPC_PORT_ID))
	enode = wait(service_id = service_id, fact_name = ENODE_FACT_NAME)

	return new_el_client_context(
		"erigon",
		enr,
		enode,
		service.ip_address,
		RPC_PORT_NUM,
		WS_PORT_NUM,
		ENGINE_RPC_PORT_NUM
	)


def get_config(network_id, genesis_data, image, existing_el_clients, verbosity_level, extra_params):
	network_id = network_id

	genesis_json_filepath_on_client = path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.erigon_genesis_json_relative_filepath)
	jwt_secret_json_filepath_on_client = path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.jwt_secret_relative_filepath)

	init_datadir_cmd_str = "erigon init --datadir={0} {1}".format(
		EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
		genesis_json_filepath_on_client,
	)

	# TODO remove this based on https://github.com/kurtosis-tech/eth2-merge-kurtosis-module/issues/152
	if len(existing_el_clients) == 0:
		fail("Erigon needs at least one node to exist, which it treats as the bootnode")

	boot_node = existing_el_clients[0]

	launch_node_cmd = [
		"erigon",
		"--log.console.verbosity=" + verbosity_level,
		"--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
		"--networkid=" + network_id,
		"--http",
		"--http.addr=0.0.0.0",
		"--http.corsdomain=*",
		# WARNING: The admin info endpoint is enabled so that we can easily get ENR/enode, which means
		#  that users should NOT store private information in these Kurtosis nodes!
		"--http.api=admin,engine,net,eth",
		"--ws",
		"--allow-insecure-unlock",
		"--nat=extip:" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
		"--authrpc.jwtsecret={0}".format(jwt_secret_json_filepath_on_client),
		"--nodiscover",
		"--staticpeers={0}".format(boot_node.enode),
	]

	if len(extra_params) > 0:
		# this is a repeated<proto type>, we convert it into Starlark
		launch_node_cmd.extend([param for param in extra_params])

	command_arg = [
		init_datadir_cmd_str,
		" ".join(launch_node_cmd)
	]

	command_arg_str = " && ".join(command_arg)

	return struct(
		image = image,
		ports = USED_PORTS,
		cmd = [command_arg_str],
		files = {
			genesis_data.files_artifact_uuid: GENESIS_DATA_MOUNT_DIRPATH
		},
		entrypoint = ENTRYPOINT_ARGS,
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def new_erigon_launcher(network_id, el_genesis_data):
	return struct(
		network_id = network_id,
		el_genesis_data = el_genesis_data,
	)
