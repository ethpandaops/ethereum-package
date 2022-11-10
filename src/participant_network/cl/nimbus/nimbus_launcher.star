load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec", "path_join", "path_dir")
load("github.com/kurtosis-tech/eth2-module/src/module_io/parse_input.star", "get_client_log_level_or_default")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/cl/cl_client_context.star", "new_cl_client_context")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/cl/cl_node_metrics_info.star", "new_cl_node_metrics_info")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/mev_boost/mev_boost_context.star", "mev_boost_endpoint")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

GENESIS_DATA_MOUNTPOINT_ON_CLIENT = "/genesis-data"

VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENT = "/validator-keys"

# Port IDs
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
HTTP_PORT_ID         = "http"
METRICS_PORT_ID      = "metrics"

# Port nums
DISCOVERY_PORT_NUM = 9000
HTTP_PORT_NUM             = 4000
METRICS_PORT_NUM          = 8008

# Nimbus requires that its data directory already exists (because it expects you to bind-mount it), so we
#  have to to create it
CONSENSUS_DATA_DIRPATH_IN_SERVICE_CONTAINER = "$HOME/consensus-data"
CONSENSUS_DATA_DIR_PERMS_STR               = "0700" # Nimbus wants the data dir to have these perms

# The entrypoint the image normally starts with (we need to override the entrypoint to create the
#  consensus data directory on the image before it starts)
DEFAULT_IMAGE_ENTRYPOINT = "/home/user/nimbus-eth2/build/nimbus_beacon_node"

# Nimbus needs write access to the validator keys/secrets directories, and b/c the module container runs as root
#  while the Nimbus container does not, we can't just point the Nimbus binary to the paths in the shared dir because
#  it won't be able to open them. To get around this, we copy the validator keys/secrets to a path inside the Nimbus
#  container that is owned by the container's user
VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER    = "$HOME/validator-keys"
VALIDATOR_SECRETS_DIRPATH_ON_SERVICE_CONTAINER = "$HOME/validator-secrets"

# TODO remove this if time and wait cant use this
MAX_NUM_HEALTHCHECK_RETRIES      = 60
TIME_BETWEEN_HEALTHCHECK_RETRIES = 1 * time.second

METRICS_PATH = "/metrics"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_PRIVATE_IP_ADDR_PLACEHOLDER"

# TODO push this into shared_utils
TCP_PROTOCOL = "TCP"
UDP_PROTOCOL = "UDP"

USED_PORTS = {
	TCP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, UDP_PROTOCOL),
	HTTP_PORT_ID:         new_port_spec(HTTP_PORT_NUM, TCP_PROTOCOL),
	METRICS_PORT_ID:      new_port_spec(METRICS_PORT_NUM, TCP_PROTOCOL),
}

