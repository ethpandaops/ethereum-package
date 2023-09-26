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

TEKU_BINARY_FILEPATH_IN_IMAGE = "/opt/teku/bin/teku"

GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/genesis"

# The Docker container runs as the "teku" user so we can't write to root
CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/opt/teku/consensus-data"

# These will get mounted as root and Teku needs directory write permissions, so we'll copy this
#  into the Teku user's home directory to get around it
VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER = "/validator-keys"

# Port IDs
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
HTTP_PORT_ID = "http"
METRICS_PORT_ID = "metrics"

# Port nums
DISCOVERY_PORT_NUM = 9000
HTTP_PORT_NUM = 4000
METRICS_PORT_NUM = 8008

# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 50
BEACON_MAX_CPU = 1000
BEACON_MIN_MEMORY = 512
BEACON_MAX_MEMORY = 1024

# 1) The Teku container runs as the "teku" user
# 2) Teku requires write access to the validator secrets directory, so it can write a lockfile into it as it uses the keys
# 3) The module container runs as 'root'
# With these three things combined, it means that when the module container tries to write the validator keys/secrets into
#  the shared directory, it does so as 'root'. When Teku tries to consum the same files, it will get a failure because it
#  doesn't have permission to write to the 'validator-secrets' directory.
# To get around this, we copy the files AGAIN from
DEST_VALIDATOR_KEYS_DIRPATH_IN_SERVICE_CONTAINER = "$HOME/validator-keys"
DEST_VALIDATOR_SECRETS_DIRPATH_IN_SERVICE_CONTAINER = "$HOME/validator-secrets"

MIN_PEERS = 1

METRICS_PATH = "/metrics"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
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

ENTRYPOINT_ARGS = ["sh", "-c"]


TEKU_LOG_LEVELS = {
    package_io.GLOBAL_CLIENT_LOG_LEVEL.error: "ERROR",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.warn: "WARN",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.info: "INFO",
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
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, TEKU_LOG_LEVELS
    )

    extra_params = [param for param in extra_beacon_params] + [
        param for param in extra_validator_params
    ]

    bn_min_cpu = int(bn_min_cpu) if int(bn_min_cpu) > 0 else BEACON_MIN_CPU
    bn_max_cpu = int(bn_max_cpu) if int(bn_max_cpu) > 0 else BEACON_MAX_CPU
    bn_min_mem = int(bn_min_mem) if int(bn_min_mem) > 0 else BEACON_MIN_MEMORY
    bn_max_mem = int(bn_max_mem) if int(bn_max_mem) > 0 else BEACON_MAX_MEMORY

    # Set the min/max CPU/memory for the beacon node to be the max of the beacon node and validator node values, unless this is defined, it will use the default beacon values
    bn_min_cpu = int(v_min_cpu) if (int(v_min_cpu) > bn_min_cpu) else bn_min_cpu
    bn_max_cpu = int(v_max_cpu) if (int(v_max_cpu) > bn_max_cpu) else bn_max_cpu
    bn_min_mem = int(v_min_mem) if (int(v_min_mem) > bn_min_mem) else bn_min_mem
    bn_max_mem = int(v_max_mem) if (int(v_max_mem) > bn_max_mem) else bn_max_mem

    config = get_config(
        launcher.cl_genesis_data,
        image,
        bootnode_context,
        el_client_context,
        log_level,
        node_keystore_files,
        bn_min_cpu,
        bn_max_cpu,
        bn_min_mem,
        bn_max_mem,
        snooper_enabled,
        snooper_engine_context,
        extra_params,
    )

    teku_service = plan.add_service(service_name, config)

    node_identity_recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=HTTP_PORT_ID,
        extract={
            "enr": ".data.enr",
            "multiaddr": ".data.discovery_addresses[0]",
            "peer_id": ".data.peer_id",
        },
    )
    response = plan.request(recipe=node_identity_recipe, service_name=service_name)
    node_enr = response["extract.enr"]
    multiaddr = response["extract.multiaddr"]
    peer_id = response["extract.peer_id"]

    teku_metrics_port = teku_service.ports[METRICS_PORT_ID]
    teku_metrics_url = "{0}:{1}".format(
        teku_service.ip_address, teku_metrics_port.number
    )

    teku_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, teku_metrics_url
    )
    nodes_metrics_info = [teku_node_metrics_info]

    return cl_client_context.new_cl_client_context(
        "teku",
        node_enr,
        teku_service.ip_address,
        HTTP_PORT_NUM,
        nodes_metrics_info,
        service_name,
        multiaddr=multiaddr,
        peer_id=peer_id,
        snooper_enabled=snooper_enabled,
        snooper_engine_context=snooper_engine_context,
    )


