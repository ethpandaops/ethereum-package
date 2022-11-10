load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec", "path_join", "path_dir")
load("github.com/kurtosis-tech/eth2-module/src/module_io/parse_input.star", "get_client_log_level_or_default")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/cl/cl_client_context.star", "new_cl_client_context")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/cl/cl_node_metrics_info.star", "new_cl_node_metrics_info")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/mev_boost/mev_boost_context.star", "mev_boost_endpoint")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

LIGHTHOUSE_BINARY_COMMAND = "lighthouse"

GENESIS_DATA_MOUNTPOINT_ON_CLIENTS = "/genesis"

VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS = "/validator-keys"

RUST_BACKTRACE_ENVVAR_NAME  = "RUST_BACKTRACE"
RUST_FULL_BACKTRACE_KEYWORD = "full"

#  ---------------------------------- Beacon client -------------------------------------
CONSENSUS_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER = "/consensus-data"

# Port IDs
BEACON_TCP_DISCOVERY_PORT_ID = "tcp-discovery"
BEACON_UDP_DISCOVERY_PORT_ID = "udp-discovery"
BEACON_HTTP_PORT_ID         = "http"
BEACON_METRICS_PORT_ID      = "metrics"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_HTTP_PORT_NUM      = 4000
BEACON_METRICS_PORT_NUM   = 5054

# TODO remove if facts & waits doesn't need this
MAX_NUM_HEALTHCHECK_RETRIES      = 10
TIME_BETWEEN_HEALTHCHECK_RETRIES = 1 * time.second

#  ---------------------------------- Validator client -------------------------------------
VALIDATING_REWARDS_ACCOUNT = "0x0000000000000000000000000000000000000000"

VALIDATOR_HTTP_PORT_ID     = "http"
VALIDATOR_METRICS_PORT_ID  = "metrics"
VALIDATOR_HTTP_PORT_NUM    = 5042
VALIDATOR_METRICS_PORT_NUM = 5064

METRICS_PATH = "/metrics"

BEACON_SUFFIX_SERVICE_ID    = "beacon"
VALIDATOR_SUFFIX_SERVICE_ID = "validator"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

# TODO push this into shared_utils
TCP_PROTOCOL = "TCP"
UDP_PROTOCOL = "UDP"

BEACON_USED_PORTS = {
	BEACON_TCP_DISCOVERY_PORT_ID: new_port_spec(BEACON_DISCOVERY_PORT_NUM, TCP_PROTOCOL),
	BEACON_UDP_DISCOVERY_PORT_ID: new_port_spec(BEACON_DISCOVERY_PORT_NUM, UDP_PROTOCOL),
	BEACON_HTTP_PORT_ID:         new_port_spec(BEACON_HTTP_PORT_NUM, TCP_PROTOCOL),
	BEACON_METRICS_PORT_ID:      new_port_spec(BEACON_METRICS_PORT_NUM, TCP_PROTOCOL),
}

VALIDATOR_USED_PORTS = {
	VALIDATOR_HTTP_PORT_ID:    new_port_spec(VALIDATOR_HTTP_PORT_NUM, TCP_PROTOCOL),
	VALIDATOR_METRICS_PORT_ID: new_port_spec(VALIDATOR_METRICS_PORT_NUM, TCP_PROTOCOL),
}

LIGHTHOUSE_LOG_LEVELS = {
	module_io.GlobalClientLogLevel.error: "error",
	module_io.GlobalClientLogLevel.warn:  "warn",
	module_io.GlobalClientLogLevel.info:  "info",
	module_io.GlobalClientLogLevel.debug: "debug",
	module_io.GlobalClientLogLevel.trace: "trace",
}

BEACON_ENR_FACT_NAME = "beacon-enr-fact"
BEACON_HEALTH_FACT_NAME = "beacon-health-fact"

