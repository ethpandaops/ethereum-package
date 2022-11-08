load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec", "path_join")
load("github.com/kurtosis-tech/eth2-module/src/module_io/parse_input.star", "get_client_log_level_or_default")
load("github.com/kurtosis-tech/eth2-module/src/el/el_client_context.star", "new_el_client_context")

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


# required for wait & fact maybe
# TODO see if it is otherwise remove
EXPECTED_SECONDS_FOR_ERIGON_INIT = 10
EXPECTED_SECONDS_AFTER_NODE_START_UNTIL_HTTP_SERVER_IS_AVAILABLE = 20
GET_NODE_INFO_TIME_BETWEEN_RETRIES = 1 * time.second

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

# TODO push this into shared_utils
TCP_PROTOCOL = "TCP"
UDP_PROTOCOL = "UDP"

USED_PORTS = {
	RPC_PORT_ID: new_port_spec(RPC_PORT_NUM, TCP_PROTOCOL),
	WS_PORT_ID: new_port_spec(WS_PORT_NUM, TCP_PROTOCOL),
	TCP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, UDP_PROTOCOL),
	ENGINE_RPC_PORT_ID: new_port_spec(ENGINE_RPC_PORT_NUM, TCP_PROTOCOL)
}

ENTRYPOINT_ARGS = ["sh", "-c"]

ERIGON_LOG_LEVELS = {
	module_io.GlobalClientLogLevel.error: "1",
	module_io.GlobalClientLogLeve.warn:  "2",
	module_io.GlobalClientLogLeve.info:  "3",
	module_io.GlobalClientLogLevel.debug: "4",
	module_io.GlobalClientLogLevel.trace: "5",
}

def launch(
	launcher,
	service_id,
	image,
	participant_log_level,
	global_log_level,
	existing_el_clients,
	extra_params):

	log_level = get_client_log_level_or_default(participant_log_level, global_log_level, ERIGON_LOG_LEVELS)

	service_config = get_service_config(launcher.network_id, launcher.el_genesis_data,
                                    image, network_id, existing_el_clients, log_level, extra_params)

	service = add_service(service_id, service_config)

	# TODO add facts & waits

	return new_el_client_context(
		"erigon",
		"", # TODO fetch ENR from wait & fact
		"", # TODO add Enode from wait & fact,
		service.ip_address,
		RPC_PORT_NUM,
		WS_PORT_NUM,
		ENGINE_HTTP_RPC_PORT_NUM
	)


def get_service_config(network_id, genesis_data, image, existing_el_clients, verbosity_level, extra_params):
	network_id = network_id

	genesis_json_filepath_on_client = path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.besu_genesis_json_relative_filepath)
	jwt_secret_json_filepath_on_client = path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.jwt_secret_relative_filepath)

	init_datadir_cmd_str = "erigon init --datadir={0} {1}".format(
		EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
		genesis_json_filepath_on_client,
	)


	if len(existing_el_clients) == 0:
		fail("Erigon needs at least one node to exist, which it treats as the bootnode")

	boot_node = existing_el_clients[0]

	launch_node_cmd_args = [
		"erigon",
		"--verbosity=" + verbosity_level,
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
		"--engine.port={0}".format(ENGINE_RPC_PORT_NUM),
		"--engine.addr=0.0.0.0",
		"--authrpc.jwtsecret={0}".format(jwt_secret_json_filepath_on_client),
		"--nodiscover",
		"--staticpeers={0}".format(boot_node.enode),
	]

	if len(extra_params) > 0:
		launch_node_cmd_args.extend(extra_params)

	command_arg = [
		init_datadir_cmd_str,
		" ".join(launch_node_cmd_args)
	]

	command_arg_str = " && ".join(command_arg)

	return struct(
		container_image_name = image,
		used_ports = USED_PORTS,
		cmd_args = [command_arg_str],
		files_artifact_mount_dirpaths = {
			genesis_data.files_artifact_uuid: GENESIS_DATA_MOUNT_DIRPATH
		},
		entry_point_args = ENTRYPOINT_ARGS,
		# TODO add private IP address place holder when add servicde supports it
		# for now this will work as we use the service config default above
		# https://github.com/kurtosis-tech/kurtosis/pull/290
	)


def new_erigon_launcher(network_id, el_genesis_data):
	return struct(
		network_id = network_id,
		el_genesis_data = el_genesis_data,
	)