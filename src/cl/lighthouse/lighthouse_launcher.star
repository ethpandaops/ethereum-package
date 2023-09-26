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

package_io = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/constants.star"
)

LIGHTHOUSE_BINARY_COMMAND = "lighthouse"

GENESIS_DATA_MOUNTPOINT_ON_CLIENTS = "/genesis"

VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS = "/validator-keys"

RUST_BACKTRACE_ENVVAR_NAME = "RUST_BACKTRACE"
RUST_FULL_BACKTRACE_KEYWORD = "full"

#  ---------------------------------- Beacon client -------------------------------------
CONSENSUS_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER = "/consensus-data"

# Port IDs
BEACON_TCP_DISCOVERY_PORT_ID = "tcp-discovery"
BEACON_UDP_DISCOVERY_PORT_ID = "udp-discovery"
BEACON_HTTP_PORT_ID = "http"
BEACON_METRICS_PORT_ID = "metrics"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_HTTP_PORT_NUM = 4000
BEACON_METRICS_PORT_NUM = 5054

# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 50
BEACON_MAX_CPU = 1000
BEACON_MIN_MEMORY = 256
BEACON_MAX_MEMORY = 1024

#  ---------------------------------- Validator client -------------------------------------
VALIDATOR_HTTP_PORT_ID = "http"
VALIDATOR_METRICS_PORT_ID = "metrics"
VALIDATOR_HTTP_PORT_NUM = 5042
VALIDATOR_METRICS_PORT_NUM = 5064
VALIDATOR_HTTP_PORT_WAIT_DISABLED = None

METRICS_PATH = "/metrics"
VALIDATOR_SUFFIX_SERVICE_NAME = "validator"

# The min/max CPU/memory that the validator node can use
VALIDATOR_MIN_CPU = 50
VALIDATOR_MAX_CPU = 300
VALIDATOR_MIN_MEMORY = 128
VALIDATOR_MAX_MEMORY = 512

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