def launch(
	launcher,
	service_id,
	image,
	participant_log_level,
	global_log_level,
	bootnode_context,
	el_client_context,
	mev_boost_context,
	node_keystore_files,
	extra_beacon_params,
	extra_validator_params):

	beacon_node_service_id = "{0}-{1}".format(service_id, BEACON_SUFFIX_SERVICE_ID)
	validator_node_service_id = "{0}-{1}".format(service_id, VALIDATOR_SUFFIX_SERVICE_ID)

	log_level = get_client_log_level_or_default(participant_log_level, global_log_level, LIGHTHOUSE_LOG_LEVELS)

	# Launch Beacon node
	beacon_service_config = get_beacon_service_config(
		launcher.genesis_data,
		image,
		bootnode_context,
		el_client_context,
		mev_boost_context,
		log_level,
		extra_beacon_params,
	)

	beacon_service = add_service(beacon_node_service_id, beacon_service_config)

	# TODO the Golang code checks whether its 200, 206 or 503, maybe add that
	# TODO this fact might start breaking if the endpoint requires a leading slash, currently breaks with a leading slash
	define_fact(service_id = beacon_node_service_id, fact_name = BEACON_HEALTH_FACT_NAME, fact_recipe = struct(method= "GET", endpoint = "eth/v1/node/health", content_type = "application/json", port_id = BEACON_HTTP_PORT_ID))
	wait(service_id = beacon_node_service_id, fact_name = BEACON_HEALTH_FACT_NAME)

	beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]

	# Launch validator node
	beacon_http_url = "http://{0}:{1}".format(beacon_service.ip_address, beacon_http_port.number)

	validator_service_config = get_validator_service_config(
		launcher.genesis_data,
		image,
		log_level,
		beacon_http_url,
		node_keystore_files,
		mev_boost_context,
		extra_validator_params,
	)

	validator_service = add_service(validator_node_service_id, validator_service_config)

	# TODO add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module
	# TODO this fact might start breaking if the endpoint requires a leading slash, currently breaks with a leading slash
	define_fact(service_id = beacon_node_service_id, fact_name = BEACON_ENR_FACT_NAME, fact_recipe = struct(method= "GET", endpoint = "eth/v1/node/identity", field_extractor = ".data.enr", content_type = "application/json", port_id = BEACON_HTTP_PORT_ID))
	beacon_node_enr = wait(service_id = beacon_node_service_id, fact_name = BEACON_ENR_FACT_NAME)

	beacon_metrics_port = beacon_service.ports[BEACON_METRICS_PORT_ID]
	beacon_metrics_url = "{0}:{1}".format(beacon_service.ip_address, beacon_metrics_port.number)

	validator_metrics_port = validator_service.ports[VALIDATOR_METRICS_PORT_ID]
	validator_metrics_url = "{00}:{1}".format(validator_service.ip_address, validator_metrics_port.number)

	beacon_node_metrics_info = new_cl_node_metrics_info(beacon_node_service_id, METRICS_PATH, beacon_metrics_url)
	validator_node_metrics_info = new_cl_node_metrics_info(validator_node_service_id, METRICS_PATH, validator_metrics_url)
	nodes_metrics_info = [beacon_node_metrics_info, validator_node_metrics_info]

	result = new_cl_client_context(
		"lighthouse",
		beacon_node_enr,
		beacon_service.ip_address,
		BEACON_HTTP_PORT_NUM,
		nodes_metrics_info,
	)

	return result

