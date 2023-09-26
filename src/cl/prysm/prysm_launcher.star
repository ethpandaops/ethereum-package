shared_utils = import_module(
    "github.com/kurtosis-tech/eth-network-package/shared_utils/shared_utils.star"
)
input_parser = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/input_parser.star"
)
cl_client_context = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/cl/cl_client_context.star"
)
node_metrics = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/node_metrics_info.star"
)
cl_node_ready_conditions = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/cl/cl_node_ready_conditions.star"
)
package_io = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/constants.star"
)

IMAGE_SEPARATOR_DELIMITER = ","
EXPECTED_NUM_IMAGES = 2
#  ---------------------------------- Beacon client -------------------------------------
CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/consensus-data"
GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/genesis"


# Port IDs
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
RPC_PORT_ID = "rpc"
HTTP_PORT_ID = "http"
BEACON_MONITORING_PORT_ID = "monitoring"

# Port nums
DISCOVERY_TCP_PORT_NUM = 13000
DISCOVERY_UDP_PORT_NUM = 12000
RPC_PORT_NUM = 4000
HTTP_PORT_NUM = 3500
BEACON_MONITORING_PORT_NUM = 8080

# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 50
BEACON_MAX_CPU = 1000
BEACON_MIN_MEMORY = 256
BEACON_MAX_MEMORY = 1024

#  ---------------------------------- Validator client -------------------------------------
VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/validator-keys"
PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/prysm-password"

# Port IDs
VALIDATOR_MONITORING_PORT_NUM = 8081
VALIDATOR_MONITORING_PORT_ID = "monitoring"

METRICS_PATH = "/metrics"
VALIDATOR_SUFFIX_SERVICE_NAME = "validator"

# The min/max CPU/memory that the validator node can use
VALIDATOR_MIN_CPU = 50
VALIDATOR_MAX_CPU = 300
VALIDATOR_MIN_MEMORY = 64
VALIDATOR_MAX_MEMORY = 256


MIN_PEERS = 1

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

BEACON_NODE_USED_PORTS = {
    TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_TCP_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_UDP_PORT_NUM, shared_utils.UDP_PROTOCOL
    ),
    RPC_PORT_ID: shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
    HTTP_PORT_ID: shared_utils.new_port_spec(HTTP_PORT_NUM, shared_utils.TCP_PROTOCOL),
    BEACON_MONITORING_PORT_ID: shared_utils.new_port_spec(
        BEACON_MONITORING_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}

VALIDATOR_NODE_USED_PORTS = {
    VALIDATOR_MONITORING_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_MONITORING_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}

