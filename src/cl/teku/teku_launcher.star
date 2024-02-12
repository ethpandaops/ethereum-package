shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_client_context = import_module("../../cl/cl_client_context.star")
node_metrics = import_module("../../node_metrics_info.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
constants = import_module("../../package_io/constants.star")
TEKU_BINARY_FILEPATH_IN_IMAGE = "/opt/teku/bin/teku"

#  ---------------------------------- Beacon client -------------------------------------
# The Docker container runs as the "teku" user so we can't write to root
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/teku/teku-beacon-data"

# Port IDs
BEACON_TCP_DISCOVERY_PORT_ID = "tcp-discovery"
BEACON_UDP_DISCOVERY_PORT_ID = "udp-discovery"
BEACON_HTTP_PORT_ID = "http"
BEACON_METRICS_PORT_ID = "metrics"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_HTTP_PORT_NUM = 4000
BEACON_METRICS_PORT_NUM = 8008

# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 50
BEACON_MIN_MEMORY = 1024

BEACON_METRICS_PATH = "/metrics"

VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER = "/validator-keys"

MIN_PEERS = 1

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

BEACON_USED_PORTS = {
    BEACON_TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        BEACON_DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    BEACON_UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        BEACON_DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL
    ),
    BEACON_HTTP_PORT_ID: shared_utils.new_port_spec(
        BEACON_HTTP_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    BEACON_METRICS_PORT_ID: shared_utils.new_port_spec(
        BEACON_METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}


ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    constants.GLOBAL_CLIENT_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_CLIENT_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_CLIENT_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_CLIENT_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_CLIENT_LOG_LEVEL.trace: "TRACE",
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
    snooper_enabled,
    snooper_engine_context,
    blobber_enabled,
    blobber_extra_params,
    extra_beacon_params,
    extra_beacon_labels,
    persistent,
    cl_volume_size,
    cl_tolerations,
    participant_tolerations,
    global_tolerations,
    node_selectors,
    use_separate_validator_client,
):
    beacon_service_name = "{0}".format(service_name)
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )

    tolerations = input_parser.get_client_tolerations(
        cl_tolerations, participant_tolerations, global_tolerations
    )

    extra_params = [param for param in extra_beacon_params]

    network_name = shared_utils.get_network_name(launcher.network)

    bn_min_cpu = int(bn_min_cpu) if int(bn_min_cpu) > 0 else BEACON_MIN_CPU
    bn_max_cpu = (
        int(bn_max_cpu)
        if int(bn_max_cpu) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["teku_max_cpu"]
    )
    bn_min_mem = int(bn_min_mem) if int(bn_min_mem) > 0 else BEACON_MIN_MEMORY
    bn_max_mem = (
        int(bn_max_mem)
        if int(bn_max_mem) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["teku_max_mem"]
    )

    cl_volume_size = (
        int(cl_volume_size)
        if int(cl_volume_size) > 0
        else constants.VOLUME_SIZE[network_name]["teku_volume_size"]
    )

    config = get_beacon_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        launcher.network,
        image,
        beacon_service_name,
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
        extra_beacon_params,
        extra_beacon_labels,
        use_separate_validator_client,
        persistent,
        cl_volume_size,
        tolerations,
        node_selectors,
    )

    beacon_service = plan.add_service(service_name, config)

    beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )

    beacon_metrics_port = beacon_service.ports[BEACON_METRICS_PORT_ID]
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

    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, BEACON_METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    return cl_client_context.new_cl_client_context(
        "teku",
        beacon_node_enr,
        beacon_service.ip_address,
        BEACON_HTTP_PORT_NUM,
        nodes_metrics_info,
        beacon_service_name,
        multiaddr=beacon_multiaddr,
        peer_id=beacon_peer_id,
        snooper_enabled=snooper_enabled,
        snooper_engine_context=snooper_engine_context,
        validator_keystore_files_artifact_uuid=node_keystore_files.files_artifact_uuid
        if node_keystore_files
        else "",
    )


