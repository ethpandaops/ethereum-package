shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")
parse_input = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/parse_input.star")
cl_client_context = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/cl/cl_client_context.star")
cl_node_metrics = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/cl/cl_node_metrics_info.star")
mev_boost_context_module = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/mev_boost/mev_boost_context.star")
cl_node_health_checker = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/cl/cl_node_health_checker.star")

package_io = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/constants.star")

CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER      = "/consensus-data"
GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER   = "/genesis"
VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/validator-keys"

# Port IDs
TCP_DISCOVERY_PORT_ID     = "tcp-discovery"
UDP_DISCOVERY_PORT_ID     = "udp-discovery"
HTTP_PORT_ID             = "http"
METRICS_PORT_ID          = "metrics"
VALIDATOR_METRICS_PORT_ID = "validator-metrics"

# Port nums
DISCOVERY_PORT_NUM        = 9000
HTTP_PORT_NUM                    = 4000
METRICS_PORT_NUM           = 8008
VALIDATOR_METRICS_PORT_NUM        = 5064

BEACON_SUFFIX_SERVICE_NAME    = "beacon"
VALIDATOR_SUFFIX_SERVICE_NAME = "validator"

METRICS_PATH = "/metrics"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
    TCP_DISCOVERY_PORT_ID:     shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL),
    UDP_DISCOVERY_PORT_ID:     shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL),
    HTTP_PORT_ID:              shared_utils.new_port_spec(HTTP_PORT_NUM, shared_utils.TCP_PROTOCOL),
    METRICS_PORT_ID:           shared_utils.new_port_spec(METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL),
    VALIDATOR_METRICS_PORT_ID: shared_utils.new_port_spec(VALIDATOR_METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL)
}