PRYSM_LOG_LEVELS = {
    package_io.GLOBAL_CLIENT_LOG_LEVEL.error: "error",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.warn: "warn",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.info: "info",
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
    bootnode_contexts,
    el_client_context,
    node_keystore_files,
    bn_min_cpu,
    bn_max_cpu,
    bn_min_mem,
    bn_max_mem,
    v_min_cpu,
    v_max_cpu,
    v_min_mem,
    v_max_mem,
    snooper_enabled,
    snooper_engine_context,
    extra_beacon_params,
    extra_validator_params,
):
    split_images = images.split(IMAGE_SEPARATOR_DELIMITER)
    if len(split_images) != EXPECTED_NUM_IMAGES:
        fail(
            "Expected {0} images but got {1}".format(
                EXPECTED_NUM_IMAGES, len(split_images)
            )
        )
    beacon_image, validator_image = split_images

    if beacon_image.strip() == "":
        fail("An empty beacon image was provided")

    if validator_image.strip() == "":
        fail("An empty validator image was provided")

    beacon_node_service_name = "{0}".format(service_name)
    validator_node_service_name = "{0}-{1}".format(
        service_name, VALIDATOR_SUFFIX_SERVICE_NAME
    )
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, PRYSM_LOG_LEVELS
    )

    bn_min_cpu = int(bn_min_cpu) if int(bn_min_cpu) > 0 else BEACON_MIN_CPU
    bn_max_cpu = int(bn_max_cpu) if int(bn_max_cpu) > 0 else BEACON_MAX_CPU
    bn_min_mem = int(bn_min_mem) if int(bn_min_mem) > 0 else BEACON_MIN_MEMORY
    bn_max_mem = int(bn_max_mem) if int(bn_max_mem) > 0 else BEACON_MAX_MEMORY

    beacon_config = get_beacon_config(
        launcher.genesis_data,
        beacon_image,
        bootnode_contexts,
        el_client_context,
        log_level,
        bn_min_cpu,
        bn_max_cpu,
        bn_min_mem,
        bn_max_mem,
        snooper_enabled,
        snooper_engine_context,
        extra_beacon_params,
    )

    beacon_service = plan.add_service(beacon_node_service_name, beacon_config)

    beacon_http_port = beacon_service.ports[HTTP_PORT_ID]

    beacon_http_endpoint = "{0}:{1}".format(beacon_service.ip_address, HTTP_PORT_NUM)
    beacon_rpc_endpoint = "{0}:{1}".format(beacon_service.ip_address, RPC_PORT_NUM)

    # Launch validator node if we have a keystore file
    validator_service = None
    if node_keystore_files != None:
        v_min_cpu = int(v_min_cpu) if int(v_min_cpu) > 0 else VALIDATOR_MIN_CPU
        v_max_cpu = int(v_max_cpu) if int(v_max_cpu) > 0 else VALIDATOR_MAX_CPU
        v_min_mem = int(v_min_mem) if int(v_min_mem) > 0 else VALIDATOR_MIN_MEMORY
        v_max_mem = int(v_max_mem) if int(v_max_mem) > 0 else VALIDATOR_MAX_MEMORY
        validator_config = get_validator_config(
            launcher.genesis_data,
            validator_image,
            validator_node_service_name,
            log_level,
            beacon_rpc_endpoint,
            beacon_http_endpoint,
            node_keystore_files,
            v_min_cpu,
            v_max_cpu,
            v_min_mem,
            v_max_mem,
            extra_validator_params,
            launcher.prysm_password_relative_filepath,
            launcher.prysm_password_artifact_uuid,
        )

        validator_service = plan.add_service(
            validator_node_service_name, validator_config
        )

    # TODO(old) add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module
    beacon_node_identity_recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=HTTP_PORT_ID,
        extract={
            "enr": ".data.enr",
            "multiaddr": ".data.discovery_addresses[0]",
            "peer_id": ".data.peer_id",
        },
    )
    response = plan.request(
        recipe=beacon_node_identity_recipe, service_name=beacon_node_service_name
    )
    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    beacon_metrics_port = beacon_service.ports[BEACON_MONITORING_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(
        beacon_service.ip_address, beacon_metrics_port.number
    )
    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        beacon_node_service_name, METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    if validator_service:
        validator_metrics_port = validator_service.ports[VALIDATOR_MONITORING_PORT_ID]
        validator_metrics_url = "{0}:{1}".format(
            validator_service.ip_address, validator_metrics_port.number
        )
        validator_node_metrics_info = node_metrics.new_node_metrics_info(
            validator_node_service_name, METRICS_PATH, validator_metrics_url
        )
        nodes_metrics_info.append(validator_node_metrics_info)

    return cl_client_context.new_cl_client_context(
        "prysm",
        beacon_node_enr,
        beacon_service.ip_address,
        HTTP_PORT_NUM,
        nodes_metrics_info,
        beacon_node_service_name,
        validator_node_service_name,
        beacon_multiaddr,
        beacon_peer_id,
        snooper_enabled,
        snooper_engine_context,
    )


def get_beacon_config(
    genesis_data,
    beacon_image,
    bootnode_contexts,
    el_client_context,
    log_level,
    bn_min_cpu,
    bn_max_cpu,
    bn_min_mem,
    bn_max_mem,
    snooper_enabled,
    snooper_engine_context,
    extra_params,
):
    # If snooper is enabled use the snooper engine context, otherwise use the execution client context
    if snooper_enabled:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            snooper_engine_context.ip_addr,
            snooper_engine_context.engine_rpc_port_num,
        )
    else:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            el_client_context.ip_addr,
            el_client_context.engine_rpc_port_num,
        )

    genesis_config_filepath = shared_utils.path_join(
        GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        genesis_data.config_yml_rel_filepath,
    )
    genesis_ssz_filepath = shared_utils.path_join(
        GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        genesis_data.genesis_ssz_rel_filepath,
    )
    jwt_secret_filepath = shared_utils.path_join(
        GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        genesis_data.jwt_secret_rel_filepath,
    )

    cmd = [
        "--accept-terms-of-use=true",  # it's mandatory in order to run the node
        "--datadir=" + CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--chain-config-file=" + genesis_config_filepath,
        "--genesis-state=" + genesis_ssz_filepath,
        "--execution-endpoint=" + EXECUTION_ENGINE_ENDPOINT,
        "--rpc-host=0.0.0.0",
        "--rpc-port={0}".format(RPC_PORT_NUM),
        "--grpc-gateway-host=0.0.0.0",
        "--grpc-gateway-corsdomain=*",
        "--grpc-gateway-port={0}".format(HTTP_PORT_NUM),
        "--p2p-host-ip=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--p2p-tcp-port={0}".format(DISCOVERY_TCP_PORT_NUM),
        "--p2p-udp-port={0}".format(DISCOVERY_UDP_PORT_NUM),
        "--min-sync-peers={0}".format(MIN_PEERS),
        "--verbosity=" + log_level,
        "--slots-per-archive-point={0}".format(32 if package_io.ARCHIVE_MODE else 8192),
        "--suggested-fee-recipient=" + package_io.VALIDATING_REWARDS_ACCOUNT,
        # Set per Pari's recommendation to reduce noise
        "--subscribe-all-subnets=true",
        "--jwt-secret={0}".format(jwt_secret_filepath),
        # vvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(BEACON_MONITORING_PORT_NUM)
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    if bootnode_contexts != None:
        for ctx in bootnode_contexts[: package_io.MAX_ENR_ENTRIES]:
            cmd.append("--peer=" + ctx.multiaddr)
            cmd.append("--bootstrap-node=" + ctx.enr)
        cmd.append("--p2p-static-id=true")

    if len(extra_params) > 0:
        # we do the for loop as otherwise its a proto repeated array
        cmd.extend([param for param in extra_params])

    return ServiceConfig(
        image=beacon_image,
        ports=BEACON_NODE_USED_PORTS,
        cmd=cmd,
        files={
            GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid,
        },
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ready_conditions=cl_node_ready_conditions.get_ready_conditions(HTTP_PORT_ID),
        min_cpu=bn_min_cpu,
        max_cpu=bn_max_cpu,
        min_memory=bn_min_mem,
        max_memory=bn_max_mem,
    )


def get_validator_config(
    genesis_data,
    validator_image,
    service_name,
    log_level,
    beacon_rpc_endpoint,
    beacon_http_endpoint,
    node_keystore_files,
    v_min_cpu,
    v_max_cpu,
    v_min_mem,
    v_max_mem,
    extra_params,
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
):
    consensus_data_dirpath = shared_utils.path_join(
        CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER, service_name
    )
    genesis_config_filepath = shared_utils.path_join(
        GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        genesis_data.config_yml_rel_filepath,
    )

    validator_keys_dirpath = shared_utils.path_join(
        VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.prysm_relative_dirpath,
    )
    validator_secrets_dirpath = shared_utils.path_join(
        PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        prysm_password_relative_filepath,
    )

    cmd = [
        "--accept-terms-of-use=true",  # it's mandatory in order to run the node
        "--chain-config-file=" + genesis_config_filepath,
        "--beacon-rpc-gateway-provider=" + beacon_http_endpoint,
        "--beacon-rpc-provider=" + beacon_rpc_endpoint,
        "--wallet-dir=" + validator_keys_dirpath,
        "--wallet-password-file=" + validator_secrets_dirpath,
        "--datadir=" + consensus_data_dirpath,
        "--monitoring-port={0}".format(VALIDATOR_MONITORING_PORT_NUM),
        "--verbosity=" + log_level,
        "--suggested-fee-recipient=" + package_io.VALIDATING_REWARDS_ACCOUNT,
        # TODO(old) SOMETHING ABOUT JWT
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(VALIDATOR_MONITORING_PORT_NUM)
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    if len(extra_params) > 0:
        # we do the for loop as otherwise its a proto repeated array
        cmd.extend([param for param in extra_params])

    return ServiceConfig(
        image=validator_image,
        ports=VALIDATOR_NODE_USED_PORTS,
        cmd=cmd,
        files={
            GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid,
            VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
            PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: prysm_password_artifact_uuid,
        },
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=v_min_cpu,
        max_cpu=v_max_cpu,
        min_memory=v_min_mem,
        max_memory=v_max_mem,
    )


def new_prysm_launcher(
    genesis_data, prysm_password_relative_filepath, prysm_password_artifact_uuid
):
    return struct(
        genesis_data=genesis_data,
        prysm_password_artifact_uuid=prysm_password_artifact_uuid,
        prysm_password_relative_filepath=prysm_password_relative_filepath,
    )
