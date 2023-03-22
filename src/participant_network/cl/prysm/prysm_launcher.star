shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")
parse_input = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/parse_input.star")
cl_client_context = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/cl/cl_client_context.star")
cl_node_metrics = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/cl/cl_node_metrics_info.star")
cl_node_health_checker = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/cl/cl_node_health_checker.star")
mev_boost_context_module = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/mev_boost/mev_boost_context.star")

package_io = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/constants.star")

IMAGE_SEPARATOR_DELIMITER = ","
EXPECTED_NUM_IMAGES       = 2

CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER      = "/consensus-data"
GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER   = "/genesis"
VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/validator-keys"
PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/prysm-password"

# Port IDs
TCP_DISCOVERY_PORT_ID        = "tcp-discovery"
UDP_DISCOVERY_PORT_ID        = "udp-discovery"
RPC_PORT_ID                 = "rpc"
HTTP_PORT_ID                = "http"
BEACON_MONITORING_PORT_ID    = "monitoring"
VALIDATOR_MONITORING_PORT_ID = "monitoring"

# Port nums
DISCOVERY_TCP_PORT_NUM         = 13000
DISCOVERY_UDP_PORT_NUM         = 12000
RPC_PORT_NUM                  = 4000
HTTP_PORT_NUM                 = 3500
BEACON_MONITORING_PORT_NUM     = 8080
VALIDATOR_MONITORING_PORT_NUM  = 8081

BEACON_SUFFIX_SERVICE_NAME    = "beacon"
VALIDATOR_SUFFIX_SERVICE_NAME = "validator"

MIN_PEERS = 1

METRICS_PATH = "/metrics"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

