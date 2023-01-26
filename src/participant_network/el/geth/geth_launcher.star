shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")
parse_input = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/parse_input.star")
el_client_context = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/el/el_client_context.star")
el_admin_node_info = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/el/el_admin_node_info.star")

package_io = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/constants.star")


RPC_PORT_NUM       = 8545
WS_PORT_NUM        = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551

# Port IDs
RPC_PORT_ID          = "rpc"
WS_PORT_ID           = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID    = "engine-rpc"
ENGINE_WS_PORT_ID     = "engineWs"

# TODO(old) Scale this dynamically based on CPUs available and Geth nodes mining
NUM_MINING_THREADS = 1

GENESIS_DATA_MOUNT_DIRPATH = "/genesis"

PREFUNDED_KEYS_MOUNT_DIRPATH = "/prefunded-keys"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/execution-data"
KEYSTORE_DIRPATH_ON_CLIENT_CONTAINER      = EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER + "/keystore"

GETH_ACCOUNT_PASSWORD      = "password"          #  Password that the Geth accounts will be locked with
GETH_ACCOUNT_PASSWORDS_FILE = "/tmp/password.txt" #  Importing an account to

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
	RPC_PORT_ID: shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
	WS_PORT_ID: shared_utils.new_port_spec(WS_PORT_NUM, shared_utils.TCP_PROTOCOL),
	TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL),
	ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(ENGINE_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL)
}

ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
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
	# If empty then the node will be launched as a bootnode
	existing_el_clients,
	extra_params):


	log_level = parse_input.get_client_log_level_or_default(participant_log_level, global_log_level, VERBOSITY_LEVELS)

	config = get_config(launcher.network_id, launcher.el_genesis_data, launcher.prefunded_geth_keys_artifact_uuid,
                                    launcher.prefunded_account_info, image, existing_el_clients, log_level, extra_params)

	service = plan.add_service(service_name, config)

	enode, enr = el_admin_node_info.get_enode_enr_for_node(plan, service_name, RPC_PORT_ID)

	return el_client_context.new_el_client_context(
		"geth",
		enr,
		enode,
		service.ip_address,
		RPC_PORT_NUM,
		WS_PORT_NUM,
		ENGINE_RPC_PORT_NUM
	)

def get_config(network_id, genesis_data, prefunded_geth_keys_artifact_uuid, prefunded_account_info, image, existing_el_clients, verbosity_level, extra_params):

	genesis_json_filepath_on_client = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.geth_genesis_json_relative_filepath)
	jwt_secret_json_filepath_on_client = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH, genesis_data.jwt_secret_relative_filepath)

	account_addresses_to_unlock = []
	for prefunded_account in prefunded_account_info:
		account_addresses_to_unlock.append(prefunded_account.address)


	accounts_to_unlock_str = ",".join(account_addresses_to_unlock)

	init_datadir_cmd_str = "geth init --datadir={0} {1}".format(
		EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
		genesis_json_filepath_on_client,
	)

	# We need to put the keys into the right spot
	copy_keys_into_keystore_cmd_str = "cp -r {0}/* {1}/".format(
		PREFUNDED_KEYS_MOUNT_DIRPATH,
		KEYSTORE_DIRPATH_ON_CLIENT_CONTAINER,
	)

	create_passwords_file_cmd_str = '{' + ' for i in $(seq 1 {0}); do echo "{1}" >> {2}; done; '.format(
		len(prefunded_account_info),
		GETH_ACCOUNT_PASSWORD,
		GETH_ACCOUNT_PASSWORDS_FILE,
	) + '}'

	launch_node_cmd = [
		"geth",
		"--verbosity=" + verbosity_level,
		"--unlock=" + accounts_to_unlock_str,
		"--password=" + GETH_ACCOUNT_PASSWORDS_FILE,
		"--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
		"--networkid=" + network_id,
		"--http",
		"--http.addr=0.0.0.0",
		"--http.vhosts=*",
		"--http.corsdomain=*",
		# WARNING: The admin info endpoint is enabled so that we can easily get ENR/enode, which means
		#  that users should NOT store private information in these Kurtosis nodes!
		"--http.api=admin,engine,net,eth",
		"--ws",
		"--ws.addr=0.0.0.0",
		"--ws.port={0}".format(WS_PORT_NUM),
		"--ws.api=engine,net,eth",
		"--ws.origins=*",
		"--allow-insecure-unlock",
		"--nat=extip:" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
		"--verbosity=" + verbosity_level,
		"--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
		"--authrpc.addr=0.0.0.0",
		"--authrpc.vhosts=*",
		"--authrpc.jwtsecret={0}".format(jwt_secret_json_filepath_on_client),
		"--syncmode=full",
	]

	bootnode_enode = ""
	if len(existing_el_clients) > 0:
		bootnode_context = existing_el_clients[0]
		bootnode_enode = bootnode_context.enode

	launch_node_cmd.append(
		'--bootnodes="{0}"'.format(bootnode_enode),
	)

	if len(extra_params) > 0:
		# this is a repeated<proto type>, we convert it into Starlark
		launch_node_cmd.extend([param for param in extra_params])


	launch_node_cmd_str = " ".join(launch_node_cmd)

	subcommand_strs = [
		init_datadir_cmd_str,
		copy_keys_into_keystore_cmd_str,
		create_passwords_file_cmd_str,
		launch_node_cmd_str,
	]
	command_str = " && ".join(subcommand_strs)

	return ServiceConfig(
		image = image,
		ports = USED_PORTS,
		cmd = [command_str],
		files = {
			GENESIS_DATA_MOUNT_DIRPATH: genesis_data.files_artifact_uuid,
			PREFUNDED_KEYS_MOUNT_DIRPATH: prefunded_geth_keys_artifact_uuid
		},
		entrypoint = ENTRYPOINT_ARGS,
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def new_geth_launcher(network_id, el_genesis_data, prefunded_geth_keys_artifact_uuid, prefunded_account_info):
	return struct(
		network_id = network_id,
		el_genesis_data = el_genesis_data,
		prefunded_account_info = prefunded_account_info,
		prefunded_geth_keys_artifact_uuid = prefunded_geth_keys_artifact_uuid,
	)
