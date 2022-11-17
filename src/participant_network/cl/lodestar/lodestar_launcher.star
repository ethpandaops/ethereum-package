load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec", "path_join", "path_dir", "TCP_PROTOCOL", "UDP_PROTOCOL")
load("github.com/kurtosis-tech/eth2-module/src/module_io/parse_input.star", "get_client_log_level_or_default")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/cl/cl_client_context.star", "new_cl_client_context")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/cl/cl_node_metrics_info.star", "new_cl_node_metrics_info")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/mev_boost/mev_boost_context.star", "mev_boost_endpoint")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

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

BEACON_SUFFIX_SERVICE_ID    = "beacon"
VALIDATOR_SUFFIX_SERVICE_ID = "validator"

METRICS_PATH = "/metrics"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

BEACON_ENR_FACT_NAME = "beacon-enr-fact"
BEACON_HEALTH_FACT_NAME = "beacon-health-fact"

USED_PORTS = {
	TCP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: new_port_spec(DISCOVERY_PORT_NUM, UDP_PROTOCOL),
	HTTP_PORT_ID:         new_port_spec(HTTP_PORT_NUM, TCP_PROTOCOL),
	METRICS_PORT_ID:      new_port_spec(METRICS_PORT_NUM, TCP_PROTOCOL),
	VALIDATOR_METRICS_PORT_ID: new_port_spec(VALIDATOR_METRICS_PORT_NUM, TCP_PROTOCOL)
}


LODESTAR_LOG_LEVELS = {
	module_io.GlobalClientLogLevel.error: "error",
	module_io.GlobalClientLogLevel.warn:  "warn",
	module_io.GlobalClientLogLevel.info:  "info",
	module_io.GlobalClientLogLevel.debug: "debug",
	module_io.GlobalClientLogLevel.trace: "trace",
}


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

	log_level = get_client_log_level_or_default(participant_log_level, global_log_level, LODESTAR_LOG_LEVELS)

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

	beacon_service = add_service(beacon_node_service_id, beacon_config)

	beacon_http_port = beacon_service.ports[HTTP_PORT_ID]

	# TODO check whether its 200, 206 or 503 like golang
	define_fact(service_id = beacon_node_service_id, fact_name = BEACON_HEALTH_FACT_NAME, fact_recipe = struct(method= "GET", endpoint = "/eth/v1/node/health", content_type = "application/json", port_id = HTTP_PORT_ID))
	wait(service_id = beacon_node_service_id, fact_name = BEACON_HEALTH_FACT_NAME)


	# Launch validator node
	beacon_http_url = "http://{0}:{1}".format(beacon_service.ip_address, beacon_http_port.number)

	validator_config = get_validator_config(
		validator_node_service_id,
		launcher.cl_genesis_data,
		image,
		log_level,
		beacon_http_url,
		node_keystore_files,
		mev_boost_context,
		extra_validator_params,
	)

	validator_service = add_service(validator_node_service_id, validator_config)

	# TODO(old) add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module

	define_fact(service_id = beacon_node_service_id, fact_name = BEACON_ENR_FACT_NAME, fact_recipe = struct(method= "GET", endpoint = "/eth/v1/node/identity", field_extractor = ".data.enr", content_type = "application/json", port_id = HTTP_PORT_ID))
	beacon_node_enr = wait(service_id = beacon_node_service_id, fact_name = BEACON_ENR_FACT_NAME)

	beacon_metrics_port = beacon_service.ports[METRICS_PORT_ID]
	beacon_metrics_url = "{0}:{1}".format(beacon_service.ip_address, beacon_metrics_port.number)

	beacon_node_metrics_info = new_cl_node_metrics_info(service_id, METRICS_PATH, beacon_metrics_url)
	nodes_metrics_info = [beacon_node_metrics_info]

	result = new_cl_client_context(
		"lodestar",
		beacon_node_enr,
		beacon_service.ip_address,
		HTTP_PORT_NUM,
		nodes_metrics_info,
		beacon_node_service_id
	)

	return result


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

	genesis_config_filepath = path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.config_yml_rel_filepath)
	genesis_ssz_filepath = path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.genesis_ssz_rel_filepath)
	jwt_secret_filepath = path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.jwt_secret_rel_filepath)
	cmd_args = [
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
		cmd_args.append("--bootnodes="+boot_cl_client_ctx.enr)
	

	if mev_boost_context != None:
		cmd_args.append("--builder")
		cmd_args.append("--builder.urls '{0}'".format(mev_boost_endpoint(mev_boost_context)))
	

	if len(extra_params) > 0:
		# this is a repeated<proto type>, we convert it into Starlark
		cmd_args.extend([param for param in extra_params])
	
	return struct(
		image = image,
		ports = USED_PORTS,
		cmd_args = cmd_args,
		files = {
			genesis_data.files_artifact_uuid: GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER
		},
		privaite_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def get_validator_config(
	service_id,
	genesis_data,
	image,
	log_level,
	beacon_client_http_url,
	node_keystore_files,
	mev_boost_context,
	extra_params):

	root_dirpath = path_join(CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER, service_id)

	genesis_config_filepath = path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.config_yml_rel_filepath)
	validator_keys_dirpath = path_join(VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, node_keystore_files.raw_keys_relative_dirpath)
	validator_secrets_dirpath = path_join(VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, node_keystore_files.raw_secrets_relative_dirpath)

	cmd_args = [
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
		cmd_args.append("--builder")
		# TODO(old) required to work? - from old module
		# cmdArgs = append(cmdArgs, "--defaultFeeRecipient <your ethereum address>")
	
	if len(extra_params) > 0:
		# this is a repeated<proto type>, we convert it into Starlark
		cmd_args.extend([param for param in extra_params])


	return struct(
		image = image,
		ports = USED_PORTS,
		cmd_args = cmd_args,
		files = {
			genesis_data.files_artifact_uuid: GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
			node_keystore_files.files_artifact_uuid: VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER
		},
		privaite_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def new_lodestar_launcher(cl_genesis_data):
	return struct(
		cl_genesis_data = cl_genesis_data,
	)