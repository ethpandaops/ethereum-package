shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")
parse_input = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/parse_input.star")
cl_client_context = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/cl/cl_client_context.star")
cl_node_metrics = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/cl/cl_node_metrics_info.star")
cl_node_health_checker = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/cl/cl_node_health_checker.star")
mev_boost_context_module = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/mev_boost/mev_boost_context.star")

package_io = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/constants.star")

TEKU_BINARY_FILEPATH_IN_IMAGE = "/opt/teku/bin/teku"

GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/genesis"

# The Docker container runs as the "teku" user so we can't write to root
CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/opt/teku/consensus-data"

# These will get mounted as root and Teku needs directory write permissions, so we'll copy this
#  into the Teku user's home directory to get around it
VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER = "/validator-keys"

# TODO(old) Get rid of this being hardcoded; should be shared
VALIDATING_REWARDS_ACCOUNT = "0x0000000000000000000000000000000000000000"

# Port IDs
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
HTTP_PORT_ID         = "http"
METRICS_PORT_ID      = "metrics"

# Port nums
DISCOVERY_PORT_NUM = 9000
HTTP_PORT_NUM             = 4000
METRICS_PORT_NUM = 8008

# 1) The Teku container runs as the "teku" user
# 2) Teku requires write access to the validator secrets directory, so it can write a lockfile into it as it uses the keys
# 3) The module container runs as 'root'
# With these three things combined, it means that when the module container tries to write the validator keys/secrets into
#  the shared directory, it does so as 'root'. When Teku tries to consum the same files, it will get a failure because it
#  doesn't have permission to write to the 'validator-secrets' directory.
# To get around this, we copy the files AGAIN from
DEST_VALIDATOR_KEYS_DIRPATH_IN_SERVICE_CONTAINER    = "$HOME/validator-keys"
DEST_VALIDATOR_SECRETS_DIRPATH_IN_SERVICE_CONTAINER = "$HOME/validator-secrets"

MIN_PEERS = 1

METRICS_PATH = "/metrics"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
	TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL),
	HTTP_PORT_ID:         shared_utils.new_port_spec(HTTP_PORT_NUM, shared_utils.TCP_PROTOCOL),
	METRICS_PORT_ID:      shared_utils.new_port_spec(METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL),
}

ENTRYPOINT_ARGS = ["sh", "-c"]


TEKU_LOG_LEVELS = {
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
	bootnode_context,
	el_client_context,
	mev_boost_context,
	node_keystore_files,
	extra_beacon_params,
	extra_validator_params):

	log_level = parse_input.get_client_log_level_or_default(participant_log_level, global_log_level, TEKU_LOG_LEVELS)

	extra_params = [param for param in extra_beacon_params] + [param for param in extra_validator_params]
	
	config = get_config(launcher.cl_genesis_data, image, bootnode_context, el_client_context, mev_boost_context, log_level, node_keystore_files, extra_params)

	teku_service = plan.add_service(service_name, config)

	cl_node_health_checker.wait_for_healthy(plan, service_name, HTTP_PORT_ID)

	node_identity_recipe = GetHttpRequestRecipe(
		endpoint = "/eth/v1/node/identity",
		port_id = HTTP_PORT_ID,
		extract = {
			"enr": ".data.enr"
		}
	)
	node_enr = plan.request(node_identity_recipe, service_name = service_name)["extract.enr"]


	teku_metrics_port = teku_service.ports[METRICS_PORT_ID]
	teku_metrics_url = "{0}:{1}".format(teku_service.ip_address, teku_metrics_port.number)

	teku_node_metrics_info = cl_node_metrics.new_cl_node_metrics_info(service_name, METRICS_PATH, teku_metrics_url)
	nodes_metrics_info = [teku_node_metrics_info]

	return cl_client_context.new_cl_client_context(
		"teku",
		node_enr,
		teku_service.ip_address,
		HTTP_PORT_NUM,
		nodes_metrics_info,
		service_name
	)


