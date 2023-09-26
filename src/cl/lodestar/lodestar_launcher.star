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

GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/genesis"
#  ---------------------------------- Beacon client -------------------------------------
CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/consensus-data"
# Port IDs
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
HTTP_PORT_ID = "http"
METRICS_PORT_ID = "metrics"
VALIDATOR_METRICS_PORT_ID = "validator-metrics"

# Port nums
DISCOVERY_PORT_NUM = 9000
HTTP_PORT_NUM = 4000
METRICS_PORT_NUM = 8008

# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 50
BEACON_MAX_CPU = 1000
BEACON_MIN_MEMORY = 256
BEACON_MAX_MEMORY = 1024

#  ---------------------------------- Validator client -------------------------------------
VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/validator-keys"
# The min/max CPU/memory that the validator node can use
VALIDATOR_MIN_CPU = 50
VALIDATOR_MAX_CPU = 300
VALIDATOR_MIN_MEMORY = 128
VALIDATOR_MAX_MEMORY = 512

VALIDATOR_SUFFIX_SERVICE_NAME = "validator"

METRICS_PATH = "/metrics"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

BEACON_USED_PORTS = {
    TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL
    ),
    HTTP_PORT_ID: shared_utils.new_port_spec(HTTP_PORT_NUM, shared_utils.TCP_PROTOCOL),
    METRICS_PORT_ID: shared_utils.new_port_spec(
        METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}

VALIDATOR_USED_PORTS = {
    METRICS_PORT_ID: shared_utils.new_port_spec(
        METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}


LODESTAR_LOG_LEVELS = {
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
    image,
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
    beacon_node_service_name = "{0}".format(service_name)
    validator_node_service_name = "{0}-{1}".format(
        service_name, VALIDATOR_SUFFIX_SERVICE_NAME
    )
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, LODESTAR_LOG_LEVELS
    )

    bn_min_cpu = int(bn_min_cpu) if int(bn_min_cpu) > 0 else BEACON_MIN_CPU
    bn_max_cpu = int(bn_max_cpu) if int(bn_max_cpu) > 0 else BEACON_MAX_CPU
    bn_min_mem = int(bn_min_mem) if int(bn_min_mem) > 0 else BEACON_MIN_MEMORY
    bn_max_mem = int(bn_max_mem) if int(bn_max_mem) > 0 else BEACON_MAX_MEMORY

    # Launch Beacon node
    beacon_config = get_beacon_config(
        launcher.cl_genesis_data,
        image,
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

    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )

    # Launch validator node if we have a keystore
    if node_keystore_files != None:
        v_min_cpu = int(v_min_cpu) if int(v_min_cpu) > 0 else VALIDATOR_MIN_CPU
        v_max_cpu = int(v_max_cpu) if int(v_max_cpu) > 0 else VALIDATOR_MAX_CPU
        v_min_mem = int(v_min_mem) if int(v_min_mem) > 0 else VALIDATOR_MIN_MEMORY
        v_max_mem = int(v_max_mem) if int(v_max_mem) > 0 else VALIDATOR_MAX_MEMORY
        validator_config = get_validator_config(
            validator_node_service_name,
            launcher.cl_genesis_data,
            image,
            log_level,
            beacon_http_url,
            node_keystore_files,
            v_min_cpu,
            v_max_cpu,
            v_min_mem,
            v_max_mem,
            extra_validator_params,
        )

        plan.add_service(validator_node_service_name, validator_config)

    # TODO(old) add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module

    beacon_node_identity_recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=HTTP_PORT_ID,
        extract={
            "enr": ".data.enr",
            "multiaddr": ".data.p2p_addresses[-1]",
            "peer_id": ".data.peer_id",
        },
    )
    response = plan.request(
        recipe=beacon_node_identity_recipe, service_name=beacon_node_service_name
    )
    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    beacon_metrics_port = beacon_service.ports[METRICS_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(
        beacon_service.ip_address, beacon_metrics_port.number
    )

    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    return cl_client_context.new_cl_client_context(
        "lodestar",
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
    image,
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
    el_client_rpc_url_str = "http://{0}:{1}".format(
        el_client_context.ip_addr,
        el_client_context.rpc_port_num,
    )

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
        "--execution.urls=" + EXECUTION_ENGINE_ENDPOINT,
        "--rest=true",
        "--rest.address=0.0.0.0",
        "--rest.namespace=*",
        "--rest.port={0}".format(HTTP_PORT_NUM),
        "--nat=true",
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

    if bootnode_contexts != None:
        cmd.append(
            "--bootnodes="
            + ",".join(
                [ctx.enr for ctx in bootnode_contexts[: package_io.MAX_ENR_ENTRIES]]
            )
        )

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    return ServiceConfig(
        image=image,
        ports=BEACON_USED_PORTS,
        cmd=cmd,
        files={
            GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid
        },
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ready_conditions=cl_node_ready_conditions.get_ready_conditions(HTTP_PORT_ID),
        min_cpu=bn_min_cpu,
        max_cpu=bn_max_cpu,
        min_memory=bn_min_mem,
        max_memory=bn_max_mem,
    )


def get_validator_config(
    service_name,
    genesis_data,
    image,
    log_level,
    beacon_client_http_url,
    node_keystore_files,
    v_min_cpu,
    v_max_cpu,
    v_min_mem,
    v_max_mem,
    extra_params,
):
    root_dirpath = shared_utils.path_join(
        CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER, service_name
    )

    genesis_config_filepath = shared_utils.path_join(
        GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        genesis_data.config_yml_rel_filepath,
    )

    validator_keys_dirpath = shared_utils.path_join(
        VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.raw_keys_relative_dirpath,
    )
    validator_secrets_dirpath = shared_utils.path_join(
        VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.raw_secrets_relative_dirpath,
    )

    cmd = [
        "validator",
        "--logLevel=" + log_level,
        "--dataDir=" + root_dirpath,
        "--paramsFile=" + genesis_config_filepath,
        "--beaconNodes=" + beacon_client_http_url,
        "--keystoresDir=" + validator_keys_dirpath,
        "--secretsDir=" + validator_secrets_dirpath,
        "--suggestedFeeRecipient=" + package_io.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics.address=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    return ServiceConfig(
        image=image,
        ports=VALIDATOR_USED_PORTS,
        cmd=cmd,
        files={
            GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid,
            VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
        },
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=v_min_cpu,
        max_cpu=v_max_cpu,
        min_memory=v_min_mem,
        max_memory=v_max_mem,
    )


def new_lodestar_launcher(cl_genesis_data):
    return struct(
        cl_genesis_data=cl_genesis_data,
    )
