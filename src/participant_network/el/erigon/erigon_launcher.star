shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")
parse_input = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/parse_input.star")
el_admin_node_info = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/el/el_admin_node_info.star")
el_client_context = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/el/el_client_context.star")

package_io = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/constants.star")

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
	RPC_PORT_ID: shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
	WS_PORT_ID: shared_utils.new_port_spec(WS_PORT_NUM, shared_utils.TCP_PROTOCOL),
	TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL),
}

ENTRYPOINT_ARGS = ["sh", "-c"]

ERIGON_LOG_LEVELS = {
	package_io.GLOBAL_CLIENT_LOG_LEVEL.error: "1",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.warn:  "2",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.info:  "3",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.debug: "4",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.trace: "5",
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

	log_level = parse_input.get_client_log_level_or_default(participant_log_level, global_log_level, ERIGON_LOG_LEVELS)

	config = get_config(launcher.network_id, launcher.el_genesis_data,
                                    image, existing_el_clients, log_level, extra_params)

	service = plan.add_service(service_name, config)

	enode, enr = el_admin_node_info.get_enode_enr_for_node(plan, service_name, RPC_PORT_ID)

	return el_client_context.new_el_client_context(
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

	genesis_json_filepath_on_client = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.erigon_genesis_json_relative_filepath)
	jwt_secret_json_filepath_on_client = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.jwt_secret_relative_filepath)

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

	return ServiceConfig(
		image = image,
		ports = USED_PORTS,
		cmd = [command_arg_str],
		files = {
			GENESIS_DATA_MOUNT_DIRPATH: genesis_data.files_artifact_uuid
		},
		entrypoint = ENTRYPOINT_ARGS,
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def new_erigon_launcher(network_id, el_genesis_data):
	return struct(
		network_id = network_id,
		el_genesis_data = el_genesis_data,
	)