def get_config(
    genesis_data,
    image,
    bootnode_contexts,
    el_client_context,
    log_level,
    node_keystore_files,
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

    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files:
        validator_keys_dirpath = shared_utils.path_join(
            VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_secrets_relative_dirpath,
        )

    validator_copy = [
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
    ]
    validator_flags = [
        "--validator-keys={0}:{1}".format(
            DEST_VALIDATOR_KEYS_DIRPATH_IN_SERVICE_CONTAINER,
            DEST_VALIDATOR_SECRETS_DIRPATH_IN_SERVICE_CONTAINER,
        ),
        "--validators-proposer-default-fee-recipient="
        + package_io.VALIDATING_REWARDS_ACCOUNT,
    ]
    beacon_start = [
        TEKU_BINARY_FILEPATH_IN_IMAGE,
        "--logging=" + log_level,
        "--log-destination=CONSOLE",
        "--network=" + genesis_config_filepath,
        "--initial-state=" + genesis_ssz_filepath,
        "--data-path=" + CONSENSUS_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--data-storage-mode={0}".format(
            "ARCHIVE" if package_io.ARCHIVE_MODE else "PRUNE"
        ),
        "--p2p-enabled=true",
        # Set per Pari's recommendation, to reduce noise in the logs
        "--p2p-subscribe-all-subnets-enabled=true",
        "--p2p-peer-lower-bound={0}".format(MIN_PEERS),
        "--p2p-advertised-ip=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--p2p-discovery-site-local-addresses-enabled",
        "--rest-api-enabled=true",
        "--rest-api-docs-enabled=true",
        "--rest-api-interface=0.0.0.0",
        "--rest-api-port={0}".format(HTTP_PORT_NUM),
        "--rest-api-host-allowlist=*",
        "--data-storage-non-canonical-blocks-enabled=true",
        "--ee-jwt-secret-file={0}".format(jwt_secret_filepath),
        "--ee-endpoint=" + EXECUTION_ENGINE_ENDPOINT,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics-enabled",
        "--metrics-interface=0.0.0.0",
        "--metrics-host-allowlist='*'",
        "--metrics-categories=BEACON,PROCESS,LIBP2P,JVM,NETWORK,PROCESS",
        "--metrics-port={0}".format(METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    # Depending on whether we're using a node keystore, we'll need to add the validator flags
    cmd = []
    if node_keystore_files != None:
        cmd.extend(validator_copy)
        cmd.extend(beacon_start)
        cmd.extend(validator_flags)
    else:
        cmd.extend(beacon_start)

    if bootnode_contexts != None:
        cmd.append(
            "--p2p-discovery-bootnodes="
            + ",".join(
                [ctx.enr for ctx in bootnode_contexts[: package_io.MAX_ENR_ENTRIES]]
            )
        )
        cmd.append(
            "--p2p-static-peers="
            + ",".join(
                [
                    ctx.multiaddr
                    for ctx in bootnode_contexts[: package_io.MAX_ENR_ENTRIES]
                ]
            )
        )

    if len(extra_params) > 0:
        # we do the list comprehension as the default extra_params is a proto repeated string
        cmd.extend([param for param in extra_params])

    files = {
        GENESIS_DATA_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: genesis_data.files_artifact_uuid,
    }
    if node_keystore_files:
        files[
            VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER
        ] = node_keystore_files.files_artifact_uuid
    cmd_str = " ".join(cmd)
    return ServiceConfig(
        image=image,
        ports=USED_PORTS,
        cmd=[cmd_str],
        entrypoint=ENTRYPOINT_ARGS,
        files=files,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ready_conditions=cl_node_ready_conditions.get_ready_conditions(HTTP_PORT_ID),
        min_cpu=bn_min_cpu,
        max_cpu=bn_max_cpu,
        min_memory=bn_min_mem,
        max_memory=bn_max_mem,
    )


def new_teku_launcher(cl_genesis_data):
    return struct(cl_genesis_data=cl_genesis_data)