LODESTAR_LOG_LEVELS = {
	package_io.GLOBAL_CLIENT_LOG_LEVEL.error: "error",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.warn:  "warn",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.info:  "info",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.debug: "debug",
	package_io.GLOBAL_CLIENT_LOG_LEVEL.trace: "trace",
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

	beacon_node_service_name = "{0}-{1}".format(service_name, BEACON_SUFFIX_SERVICE_NAME)
	validator_node_service_name = "{0}-{1}".format(service_name, VALIDATOR_SUFFIX_SERVICE_NAME)

	log_level = parse_input.get_client_log_level_or_default(participant_log_level, global_log_level, LODESTAR_LOG_LEVELS)

	# Launch Beacon node
	beacon_config = get_beacon_config(
		launcher.cl_genesis_data,
		image,
		bootnode_context,
		el_client_context,
		mev_boost_context,
		log_level,
		extra_beacon_params,
	)

	beacon_service = plan.add_service(beacon_node_service_name, beacon_config)

	beacon_http_port = beacon_service.ports[HTTP_PORT_ID]

	cl_node_health_checker.wait_for_healthy(plan, beacon_node_service_name, HTTP_PORT_ID)


	# Launch validator node
	beacon_http_url = "http://{0}:{1}".format(beacon_service.ip_address, beacon_http_port.number)

	validator_config = get_validator_config(
		validator_node_service_name,
		launcher.cl_genesis_data,
		image,
		log_level,
		beacon_http_url,
		node_keystore_files,
		mev_boost_context,
		extra_validator_params,
	)

	validator_service = plan.add_service(validator_node_service_name, validator_config)

	# TODO(old) add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module

	beacon_node_identity_recipe = GetHttpRequestRecipe(
		endpoint = "/eth/v1/node/identity",
		port_id = HTTP_PORT_ID,
		extract = {
			"enr": ".data.enr"
		}
	)
	beacon_node_enr = plan.request(beacon_node_identity_recipe, service_name = beacon_node_service_name)["extract.enr"]

	beacon_metrics_port = beacon_service.ports[METRICS_PORT_ID]
	beacon_metrics_url = "{0}:{1}".format(beacon_service.ip_address, beacon_metrics_port.number)

	beacon_node_metrics_info = cl_node_metrics.new_cl_node_metrics_info(service_name, METRICS_PATH, beacon_metrics_url)
	nodes_metrics_info = [beacon_node_metrics_info]

	return cl_client_context.new_cl_client_context(
		"lodestar",
		beacon_node_enr,
		beacon_service.ip_address,
		HTTP_PORT_NUM,
		nodes_metrics_info,
		beacon_node_service_name
	)


def get_beacon_config(
	genesis_data,
	image,
	boot_cl_client_ctx,
	el_client_ctx,
	mev_boost_context,
	log_level,
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
	cmd = [
		"beacon",
		"--logLevel=" + log_level,
		"--port={0}".format(DISCOVERY_PORT_NUM),
		"--discoveryPort={0}".format(DISCOVERY_PORT_NUM),
		"--dataDir=" + CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER,
		"--paramsFile=" + genesis_config_filepath,
		"--genesisStateFile=" + genesis_ssz_filepath,
		"--eth1.depositContractDeployBlock=0",
		"--network.connectToDiscv5Bootnodes=true",
		"--discv5=true",
		"--eth1=true",
		"--eth1.providerUrls=" + el_client_rpc_url_str,
		"--execution.urls=" + el_client_engine_rpc_url_str,
		"--rest=true",
		"--rest.address=0.0.0.0",
		"--rest.namespace=*",
		"--rest.port={0}".format(HTTP_PORT_NUM),
		"--enr.ip=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
		"--enr.tcp={0}".format(DISCOVERY_PORT_NUM),
		"--enr.udp={0}".format(DISCOVERY_PORT_NUM),
		# Set per Pari's recommendation to reduce noise in the logs
		"--subscribeAllSubnets=true",
		"--jwt-secret={0}".format(jwt_secret_filepath),
		# vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
		"--metrics",
		"--metrics.address=0.0.0.0",
		"--metrics.port={0}".format(METRICS_PORT_NUM),
		# ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
	]

	if boot_cl_client_ctx != None :
		cmd.append("--bootnodes="+boot_cl_client_ctx.enr)
	

	if mev_boost_context != None:
		cmd.append("--builder")
		cmd.append("--builder.urls '{0}'".format(mev_boost_context_module.mev_boost_endpoint(mev_boost_context)))
	

	if len(extra_params) > 0:
		# this is a repeated<proto type>, we convert it into Starlark
		cmd.extend([param for param in extra_params])
	
	return ServiceConfig(
		image = image,
		ports = USED_PORTS,
		cmd = cmd,
		files = {
			GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid
		},
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def get_validator_config(
	service_name,
	genesis_data,
	image,
	log_level,
	beacon_client_http_url,
	node_keystore_files,
	mev_boost_context,
	extra_params):

	root_dirpath = shared_utils.path_join(CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER, service_name)

	genesis_config_filepath = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.config_yml_rel_filepath)
	validator_keys_dirpath = shared_utils.path_join(VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, node_keystore_files.raw_keys_relative_dirpath)
	validator_secrets_dirpath = shared_utils.path_join(VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, node_keystore_files.raw_secrets_relative_dirpath)

	cmd = [
		"validator",
		"--logLevel=" + log_level,
		"--dataDir=" + root_dirpath,
		"--paramsFile=" + genesis_config_filepath,
		"--server=" + beacon_client_http_url,
		"--keystoresDir=" + validator_keys_dirpath,
		"--secretsDir=" + validator_secrets_dirpath,
		# vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
		"--metrics",
		"--metrics.address=0.0.0.0",
		"--metrics.port={0}".format(VALIDATOR_METRICS_PORT_NUM),
		# ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
	]

	if mev_boost_context != None:
		cmd.append("--builder")
		# TODO(old) required to work? - from old module
		# cmdArgs = append(cmdArgs, "--defaultFeeRecipient <your ethereum address>")
	
	if len(extra_params) > 0:
		# this is a repeated<proto type>, we convert it into Starlark
		cmd.extend([param for param in extra_params])


	return ServiceConfig(
		image = image,
		ports = USED_PORTS,
		cmd = cmd,
		files = {
			GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid,
			VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
		},
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def new_lodestar_launcher(cl_genesis_data):
	return struct(
		cl_genesis_data = cl_genesis_data,
	)
