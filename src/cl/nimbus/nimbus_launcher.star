#  ---------------------------------- Library Imports ----------------------------------
shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")
vc_shared = import_module("../../vc/shared.star")
#  ---------------------------------- Beacon client -------------------------------------
# Nimbus requires that its data directory already exists (because it expects you to bind-mount it), so we
#  have to to create it
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/nimbus/beacon-data"
# Port IDs
BEACON_TCP_DISCOVERY_PORT_ID = "tcp-discovery"
BEACON_UDP_DISCOVERY_PORT_ID = "udp-discovery"
BEACON_HTTP_PORT_ID = "http"
BEACON_METRICS_PORT_ID = "metrics"
VALIDATOR_HTTP_PORT_ID = "http-validator"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_HTTP_PORT_NUM = 4000
BEACON_METRICS_PORT_NUM = 8008

# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 50
BEACON_MIN_MEMORY = 256

DEFAULT_BEACON_IMAGE_ENTRYPOINT = ["nimbus_beacon_node"]

BEACON_METRICS_PATH = "/metrics"

VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS = "/data/nimbus/validator-keys"
# ---------------------------------- Genesis Files ----------------------------------

# Nimbus needs write access to the validator keys/secrets directories, and b/c the module container runs as root
#  while the Nimbus container does not, we can't just point the Nimbus binary to the paths in the shared dir because
#  it won't be able to open them. To get around this, we copy the validator keys/secrets to a path inside the Nimbus
#  container that is owned by the container's user

# ---------------------------------- Metrics ----------------------------------


# ---------------------------------- Used Ports ----------------------------------
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

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
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
    el_context,
    node_keystore_files,
    cl_min_cpu,
    cl_max_cpu,
    cl_min_mem,
    cl_max_mem,
    snooper_enabled,
    snooper_engine_context,
    blobber_enabled,
    blobber_extra_params,
    extra_params,
    extra_env_vars,
    extra_labels,
    persistent,
    cl_volume_size,
    cl_tolerations,
    participant_tolerations,
    global_tolerations,
    node_selectors,
    use_separate_vc,
):
    beacon_service_name = "{0}".format(service_name)

    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )

    tolerations = input_parser.get_client_tolerations(
        cl_tolerations, participant_tolerations, global_tolerations
    )

    network_name = shared_utils.get_network_name(launcher.network)

    cl_min_cpu = int(cl_min_cpu) if int(cl_min_cpu) > 0 else BEACON_MIN_CPU
    cl_max_cpu = (
        int(cl_max_cpu)
        if int(cl_max_cpu) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["nimbus_max_cpu"]
    )
    cl_min_mem = int(cl_min_mem) if int(cl_min_mem) > 0 else BEACON_MIN_MEMORY
    cl_max_mem = (
        int(cl_max_mem)
        if int(cl_max_mem) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["nimbus_max_mem"]
    )

    cl_volume_size = (
        int(cl_volume_size)
        if int(cl_volume_size) > 0
        else constants.VOLUME_SIZE[network_name]["nimbus_volume_size"]
    )

    beacon_config = get_beacon_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        launcher.keymanager_file,
        launcher.network,
        image,
        beacon_service_name,
        bootnode_contexts,
        el_context,
        log_level,
        node_keystore_files,
        cl_min_cpu,
        cl_max_cpu,
        cl_min_mem,
        cl_max_mem,
        snooper_enabled,
        snooper_engine_context,
        extra_params,
        extra_env_vars,
        extra_labels,
        use_separate_vc,
        persistent,
        cl_volume_size,
        tolerations,
        node_selectors,
    )

    beacon_service = plan.add_service(beacon_service_name, beacon_config)
    beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]
    beacon_metrics_port = beacon_service.ports[BEACON_METRICS_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )
    beacon_metrics_url = "{0}:{1}".format(
        beacon_service.ip_address, beacon_metrics_port.number
    )

    beacon_node_identity_recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=BEACON_HTTP_PORT_ID,
        extract={
            "enr": ".data.enr",
            "multiaddr": ".data.p2p_addresses[0]",
            "peer_id": ".data.peer_id",
        },
    )
    response = plan.request(
        recipe=beacon_node_identity_recipe, service_name=service_name
    )
    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    nimbus_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, BEACON_METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [nimbus_node_metrics_info]

    return cl_context.new_cl_context(
        "nimbus",
        beacon_node_enr,
        beacon_service.ip_address,
        BEACON_HTTP_PORT_NUM,
        nodes_metrics_info,
        beacon_service_name,
        beacon_multiaddr,
        beacon_peer_id,
        snooper_enabled,
        snooper_engine_context,
        validator_keystore_files_artifact_uuid=node_keystore_files.files_artifact_uuid
        if node_keystore_files
        else "",
    )