def get_beacon_config(
    plan,
    el_cl_genesis_data,
    jwt_file,
    network,
    image,
    service_name,
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
    extra_labels,
    use_separate_validator_client,
    persistent,
    cl_volume_size,
    tolerations,
    node_selectors,
):
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
    cmd = [
        "--logging=" + log_level,
        "--log-destination=CONSOLE",
        "--network={0}".format(
            network
            if network in constants.PUBLIC_NETWORKS
            else constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/config.yaml"
        ),
        "--data-path=" + BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--data-storage-mode={0}".format(
            "ARCHIVE" if constants.ARCHIVE_MODE else "PRUNE"
        ),
        "--p2p-enabled=true",
        # Set per Pari's recommendation, to reduce noise in the logs
        "--p2p-subscribe-all-subnets-enabled=true",
        "--p2p-peer-lower-bound={0}".format(MIN_PEERS),
        "--p2p-advertised-ip=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--p2p-discovery-site-local-addresses-enabled=true",
        "--rest-api-enabled=true",
        "--rest-api-docs-enabled=true",
        "--rest-api-interface=0.0.0.0",
        "--rest-api-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--rest-api-host-allowlist=*",
        "--data-storage-non-canonical-blocks-enabled=true",
        "--ee-jwt-secret-file=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--ee-endpoint=" + EXECUTION_ENGINE_ENDPOINT,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics-enabled",
        "--metrics-interface=0.0.0.0",
        "--metrics-host-allowlist='*'",
        "--metrics-categories=BEACON,PROCESS,LIBP2P,JVM,NETWORK,PROCESS",
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
        # To enable syncing other networks too without checkpoint syncing
        "--ignore-weak-subjectivity-period-enabled=true",
    ]
    validator_flags = [
        "--validator-keys={0}:{1}".format(
            validator_keys_dirpath,
            validator_secrets_dirpath,
        ),
        "--validators-proposer-default-fee-recipient="
        + constants.VALIDATING_REWARDS_ACCOUNT,
        "--validators-graffiti="
        + constants.CL_CLIENT_TYPE.teku
        + "-"
        + el_client_context.client_name,
    ]

    if node_keystore_files != None and not use_separate_validator_client:
        cmd.extend(validator_flags)

    if network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--initial-state="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis.ssz"
        )
        if (
            network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network
        ):
            if bootnode_contexts != None:
                cmd.append(
                    "--p2p-discovery-bootnodes="
                    + ",".join(
                        [
                            ctx.enr
                            for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]
                        ]
                    )
                )
                cmd.append(
                    "--p2p-static-peers="
                    + ",".join(
                        [
                            ctx.multiaddr
                            for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]
                        ]
                    )
                )
        elif network == constants.NETWORK_NAME.ephemery:
            cmd.append(
                "--checkpoint-sync-url=" + constants.CHECKPOINT_SYNC_URL[network]
            )
            cmd.append(
                "--p2p-discovery-bootnodes="
                + shared_utils.get_devnet_enrs_list(
                    plan, el_cl_genesis_data.files_artifact_uuid
                )
            )
        elif constants.NETWORK_NAME.shadowfork in network:
            cmd.append(
                "--p2p-discovery-bootnodes="
                + shared_utils.get_devnet_enrs_list(
                    plan, el_cl_genesis_data.files_artifact_uuid
                )
            )
        else:  # Devnets
            # TODO Remove once checkpoint sync is working for verkle
            if constants.NETWORK_NAME.verkle not in network:
                cmd.append(
                    "--checkpoint-sync-url=https://checkpoint-sync.{0}.ethpandaops.io".format(
                        network
                    )
                )
            cmd.append(
                "--p2p-discovery-bootnodes="
                + shared_utils.get_devnet_enrs_list(
                    plan, el_cl_genesis_data.files_artifact_uuid
                )
            )
    else:  # Public networks
        cmd.append("--checkpoint-sync-url=" + constants.CHECKPOINT_SYNC_URL[network])

    if len(extra_params) > 0:
        # we do the list comprehension as the default extra_params is a proto repeated string
        cmd.extend([param for param in extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }
    if node_keystore_files != None and not use_separate_validator_client:
        files[
            VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER
        ] = node_keystore_files.files_artifact_uuid

    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=cl_volume_size,
        )
    return ServiceConfig(
        image=image,
        ports=BEACON_USED_PORTS,
        cmd=cmd,
        # entrypoint=ENTRYPOINT_ARGS,
        files=files,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ready_conditions=cl_node_ready_conditions.get_ready_conditions(
            BEACON_HTTP_PORT_ID
        ),
        min_cpu=bn_min_cpu,
        max_cpu=bn_max_cpu,
        min_memory=bn_min_mem,
        max_memory=bn_max_mem,
        labels=shared_utils.label_maker(
            constants.CL_CLIENT_TYPE.teku,
            constants.CLIENT_TYPES.cl,
            image,
            el_client_context.client_name,
            extra_labels,
        ),
        user=User(uid=0, gid=0),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )


def new_teku_launcher(el_cl_genesis_data, jwt_file, network):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data, jwt_file=jwt_file, network=network
    )