def get_beacon_service_config(
	genesis_data,
	image,
	boot_cl_client_ctx,
	el_client_ctx,
	mev_boost_context,
	log_level,
	extra_params):

	el_client_engine_rpc_url_str = "http://{0}:{1}".format(
		el_client_ctx.ip_addr,
		el_client_ctx.engine_rpc_port_num,
	)

	# For some reason, Lighthouse takes in the parent directory of the config file (rather than the path to the config file itself)
	genesis_config_parent_dirpath_on_client = path_join(GENESIS_DATA_MOUNTPOINT_ON_CLIENTS, path_dir(genesis_data.config_yml_rel_filepath))
	jwt_secret_filepath = path_join(GENESIS_DATA_MOUNTPOINT_ON_CLIENTS, genesis_data.jwt_secret_rel_filepath)

	# NOTE: If connecting to the merge devnet remotely we DON'T want the following flags; when they're not set, the node's external IP address is auto-detected
	#  from the peers it communicates with but when they're set they basically say "override the autodetection and
	#  use what I specify instead." This requires having a know external IP address and port, which we definitely won't
	#  have with a network running in Kurtosis.
	#    "--disable-enr-auto-update",
	#    "--enr-address=" + externalIpAddress,
	#    fmt.Sprintf("--enr-udp-port=%v", BEACON_DISCOVERY_PORT_NUM),
	#    fmt.Sprintf("--enr-tcp-port=%v", beaconDiscoveryPortNum),
	cmd_args = [
		LIGHTHOUSE_BINARY_COMMAND,
		"beacon_node",
		"--debug-level=" + log_level,
		"--datadir=" + CONSENSUS_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER,
		"--testnet-dir=" + genesis_config_parent_dirpath_on_client,
		# vvvvvvvvvvvvvvvvvvv REMOVE THESE WHEN CONNECTING TO EXTERNAL NET vvvvvvvvvvvvvvvvvvvvv
		"--disable-enr-auto-update",
		"--enr-address=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
		"--enr-udp-port={0}".format(BEACON_DISCOVERY_PORT_NUM),
		"--enr-tcp-port={0}".format(BEACON_DISCOVERY_PORT_NUM),
		# ^^^^^^^^^^^^^^^^^^^ REMOVE THESE WHEN CONNECTING TO EXTERNAL NET ^^^^^^^^^^^^^^^^^^^^^
		"--listen-address=0.0.0.0",
		"--port={0}".format(BEACON_DISCOVERY_PORT_NUM), # NOTE: Remove for connecting to external net!
		"--http",
		"--http-address=0.0.0.0",
		"--http-port={0}".format(BEACON_HTTP_PORT_NUM),
		"--http-allow-sync-stalled",
		# NOTE: This comes from:
		#   https://github.com/sigp/lighthouse/blob/7c88f582d955537f7ffff9b2c879dcf5bf80ce13/scripts/local_testnet/beacon_node.sh
		# and the option says it's "useful for testing in smaller networks" (unclear what happens in larger networks)
		"--disable-packet-filter",
		"--execution-endpoints=" + el_client_engine_rpc_url_str,
		"--jwt-secrets=" + jwt_secret_filepath,
		"--suggested-fee-recipient=" + VALIDATING_REWARDS_ACCOUNT,
		# Set per Paris' recommendation to reduce noise in the logs
		"--subscribe-all-subnets",
		# vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
		"--metrics",
		"--metrics-address=0.0.0.0",
		"--metrics-allow-origin=*",
		"--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
		# ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
	]

	if boot_cl_client_ctx != None:
		cmd_args.append("--boot-nodes="+boot_cl_client_ctx.enr)

	if mev_boost_context != None:
		cmd_args.append("--builder")
		cmd_args.append(mev_boost_endpoint(mev_boost_context))


	if len(extra_params) > 0:
		# this is a repeated<proto type>, we convert it into Starlark
		cmd_args.extend([param for param in extra_params])


	return struct(
		container_image_name = image,
		used_ports = BEACON_USED_PORTS,
		cmd_args = cmd_args,
		files_artifact_mount_dirpaths = {
			genesis_data.files_artifact_uuid: GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
		},
		env_vars = {
			RUST_BACKTRACE_ENVVAR_NAME: RUST_FULL_BACKTRACE_KEYWORD
		},
		privaite_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def get_validator_service_config(
	genesis_data,
	image,
	log_level,
	beacon_client_http_url,
	node_keystore_files,
	mev_boost_context,
	extra_params):

	# For some reason, Lighthouse takes in the parent directory of the config file (rather than the path to the config file itself)
	genesis_config_parent_dirpath_on_client = path_join(GENESIS_DATA_MOUNTPOINT_ON_CLIENTS, path_dir(genesis_data.config_yml_rel_filepath))
	validator_keys_dirpath = path_join(VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS, node_keystore_files.raw_keys_relative_dirpath)
	validator_secrets_dirpath = path_join(VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS, node_keystore_files.raw_secrets_relative_dirpath)
	
	cmd_args = [
		"lighthouse",
		"validator_client",
		"--debug-level=" + log_level,
		"--testnet-dir=" + genesis_config_parent_dirpath_on_client,
		"--validators-dir=" + validator_keys_dirpath,
		# NOTE: When secrets-dir is specified, we can't add the --data-dir flag
		"--secrets-dir=" + validator_secrets_dirpath,
		# The node won't have a slashing protection database and will fail to start otherwise
		"--init-slashing-protection",
		"--http",
		"--unencrypted-http-transport",
		"--http-address=0.0.0.0",
		"--http-port={0}".format(VALIDATOR_HTTP_PORT_NUM),
		"--beacon-nodes=" + beacon_client_http_url,
		#"--enable-doppelganger-protection", // Disabled to not have to wait 2 epochs before validator can start
		# burn address - If unset, the validator will scream in its logs
		"--suggested-fee-recipient=0x0000000000000000000000000000000000000000",
		# vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
		"--metrics",
		"--metrics-address=0.0.0.0",
		"--metrics-allow-origin=*",
		"--metrics-port={0}".format(VALIDATOR_METRICS_PORT_NUM),
		# ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
	]

	if mev_boost_context != None:
		cmd_args.append("--builder-proposals")

	if len(extra_params):
		cmd_args.extend([param for param in extra_params])


	return struct(
		container_image_name = image,
		used_ports = VALIDATOR_USED_PORTS,
		cmd_args = cmd_args,
		files_artifact_mount_dirpaths = {
			genesis_data.files_artifact_uuid: GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
			node_keystore_files.files_artifact_uuid: VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS,
		},
		env_vars = {
			RUST_BACKTRACE_ENVVAR_NAME: RUST_FULL_BACKTRACE_KEYWORD
		},
	)



def new_lighthouse_launcher(cl_genesis_data):
	return struct(
		genesis_data = cl_genesis_data,
	)