def get_beacon_config(
    plan,
    el_cl_genesis_data,
    jwt_file,
    keymanager_file,
    network,
    image,
    service_name,
    bootnode_contexts,
    el_context,
    log_level,
    node_keystore_files,
    cl_min_cpu,
    cl_max_cpu,
    cl_min_mem,
    cl_max_mem,
    snooper_enabled,
    snooper_engine_context,
    extra_params,
    extra_env_vars,
    extra_labels,
    use_separate_vc,
    persistent,
    cl_volume_size,
    tolerations,
    node_selectors,
):
    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS,
            node_keystore_files.nimbus_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS,
            node_keystore_files.raw_secrets_relative_dirpath,
        )
    # If snooper is enabled use the snooper engine context, otherwise use the execution client context
    if snooper_enabled:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            snooper_engine_context.ip_addr,
            snooper_engine_context.engine_rpc_port_num,
        )
    else:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            el_context.ip_addr,
            el_context.engine_rpc_port_num,
        )

    cmd = [
        "--non-interactive=true",
        "--log-level=" + log_level,
        "--udp-port={0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--tcp-port={0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--network={0}".format(
            network
            if network in constants.PUBLIC_NETWORKS
            else constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        ),
        "--data-dir=" + BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--web3-url=" + EXECUTION_ENGINE_ENDPOINT,
        "--nat=extip:" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--enr-auto-update=false",
        "--history={0}".format("archive" if constants.ARCHIVE_MODE else "prune"),
        "--rest",
        "--rest-address=0.0.0.0",
        "--rest-allow-origin=*",
        "--rest-port={0}".format(BEACON_HTTP_PORT_NUM),
        # There's a bug where if we don't set this flag, the Nimbus nodes won't work:
        # https://discord.com/channels/641364059387854899/674288681737256970/922890280120750170
        # https://github.com/status-im/nimbus-eth2/issues/2451
        "--doppelganger-detection=false",
        # Set per Pari's recommendation to reduce noise in the logs
        "--subscribe-all-subnets=true",
        # Nimbus can handle a max of 256 threads, if the host has more then nimbus crashes. Setting it to 4 so it doesn't crash on build servers
        "--num-threads=4",
        "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    validator_flags = [
        "--validators-dir=" + validator_keys_dirpath,
        "--secrets-dir=" + validator_secrets_dirpath,
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        "--graffiti=" + constants.CL_TYPE.nimbus + "-" + el_context.client_name,
        "--keymanager",
        "--keymanager-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--keymanager-address=0.0.0.0",
        "--keymanager-allow-origin=*",
        "--keymanager-token-file=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
    ]

    if network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--bootstrap-file="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/bootstrap_nodes.txt"
        )
        if (
            network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network
        ):
            if bootnode_contexts == None:
                cmd.append("--subscribe-all-subnets")
            else:
                for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]:
                    cmd.append("--bootstrap-node=" + ctx.enr)
                    cmd.append("--direct-peer=" + ctx.multiaddr)

    if len(extra_params) > 0:
        cmd.extend([param for param in extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }
    beacon_validator_used_ports = {}
    beacon_validator_used_ports.update(BEACON_USED_PORTS)
    if node_keystore_files != None and not use_separate_vc:
        validator_http_port_id_spec = shared_utils.new_port_spec(
            vc_shared.VALIDATOR_HTTP_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        )
        beacon_validator_used_ports.update(
            {VALIDATOR_HTTP_PORT_ID: validator_http_port_id_spec}
        )
        cmd.extend(validator_flags)
        files[
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS
        ] = node_keystore_files.files_artifact_uuid
        files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = keymanager_file

    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=cl_volume_size,
        )

    return ServiceConfig(
        image=image,
        ports=beacon_validator_used_ports,
        cmd=cmd,
        env_vars=extra_env_vars,
        files=files,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ready_conditions=cl_node_ready_conditions.get_ready_conditions(
            BEACON_HTTP_PORT_ID
        ),
        min_cpu=cl_min_cpu,
        max_cpu=cl_max_cpu,
        min_memory=cl_min_mem,
        max_memory=cl_max_mem,
        labels=shared_utils.label_maker(
            constants.CL_TYPE.nimbus,
            constants.CLIENT_TYPES.cl,
            image,
            el_context.client_name,
            extra_labels,
        ),
        user=User(uid=0, gid=0),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )


def new_nimbus_launcher(el_cl_genesis_data, jwt_file, network, keymanager_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
        keymanager_file=keymanager_file,
    )
