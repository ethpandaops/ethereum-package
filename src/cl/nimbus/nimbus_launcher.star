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

GENESIS_DATA_MOUNTPOINT_ON_CLIENT = "/genesis-data"

VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENT = "/validator-keys"

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
BEACON_MIN_MEMORY = 128
BEACON_MAX_MEMORY = 1024


# Nimbus requires that its data directory already exists (because it expects you to bind-mount it), so we
#  have to to create it
CONSENSUS_DATA_DIRPATH_IN_SERVICE_CONTAINER = "$HOME/consensus-data"
# Nimbus wants the data dir to have these perms
CONSENSUS_DATA_DIR_PERMS_STR = "0700"

# The entrypoint the image normally starts with (we need to override the entrypoint to create the
#  consensus data directory on the image before it starts)
DEFAULT_IMAGE_ENTRYPOINT = "/home/user/nimbus-eth2/build/nimbus_beacon_node"

# Nimbus needs write access to the validator keys/secrets directories, and b/c the module container runs as root
#  while the Nimbus container does not, we can't just point the Nimbus binary to the paths in the shared dir because
#  it won't be able to open them. To get around this, we copy the validator keys/secrets to a path inside the Nimbus
#  container that is owned by the container's user
VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER = "$HOME/validator-keys"
VALIDATOR_SECRETS_DIRPATH_ON_SERVICE_CONTAINER = "$HOME/validator-secrets"

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

NIMBUS_LOG_LEVELS = {
    package_io.GLOBAL_CLIENT_LOG_LEVEL.error: "ERROR",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.warn: "WARN",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.info: "INFO",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.debug: "DEBUG",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.trace: "TRACE",
}

ENTRYPOINT_ARGS = ["sh", "-c"]


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
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, NIMBUS_LOG_LEVELS
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
    )

    nimbus_service = plan.add_service(service_name, config)

    cl_node_identity_recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=HTTP_PORT_ID,
        extract={
            "enr": ".data.enr",
            "multiaddr": ".data.discovery_addresses[0]",
            "peer_id": ".data.peer_id",
        },
    )
    response = plan.request(recipe=cl_node_identity_recipe, service_name=service_name)
    node_enr = response["extract.enr"]
    multiaddr = response["extract.multiaddr"]
    peer_id = response["extract.peer_id"]

    metrics_port = nimbus_service.ports[METRICS_PORT_ID]
    metrics_url = "{0}:{1}".format(nimbus_service.ip_address, metrics_port.number)

    nimbus_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )
    nodes_metrics_info = [nimbus_node_metrics_info]

    return cl_client_context.new_cl_client_context(
        "nimbus",
        node_enr,
        nimbus_service.ip_address,
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

    # For some reason, Nimbus takes in the parent directory of the config file (rather than the path to the config file itself)
    genesis_config_parent_dirpath_on_client = shared_utils.path_join(
        GENESIS_DATA_MOUNTPOINT_ON_CLIENT,
        shared_utils.path_dir(genesis_data.config_yml_rel_filepath),
    )
    jwt_secret_filepath = shared_utils.path_join(
        GENESIS_DATA_MOUNTPOINT_ON_CLIENT, genesis_data.jwt_secret_rel_filepath
    )

    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENT,
            node_keystore_files.nimbus_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENT,
            node_keystore_files.raw_secrets_relative_dirpath,
        )

    # Sources for these flags:
    #  1) https://github.com/status-im/nimbus-eth2/blob/stable/scripts/launch_local_testnet.sh
    #  2) https://github.com/status-im/nimbus-eth2/blob/67ab477a27e358d605e99bffeb67f98d18218eca/scripts/launch_local_testnet.sh#L417
    # WARNING: Do NOT set the --max-peers flag here, as doing so to the exact number of nodes seems to mess things up!
    # See: https://github.com/kurtosis-tech/eth2-merge-kurtosis-module/issues/26
    validator_copy = [
        "mkdir",
        CONSENSUS_DATA_DIRPATH_IN_SERVICE_CONTAINER,
        "-m",
        CONSENSUS_DATA_DIR_PERMS_STR,
        "&&",
        # TODO(old) COMMENT THIS OUT?
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
    ]

    validator_flags = [
        "--validators-dir=" + VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        "--secrets-dir=" + VALIDATOR_SECRETS_DIRPATH_ON_SERVICE_CONTAINER,
        "--suggested-fee-recipient=" + package_io.VALIDATING_REWARDS_ACCOUNT,
    ]

    beacon_start = [
        DEFAULT_IMAGE_ENTRYPOINT,
        "--non-interactive=true",
        "--log-level=" + log_level,
        "--udp-port={0}".format(DISCOVERY_PORT_NUM),
        "--tcp-port={0}".format(DISCOVERY_PORT_NUM),
        "--network=" + genesis_config_parent_dirpath_on_client,
        "--data-dir=" + CONSENSUS_DATA_DIRPATH_IN_SERVICE_CONTAINER,
        "--web3-url=" + EXECUTION_ENGINE_ENDPOINT,
        "--nat=extip:" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--enr-auto-update=false",
        "--history={0}".format("archive" if package_io.ARCHIVE_MODE else "prune"),
        "--rest",
        "--rest-address=0.0.0.0",
        "--rest-allow-origin=*",
        "--rest-port={0}".format(HTTP_PORT_NUM),
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

    # Depending on whether we're using a node keystore, we'll need to add the validator flags
    cmd = []
    if node_keystore_files != None:
        cmd.extend(validator_copy)
        cmd.extend(beacon_start)
        cmd.extend(validator_flags)
    else:
        cmd.extend(beacon_start)

    if bootnode_contexts == None:
        # Copied from https://github.com/status-im/nimbus-eth2/blob/67ab477a27e358d605e99bffeb67f98d18218eca/scripts/launch_local_testnet.sh#L417
        # See explanation there
        cmd.append("--subscribe-all-subnets")
    else:
        for ctx in bootnode_contexts[: package_io.MAX_ENR_ENTRIES]:
            cmd.append("--bootstrap-node=" + ctx.enr)
            cmd.append("--direct-peer=" + ctx.multiaddr)

    if len(extra_params) > 0:
        cmd.extend([param for param in extra_params])

    files = {
        GENESIS_DATA_MOUNTPOINT_ON_CLIENT: genesis_data.files_artifact_uuid,
    }
    if node_keystore_files:
        files[
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENT
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


def new_nimbus_launcher(cl_genesis_data):
    return struct(
        cl_genesis_data=cl_genesis_data,
    )