NIMBUS_LOG_LEVELS = {
	module_io.GlobalClientLogLevel.error: "ERROR",
	module_io.GlobalClientLogLevel.warn:  "WARN",
	module_io.GlobalClientLogLevel.info:  "INFO",
	module_io.GlobalClientLogLevel.debug: "DEBUG",
	module_io.GlobalClientLogLevel.trace: "TRACE",
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

	log_level = get_client_log_level_or_default(participant_log_level, global_log_level, NIMBUS_LOG_LEVELS)

	extra_params = [param for param in extra_beacon_params] + [param for param in extra_validator_params]

	beacon_service_config = get_beacon_service_config(launcher.cl_genesis_data, image, bootnode_context, el_client_context, mev_boost_context, log_level, node_keystore_files, extra_params)

	beacon_service = add_service(service_id, beacon_service_config)

	beacon_http_port = beacon_service.ports[HTTP_PORT_ID]

	# TODO the Golang code checks whether its 200, 206 or 503, maybe add that
	# TODO this fact might start breaking if the endpoint requires a leading slash, currently breaks with a leading slash
	define_fact(service_id = service_id, fact_name = BEACON_HEALTH_FACT_NAME, fact_recipe = struct(method= "GET", endpoint = "eth/v1/node/health", content_type = "application/json", port_id = HTTP_PORT_ID))
	wait(service_id = service_id, fact_name = BEACON_HEALTH_FACT_NAME)

	define_fact(service_id = service_id, fact_name = BEACON_ENR_FACT_NAME, fact_recipe = struct(method= "GET", endpoint = "eth/v1/node/identity", field_extractor = ".data.enr", content_type = "application/json", port_id = HTTP_PORT_ID))
	beacon_node_enr = wait(service_id = service_id, fact_name = BEACON_ENR_FACT_NAME)

	beacon_metrics_port = beacon_service.ports[METRICS_PORT_ID]
	beacon_metrics_url = "{0}:{1}".format(beacon_service.ip_address, beacon_metrics_port.number)

	# TODO verify if this is correct - from eth2-merge-kurtosis-module
	# why do we pass the "service_id" that isn't used
	beacon_node_metrics_info = new_cl_node_metrics_info(service_id, METRICS_PATH, beacon_metrics_url)
	nodes_metrics_info = [beacon_node_metrics_info]


	# Launch validator node
	beacon_http_url = "http://{0}:{1}".format(beacon_service.ip_address, beacon_http_port.number)

	result = new_cl_client_context(
		"nimbu",
		beacon_node_enr,
		beacon_service.ip_address,
		HTTP_PORT_NUM,
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
	node_keystore_files,
	extra_params):

	el_client_engine_rpc_url_str = "http://{0}:{1}".format(
		el_client_ctx.ip_addr,
		el_client_ctx.engine_rpc_port_num,
	)

	# For some reason, Nimbus takes in the parent directory of the config file (rather than the path to the config file itself)
	genesis_config_parent_dirpath_on_client = path_join(GENESIS_DATA_MOUNTPOINT_ON_CLIENT, path_dir(genesis_data.config_yml_rel_filepath))
	jwt_secret_filepath = path_join(GENESIS_DATA_MOUNTPOINT_ON_CLIENT, genesis_data.jwt_secret_rel_filepath)
	validator_keys_dirpath = path_join(VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENT, node_keystore_files.nimbus_keys_relative_dirpath)
	validator_secrets_dirpath = path_join(VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENT, node_keystore_files.raw_secrets_relative_dirpath)

	# Sources for these flags:
	#  1) https://github.com/status-im/nimbus-eth2/blob/stable/scripts/launch_local_testnet.sh
	#  2) https://github.com/status-im/nimbus-eth2/blob/67ab477a27e358d605e99bffeb67f98d18218eca/scripts/launch_local_testnet.sh#L417
	# WARNING: Do NOT set the --max-peers flag here, as doing so to the exact number of nodes seems to mess things up!
	# See: https://github.com/kurtosis-tech/eth2-merge-kurtosis-module/issues/26
	cmd_args = [
		"mkdir",
		CONSENSUS_DATA_DIRPATH_IN_SERVICE_CONTAINER,
		"-m",
		CONSENSUS_DATA_DIR_PERMS_STR,
		"&&",
		# TODO COMMENT THIS OUT?
		"cp",
		"-R",
		validator_keys_dirpath,
		VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
		"&&",
		"cp",
		"-R",
		validator_secrets_dirpath,
		VALIDATOR_SECRETS_DIRPATH_ON_SERVICE_CONTAINER,
		"&&",
		# If we don't do this chmod, Nimbus will spend a crazy amount of time manually correcting them
		#  before it starts
		"chmod",
		"600",
		VALIDATOR_SECRETS_DIRPATH_ON_SERVICE_CONTAINER + "/*",
		"&&",
		DEFAULT_IMAGE_ENTRYPOINT,
		"--non-interactive=true",
		"--log-level=" + log_level,
		"--network=" + genesis_config_parent_dirpath_on_client,
		"--data-dir=" + CONSENSUS_DATA_DIRPATH_IN_SERVICE_CONTAINER,
		"--web3-url=" + el_client_engine_rpc_url_str,
		"--nat=extip:" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
		"--enr-auto-update=false",
		"--rest",
		"--rest-address=0.0.0.0",
		"--rest-port={0}".format(HTTP_PORT_NUM),
		"--validators-dir=" + VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
		"--secrets-dir=" + VALIDATOR_SECRETS_DIRPATH_ON_SERVICE_CONTAINER,
		# There's a bug where if we don't set this flag, the Nimbus nodes won't work:
		# https://discord.com/channels/641364059387854899/674288681737256970/922890280120750170
		# https://github.com/status-im/nimbus-eth2/issues/2451
		"--doppelganger-detection=false",
		# Set per Pari's recommendation to reduce noise in the logs
		"--subscribe-all-subnets=true",
		# Nimbus can handle a max of 256 threads, if the host has more then nimbus crashes. Setting it to 4 so it doesn't crash on build servers
		"--num-threads=4",
		"--jwt-secret={0}".format(jwt_secret_filepath),
		# vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
		"--metrics",
		"--metrics-address=0.0.0.0",
		"--metrics-port={0}".format(METRICS_PORT_NUM),
		# ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
	]
	if boot_cl_client_ctx == None:
		# Copied from https://.com/status-im/nimbus-eth2/blob/67ab477a27e358d605e99bffeb67f98d18218eca/scripts/launch_local_testnet.sh#L417
		# See explanation there
		cmd_args.append("--subscribe-all-subnets")
	else:
		cmd_args.append("--bootstrap-node="+boot_cl_client_ctx.enr)

	if mev_boost_context != None:
		# TODO add `mev-boost` support once the feature lands on `stable` - from eth2-merge-kurtosis-module
		pass


	if len(extra_params) > 0:
		cmd_args.extend([param for param in extra_params])

	cmd_str = " ".join(cmd_args)

	return struct(
		container_image_name = image,
		used_ports = USED_PORTS,
		cmd_args = cmd_args,
		entry_point_args = ["sh", "-c"],
		files_artifact_mount_dirpaths = {
			genesis_data.files_artifact_uuid: GENESIS_DATA_MOUNTPOINT_ON_CLIENT,
			node_keystore_files.files_artifact_uuid: VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENT
		},
		privaite_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def new_nimbus_launcher(cl_genesis_data):
	return struct(
		cl_genesis_data = cl_genesis_data,
	)