BEACON_USED_PORTS = {
    BEACON_TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        BEACON_DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    BEACON_UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        BEACON_DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL
    ),
    BEACON_HTTP_PORT_ID: shared_utils.new_port_spec(
        BEACON_HTTP_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    BEACON_METRICS_PORT_ID: shared_utils.new_port_spec(
        BEACON_METRICS_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

VALIDATOR_USED_PORTS = {
    VALIDATOR_HTTP_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_HTTP_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.NOT_PROVIDED_APPLICATION_PROTOCOL,
        VALIDATOR_HTTP_PORT_WAIT_DISABLED,
    ),
    VALIDATOR_METRICS_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_METRICS_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

LIGHTHOUSE_LOG_LEVELS = {
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
        participant_log_level, global_log_level, LIGHTHOUSE_LOG_LEVELS
    )

    bn_min_cpu = int(bn_min_cpu) if int(bn_min_cpu) > 0 else BEACON_MIN_CPU
    bn_max_cpu = int(bn_max_cpu) if int(bn_max_cpu) > 0 else BEACON_MAX_CPU
    bn_min_mem = int(bn_min_mem) if int(bn_min_mem) > 0 else BEACON_MIN_MEMORY
    bn_max_mem = int(bn_max_mem) if int(bn_max_mem) > 0 else BEACON_MAX_MEMORY

    # Launch Beacon node
    beacon_config = get_beacon_config(
        launcher.genesis_data,
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
    beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )

    # Launch validator node if we have a keystore
    validator_service = None
    if node_keystore_files != None:
        v_min_cpu = int(v_min_cpu) if int(v_min_cpu) > 0 else VALIDATOR_MIN_CPU
        v_max_cpu = int(v_max_cpu) if int(v_max_cpu) > 0 else VALIDATOR_MAX_CPU
        v_min_mem = int(v_min_mem) if int(v_min_mem) > 0 else VALIDATOR_MIN_MEMORY
        v_max_mem = int(v_max_mem) if int(v_max_mem) > 0 else VALIDATOR_MAX_MEMORY

        validator_config = get_validator_config(
            launcher.genesis_data,
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

        validator_service = plan.add_service(
            validator_node_service_name, validator_config
        )

    # TODO(old) add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module
    beacon_node_identity_recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=BEACON_HTTP_PORT_ID,
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

    beacon_metrics_port = beacon_service.ports[BEACON_METRICS_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(
        beacon_service.ip_address, beacon_metrics_port.number
    )
    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        beacon_node_service_name, METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    if validator_service:
        validator_metrics_port = validator_service.ports[VALIDATOR_METRICS_PORT_ID]
        validator_metrics_url = "{0}:{1}".format(
            validator_service.ip_address, validator_metrics_port.number
        )
        validator_node_metrics_info = node_metrics.new_node_metrics_info(
            validator_node_service_name, METRICS_PATH, validator_metrics_url
        )
        nodes_metrics_info.append(validator_node_metrics_info)

    return cl_client_context.new_cl_client_context(
        "lighthouse",
        beacon_node_enr,
        beacon_service.ip_address,
        BEACON_HTTP_PORT_NUM,
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
    boot_cl_client_ctxs,
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

    # For some reason, Lighthouse takes in the parent directory of the config file (rather than the path to the config file itself)
    genesis_config_parent_dirpath_on_client = shared_utils.path_join(
        GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
        shared_utils.path_dir(genesis_data.config_yml_rel_filepath),
    )
    jwt_secret_filepath = shared_utils.path_join(
        GENESIS_DATA_MOUNTPOINT_ON_CLIENTS, genesis_data.jwt_secret_rel_filepath
    )

    # NOTE: If connecting to the merge devnet remotely we DON'T want the following flags; when they're not set, the node's external IP address is auto-detected
    #  from the peers it communicates with but when they're set they basically say "override the autodetection and
    #  use what I specify instead." This requires having a know external IP address and port, which we definitely won't
    #  have with a network running in Kurtosis.
    # 	"--disable-enr-auto-update",
    # 	"--enr-address=" + externalIpAddress,
    # 	fmt.Sprintf("--enr-udp-port=%v", BEACON_DISCOVERY_PORT_NUM),
    # 	fmt.Sprintf("--enr-tcp-port=%v", beaconDiscoveryPortNum),
    cmd = [
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
        "--port={0}".format(
            BEACON_DISCOVERY_PORT_NUM
        ),  # NOTE: Remove for connecting to external net!
        "--http",
        "--http-address=0.0.0.0",
        "--http-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--http-allow-sync-stalled",
        "--slots-per-restore-point={0}".format(32 if package_io.ARCHIVE_MODE else 8192),
        # NOTE: This comes from:
        #   https://github.com/sigp/lighthouse/blob/7c88f582d955537f7ffff9b2c879dcf5bf80ce13/scripts/local_testnet/beacon_node.sh
        # and the option says it's "useful for testing in smaller networks" (unclear what happens in larger networks)
        "--disable-packet-filter",
        "--execution-endpoints=" + EXECUTION_ENGINE_ENDPOINT,
        "--jwt-secrets=" + jwt_secret_filepath,
        "--suggested-fee-recipient=" + package_io.VALIDATING_REWARDS_ACCOUNT,
        # Set per Paris' recommendation to reduce noise in the logs
        "--subscribe-all-subnets",
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-allow-origin=*",
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    if boot_cl_client_ctxs != None:
        cmd.append(
            "--boot-nodes="
            + ",".join(
                [ctx.enr for ctx in boot_cl_client_ctxs[: package_io.MAX_ENR_ENTRIES]]
            )
        )
        cmd.append(
            "--trusted-peers="
            + ",".join(
                [
                    ctx.peer_id
                    for ctx in boot_cl_client_ctxs[: package_io.MAX_ENR_ENTRIES]
                ]
            )
        )

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity", port_id=BEACON_HTTP_PORT_ID
    )

    ready_conditions = ReadyCondition(
        recipe=recipe,
        field="code",
        assertion="IN",
        target_value=[200, 206],
        timeout="15m",
    )

    return ServiceConfig(
        image=image,
        ports=BEACON_USED_PORTS,
        cmd=cmd,
        files={GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: genesis_data.files_artifact_uuid},
        env_vars={RUST_BACKTRACE_ENVVAR_NAME: RUST_FULL_BACKTRACE_KEYWORD},
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ready_conditions=ready_conditions,
        min_cpu=bn_min_cpu,
        max_cpu=bn_max_cpu,
        min_memory=bn_min_mem,
        max_memory=bn_max_mem,
    )


def get_validator_config(
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
    # For some reason, Lighthouse takes in the parent directory of the config file (rather than the path to the config file itself)
    genesis_config_parent_dirpath_on_client = shared_utils.path_join(
        GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
        shared_utils.path_dir(genesis_data.config_yml_rel_filepath),
    )

    validator_keys_dirpath = shared_utils.path_join(
        VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS,
        node_keystore_files.raw_keys_relative_dirpath,
    )
    validator_secrets_dirpath = shared_utils.path_join(
        VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS,
        node_keystore_files.raw_secrets_relative_dirpath,
    )

    cmd = [
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
        # "--enable-doppelganger-protection", // Disabled to not have to wait 2 epochs before validator can start
        # burn address - If unset, the validator will scream in its logs
        "--suggested-fee-recipient=" + package_io.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-allow-origin=*",
        "--metrics-port={0}".format(VALIDATOR_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    if len(extra_params):
        cmd.extend([param for param in extra_params])

    return ServiceConfig(
        image=image,
        ports=VALIDATOR_USED_PORTS,
        cmd=cmd,
        files={
            GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: genesis_data.files_artifact_uuid,
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS: node_keystore_files.files_artifact_uuid,
        },
        env_vars={RUST_BACKTRACE_ENVVAR_NAME: RUST_FULL_BACKTRACE_KEYWORD},
        min_cpu=v_min_cpu,
        max_cpu=v_max_cpu,
        min_memory=v_min_mem,
        max_memory=v_max_mem,
    )


def new_lighthouse_launcher(cl_genesis_data):
    return struct(
        genesis_data=cl_genesis_data,
    )