def get_config(
	genesis_data,
	image,
	boot_cl_client_ctx,
	el_client_ctx,
	mev_boost_context,
	log_level,
	node_keystore_files,
	extra_params):

	el_client_rpc_url_str = "http://{0}:{1}".format(
		el_client_ctx.ip_addr,
		el_client_ctx.rpc_port_num,
	)

	el_client_engine_rpc_url_str = "http://{0}:{1}".format(
		el_client_ctx.ip_addr,
		el_client_ctx.engine_rpc_port_num,
	)

	genesis_config_filepath = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.config_yml_rel_filepath)
	genesis_ssz_filepath = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.genesis_ssz_rel_filepath)
	jwt_secret_filepath = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.jwt_secret_rel_filepath)
	validator_keys_dirpath = shared_utils.path_join(VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER, node_keystore_files.teku_keys_relative_dirpath)
	validator_secrets_dirpath = shared_utils.path_join(VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER, node_keystore_files.teku_secrets_relative_dirpath)
	
	cmd = [
		# Needed because the generated keys are owned by root and the Teku image runs as the 'teku' user
		"cp",
		"-R",
		validator_keys_dirpath,
		DEST_VALIDATOR_KEYS_DIRPATH_IN_SERVICE_CONTAINER,
		"&&",
		# Needed because the generated keys are owned by root and the Teku image runs as the 'teku' user
		"cp",
		"-R",
		validator_secrets_dirpath,
		DEST_VALIDATOR_SECRETS_DIRPATH_IN_SERVICE_CONTAINER,
		"&&",
		TEKU_BINARY_FILEPATH_IN_IMAGE,
		"--Xee-version kilnv2",
		"--logging=" + log_level,
		"--log-destination=CONSOLE",
		"--network=" + genesis_config_filepath,
		"--initial-state=" + genesis_ssz_filepath,
		"--data-path=" + CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER,
		"--data-storage-mode=PRUNE",
		"--p2p-enabled=true",
		# Set per Pari's recommendation, to reduce noise in the logs
		"--p2p-subscribe-all-subnets-enabled=true",
		"--p2p-peer-lower-bound={0}".format(MIN_PEERS),
		"--eth1-endpoints=" + el_client_rpc_url_str,
		"--p2p-advertised-ip=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
		"--rest-api-enabled=true",
		"--rest-api-docs-enabled=true",
		"--rest-api-interface=0.0.0.0",
		"--rest-api-port={0}".format(HTTP_PORT_NUM),
		"--rest-api-host-allowlist=*",
		"--data-storage-non-canonical-blocks-enabled=true",
		"--validator-keys={0}:{1}".format(
			DEST_VALIDATOR_KEYS_DIRPATH_IN_SERVICE_CONTAINER,
			DEST_VALIDATOR_SECRETS_DIRPATH_IN_SERVICE_CONTAINER,
		),
		"--ee-jwt-secret-file={0}".format(jwt_secret_filepath),
		"--ee-endpoint=" + el_client_engine_rpc_url_str,
		"--validators-proposer-default-fee-recipient=" + VALIDATING_REWARDS_ACCOUNT,
		# vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
		"--metrics-enabled",
		"--metrics-interface=0.0.0.0",
		"--metrics-host-allowlist='*'",
		"--metrics-categories=BEACON,PROCESS,LIBP2P,JVM,NETWORK,PROCESS",
		"--metrics-port={0}".format(METRICS_PORT_NUM),
		# ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
	]

	if boot_cl_client_ctx != None:
		cmd.append("--p2p-discovery-bootnodes="+boot_cl_client_ctx.enr)

	if mev_boost_context != None:
		cmd.append("--validators-builder-registration-default-enabled=true")
		cmd.append("--builder-endpoint='{0}'".format(mev_boost_context_module.mev_boost_endpoint(mev_boost_context)))


	if len(extra_params) > 0:
		# we do the list comprehension as the default extra_params is a proto repeated string
		cmd.extend([param for param in extra_params])

	cmd_str = " ".join(cmd)

	return ServiceConfig(
		image = image,
		ports = USED_PORTS,
		cmd = [cmd_str],
		entrypoint = ENTRYPOINT_ARGS,
		files = {
			GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid,
			VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
		},
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def new_teku_launcher(cl_genesis_data):
	return struct(
		cl_genesis_data = cl_genesis_data
	)