BEACON_NODE_USED_PORTS = {
	TCP_DISCOVERY_PORT_ID:     shared_utils.new_port_spec(DISCOVERY_TCP_PORT_NUM, shared_utils.TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID:     shared_utils.new_port_spec(DISCOVERY_UDP_PORT_NUM, shared_utils.UDP_PROTOCOL),
	RPC_PORT_ID:              shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
	HTTP_PORT_ID:             shared_utils.new_port_spec(HTTP_PORT_NUM, shared_utils.TCP_PROTOCOL),
	BEACON_MONITORING_PORT_ID: shared_utils.new_port_spec(BEACON_MONITORING_PORT_NUM, shared_utils.TCP_PROTOCOL),
}

VALIDATOR_NODE_USED_PORTS = {
	VALIDATOR_MONITORING_PORT_ID: shared_utils.new_port_spec(VALIDATOR_MONITORING_PORT_NUM, shared_utils.TCP_PROTOCOL),
}

PRYSM_LOG_LEVELS = {
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
	images,
	participant_log_level,
	global_log_level,
	bootnode_context,
	el_client_context,
	mev_boost_context,
	node_keystore_files,
	extra_beacon_params,
	extra_validator_params):

	split_images = images.split(IMAGE_SEPARATOR_DELIMITER)
	if len(split_images) != EXPECTED_NUM_IMAGES:
		fail("Expected {0} images but got {1}".format(EXPECTED_NUM_IMAGES, len(split_images)))
	beacon_image, validator_image = split_images

	if beacon_image.strip() == "":
		fail("An empty beacon image was provided")

	if validator_image.strip() == "":
		fail("An empty validator image was provided")


	beacon_node_service_name = "{0}-{1}".format(service_name, BEACON_SUFFIX_SERVICE_NAME)
	validator_node_service_name = "{0}-{1}".format(service_name, VALIDATOR_SUFFIX_SERVICE_NAME)

	log_level = parse_input.get_client_log_level_or_default(participant_log_level, global_log_level, PRYSM_LOG_LEVELS)

	beacon_config = get_beacon_config(
		launcher.genesis_data,
		beacon_image,
		bootnode_context,
		el_client_context,
		mev_boost_context,
		log_level,
		extra_beacon_params,
	)

	beacon_service = plan.add_service(beacon_node_service_name, beacon_config)

	cl_node_health_checker.wait_for_healthy(plan, beacon_node_service_name, HTTP_PORT_ID)

	beacon_http_port = beacon_service.ports[HTTP_PORT_ID]

	# Launch validator node
	beacon_http_endpoint = "{0}:{1}".format(beacon_service.ip_address, HTTP_PORT_NUM)
	beacon_rpc_endpoint = "{0}:{1}".format(beacon_service.ip_address, RPC_PORT_NUM)

	validator_config = get_validator_config(
		launcher.genesis_data,
		validator_image,
		validator_node_service_name,
		log_level,
		beacon_rpc_endpoint,
		beacon_http_endpoint,
		node_keystore_files,
		mev_boost_context,
		extra_validator_params,
		launcher.prysm_password_relative_filepath,
		launcher.prysm_password_artifact_uuid
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

	beacon_metrics_port = beacon_service.ports[BEACON_MONITORING_PORT_ID]
	beacon_metrics_url = "{0}:{1}".format(beacon_service.ip_address, beacon_metrics_port.number)

	validator_metrics_port = validator_service.ports[VALIDATOR_MONITORING_PORT_ID]
	validator_metrics_url = "{0}:{1}".format(validator_service.ip_address, validator_metrics_port.number)

	beacon_node_metrics_info = cl_node_metrics.new_cl_node_metrics_info(beacon_node_service_name, METRICS_PATH, beacon_metrics_url)
	validator_node_metrics_info = cl_node_metrics.new_cl_node_metrics_info(validator_node_service_name, METRICS_PATH, validator_metrics_url)
	nodes_metrics_info = [beacon_node_metrics_info, validator_node_metrics_info]


	return cl_client_context.new_cl_client_context(
		"prysm",
		beacon_node_enr,
		beacon_service.ip_address,
		HTTP_PORT_NUM,
		nodes_metrics_info,
		beacon_node_service_name
	)


def get_beacon_config(
		genesis_data,
		beacon_image,
		bootnode_context,
		el_client_context,
		mev_boost_context,
		log_level,
		extra_params,
	):

	el_client_engine_rpc_url_str = "http://{0}:{1}".format(
		el_client_context.ip_addr,
		el_client_context.engine_rpc_port_num,
	)

	genesis_config_filepath = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.config_yml_rel_filepath)
	genesis_ssz_filepath = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.genesis_ssz_rel_filepath)
	jwt_secret_filepath = shared_utils.path_join(GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, genesis_data.jwt_secret_rel_filepath)


	cmd = [
		"--accept-terms-of-use=true", #it's mandatory in order to run the node
		"--datadir=" + CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER,
		"--chain-config-file=" + genesis_config_filepath,
		"--genesis-state=" + genesis_ssz_filepath,
		"--http-web3provider=" + el_client_engine_rpc_url_str,
		"--rpc-host=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
		"--rpc-port={0}".format(RPC_PORT_NUM),
		"--grpc-gateway-host=0.0.0.0",
		"--grpc-gateway-port={0}".format(HTTP_PORT_NUM),
		"--p2p-tcp-port={0}".format(DISCOVERY_TCP_PORT_NUM),
		"--p2p-udp-port={0}".format(DISCOVERY_UDP_PORT_NUM),
		"--min-sync-peers={0}".format(MIN_PEERS),
		"--verbosity=" + log_level,
		# Set per Pari's recommendation to reduce noise
		"--subscribe-all-subnets=true",
		"--jwt-secret={0}".format(jwt_secret_filepath),
		# vvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
		"--disable-monitoring=false",
		"--monitoring-host=0.0.0.0",
		"--monitoring-port={0}".format(BEACON_MONITORING_PORT_NUM)
		# ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
	]

	if bootnode_context != None:
		cmd.append("--bootstrap-node="+bootnode_context.enr)

	if mev_boost_context != None:
		cmd.append(("--http-mev-relay{0}".format(mev_boost_context_module.mev_boost_endpoint(mev_boost_context))))

	if len(extra_params) > 0:
		# we do the for loop as otherwise its a proto repeated array
		cmd.extend([param for param in extra_params])

	return ServiceConfig(
		image = beacon_image,
		ports = BEACON_NODE_USED_PORTS,
		cmd = cmd,
		files = {
			GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid,
		},
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def get_validator_config(
		genesis_data,
		validator_image,
		service_name,
		log_level,
		beacon_rpc_endpoint,
		beacon_http_endpoint,
		node_keystore_files,
		mev_boost_context,
		extra_params,
		prysm_password_relative_filepath,
		prysm_password_artifact_uuid
	):

	consensus_data_dirpath = shared_utils.path_join(CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER, service_name)
	prysm_keystore_dirpath = shared_utils.path_join(VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, node_keystore_files.prysm_relative_dirpath)
	prysm_password_filepath = shared_utils.path_join(PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, prysm_password_relative_filepath)

	cmd = [
		"--accept-terms-of-use=true",#it's mandatory in order to run the node
		"--prater",                  #it's a tesnet setup, it's mandatory to set a network (https://docs.prylabs.network/docs/install/install-with-script#before-you-begin-pick-your-network-1)
		"--beacon-rpc-gateway-provider=" + beacon_http_endpoint,
		"--beacon-rpc-provider=" + beacon_rpc_endpoint,
		"--wallet-dir=" + prysm_keystore_dirpath,
		"--wallet-password-file=" + prysm_password_filepath,
		"--datadir=" + consensus_data_dirpath,
		"--monitoring-port={0}".format(VALIDATOR_MONITORING_PORT_NUM),
		"--verbosity=" + log_level,
		# TODO(old) SOMETHING ABOUT JWT
		# vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
		"--disable-monitoring=false",
		"--monitoring-host=0.0.0.0",
		"--monitoring-port={0}".format(VALIDATOR_MONITORING_PORT_NUM)
		# ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
	]

	if mev_boost_context != None:
		# TODO(old) required to work?
		# cmdArgs = append(cmdArgs, "--suggested-fee-recipient=0x...")
		cmd.append("--enable-builder")


	if len(extra_params) > 0:
		# we do the for loop as otherwise its a proto repeated array
		cmd.extend([param for param in extra_params])


	return ServiceConfig(
		image = validator_image,
		ports = VALIDATOR_NODE_USED_PORTS,
		cmd = cmd,
		files = {
			GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid,
			VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
			PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: prysm_password_artifact_uuid,			
		},
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def new_prysm_launcher(genesis_data, prysm_password_relative_filepath, prysm_password_artifact_uuid):
	return struct(
		genesis_data = genesis_data,
		prysm_password_artifact_uuid = prysm_password_artifact_uuid,
		prysm_password_relative_filepath = prysm_password_relative_filepath
	)
