shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")
vc_shared = import_module("../../vc/vc_shared.star")

TEKU_ENTRYPOINT_COMMAND = "/opt/teku/bin/teku"

# The Docker container runs as the "teku" user so we can't write to root
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/teku/teku-beacon-data"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_HTTP_PORT_NUM = 4000
BEACON_METRICS_PORT_NUM = 8008
BEACON_QUIC_PORT_NUM = 9001

BEACON_METRICS_PATH = "/metrics"

MIN_PEERS = 1

ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
    constants.GLOBAL_LOG_LEVEL.custom: "CUSTOM",
}


def get_beacon_config(
    plan,
    launcher,
    beacon_service_name,
    participant,
    global_log_level,
    bootnode_contexts,
    el_context,
    full_name,
    node_keystore_files,
    snooper_el_engine_context,
    persistent,
    tolerations,
    node_selectors,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    participant_index,
    network_params,
    extra_files_artifacts,
    backend,
    tempo_otlp_grpc_url,
    otel_otlp_grpc_url=None,
    bootnode_enr_override=None,
    cl_binary_artifact=None,
    skip_ready_conditions=False,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.cl_log_level, global_log_level, VERBOSITY_LEVELS
    )
    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files:
        validator_keys_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_secrets_relative_dirpath,
        )
    # If snooper is enabled use the snooper engine context, otherwise use the execution client context
    EXECUTION_ENGINE_ENDPOINT = cl_shared.get_execution_engine_endpoint(
        participant, el_context, snooper_el_engine_context
    )

    public_ports = {}
    public_ports_for_component = None
    validator_public_port_assignment = {}
    if port_publisher.cl_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "cl", port_publisher, participant_index
        )
        validator_public_port_assignment = {
            constants.VALIDATOR_HTTP_PORT_ID: public_ports_for_component[3]
        }
        public_ports = cl_shared.get_general_cl_public_port_specs(
            public_ports_for_component
        )
        public_ports.update(
            shared_utils.get_port_specs(
                {constants.QUIC_DISCOVERY_PORT_ID: public_ports_for_component[4]}
            )
        )

    discovery_port_tcp = (
        public_ports_for_component[0]
        if public_ports_for_component
        else BEACON_DISCOVERY_PORT_NUM
    )
    discovery_port_udp = (
        public_ports_for_component[0]
        if public_ports_for_component
        else BEACON_DISCOVERY_PORT_NUM
    )
    discovery_port_quic = (
        public_ports_for_component[4]
        if public_ports_for_component
        else BEACON_QUIC_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port_tcp,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port_udp,
        constants.QUIC_DISCOVERY_PORT_ID: discovery_port_quic,
        constants.HTTP_PORT_ID: BEACON_HTTP_PORT_NUM,
        constants.METRICS_PORT_ID: BEACON_METRICS_PORT_NUM,
    }
    # Disable port checks if skip_start is enabled
    if participant.skip_start:
        used_ports = shared_utils.get_port_specs(used_port_assignments, wait=None)
    else:
        used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        TEKU_ENTRYPOINT_COMMAND,
        "--network={0}".format(
            network_params.network
            if network_params.network in constants.PUBLIC_NETWORKS
            else constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/config.yaml"
        ),
        "--data-path=" + BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--data-storage-mode={0}".format(
            "ARCHIVE" if constants.ARCHIVE_MODE else "PRUNE"
        ),
        "--p2p-enabled=true",
        "--p2p-peer-lower-bound={0}".format(MIN_PEERS),
        "--p2p-advertised-ip={0}".format(
            "${K8S_POD_IP}"
            if backend == "kubernetes"
            else port_publisher.cl_nat_exit_ip
        ),
        "--p2p-discovery-site-local-addresses-enabled=true",
        "--p2p-port={0}".format(discovery_port_tcp),
        "--rest-api-enabled=true",
        "--rest-api-docs-enabled=true",
        "--rest-api-interface=0.0.0.0",
        "--rest-api-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--rest-api-host-allowlist=*",
        "--data-storage-non-canonical-blocks-enabled=true",
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics-enabled",
        "--metrics-interface=0.0.0.0",
        "--metrics-host-allowlist=*",
        "--metrics-categories=BEACON,PROCESS,LIBP2P,JVM,NETWORK,PROCESS",
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    if el_context != None:
        cmd.append("--ee-jwt-secret-file=" + constants.JWT_MOUNT_PATH_ON_CONTAINER)
        cmd.append("--ee-endpoint=" + EXECUTION_ENGINE_ENDPOINT)

    if log_level == "CUSTOM":
        cmd.append("--log-destination=CUSTOM")
    else:
        cmd.append("--logging=" + log_level)
        cmd.append("--log-destination=CONSOLE")

    validator_default_cmd = [
        "--validator-keys={0}:{1}".format(
            validator_keys_dirpath,
            validator_secrets_dirpath,
        ),
        "--validators-proposer-default-fee-recipient="
        + constants.VALIDATING_REWARDS_ACCOUNT,
    ]

    keymanager_api_cmd = [
        "--validator-api-enabled=true",
        "--validator-api-host-allowlist=*",
        "--validator-api-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--validator-api-interface=0.0.0.0",
        "--validator-api-bearer-file=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
        "--Xvalidator-api-ssl-enabled=false",
        "--Xvalidator-api-unsafe-hosts-enabled=true",
    ]

    supernode_cmd = [
        "--p2p-subscribe-all-custody-subnets-enabled=true",
    ]

    if network_params.perfect_peerdas_enabled and participant_index < 16:
        cmd.append(
            "--Xp2p-private-key-file-secp256k1="
            + constants.NODE_KEY_MOUNTPOINT_ON_CLIENTS
            + "/node-key-file-{0}".format(participant_index + 1)
        )

    if participant.supernode:
        cmd.extend(supernode_cmd)

    if checkpoint_sync_enabled:
        cmd.append("--checkpoint-sync-url=" + checkpoint_sync_url)
    else:
        cmd.append("--ignore-weak-subjectivity-period-enabled=true")

    if network_params.network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--genesis-state="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis.ssz"
        )

    cl_shared.append_bootnode_arg(
        plan,
        cmd,
        "--p2p-discovery-bootnodes=",
        launcher,
        network_params,
        bootnode_contexts,
        bootnode_enr_override,
    )

    if len(participant.cl_extra_params) > 0:
        # we do the list comprehension as the default extra_params is a proto repeated string
        cmd.extend([param for param in participant.cl_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
    }
    if el_context != None:
        files[constants.JWT_MOUNTPOINT_ON_CLIENTS] = launcher.jwt_file

    if network_params.perfect_peerdas_enabled and participant_index < 16:
        files[constants.NODE_KEY_MOUNTPOINT_ON_CLIENTS] = Directory(
            artifact_names=["node-key-file-{0}".format(participant_index + 1)]
        )

    if node_keystore_files != None and not participant.use_separate_vc:
        cmd.extend(validator_default_cmd)
        files[
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER
        ] = node_keystore_files.files_artifact_uuid

        if participant.keymanager_enabled:
            files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = launcher.keymanager_file
            cmd.extend(keymanager_api_cmd)
            used_ports.update(vc_shared.VALIDATOR_KEYMANAGER_USED_PORTS)
            public_ports.update(
                shared_utils.get_port_specs(validator_public_port_assignment)
            )

        if network_params.gas_limit > 0:
            cmd.append(
                "--validators-builder-registration-default-gas-limit={0}".format(
                    network_params.gas_limit
                )
            )

    if persistent:
        files[
            BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER
        ] = cl_shared.get_beacon_data_directory(
            beacon_service_name, participant, network_params, constants.CL_TYPE.teku
        )

    # Add extra mounts - automatically handle file uploads
    processed_mounts = shared_utils.process_extra_mounts(
        plan, participant.cl_extra_mounts, extra_files_artifacts
    )
    for mount_path, artifact in processed_mounts.items():
        files[mount_path] = artifact

    # Binary injection - mount custom binary directory if provided
    if cl_binary_artifact != None:
        files["/opt/bin"] = cl_binary_artifact.artifact

    # Build the command string, copying injected binary if provided
    cmd_str = " ".join(cmd)
    if cl_binary_artifact != None:
        cmd_str = (
            "cp /opt/bin/{0} /opt/teku/bin/teku && exec ".format(
                cl_binary_artifact.filename
            )
            + cmd_str
        )
    else:
        cmd_str = "exec " + cmd_str

    config_args = {
        "image": participant.cl_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.cl_enabled,
        "entrypoint": ["sh", "-c"],
        "cmd": [cmd_str],
        "files": files,
        "env_vars": shared_utils.with_otel_env_vars(
            participant.cl_extra_env_vars,
            otel_otlp_grpc_url,
            beacon_service_name,
        ),
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "labels": shared_utils.label_maker(
            client=constants.CL_TYPE.teku,
            client_type=constants.CLIENT_TYPES.cl,
            image=participant.cl_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=el_context.client_name if el_context != None else "none",
            extra_labels=participant.cl_extra_labels
            | {constants.NODE_INDEX_LABEL_KEY: str(participant_index + 1)},
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
        "user": User(uid=0, gid=0),
    }

    if len(participant.cl_devices) > 0:
        config_args["devices"] = participant.cl_devices
    # Only add ready_conditions if not skipping start
    if not participant.skip_start and not skip_ready_conditions:
        config_args["ready_conditions"] = cl_node_ready_conditions.get_ready_conditions(
            constants.HTTP_PORT_ID
        )

    cl_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)


def get_cl_context(
    plan,
    service_name,
    service,
    participant,
    snooper_el_engine_context,
    node_keystore_files,
    node_selectors,
    skip_identity=False,
):
    beacon_http_port = service.ports[constants.HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(service.name, beacon_http_port.number)

    beacon_metrics_port = service.ports[constants.METRICS_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(service.name, beacon_metrics_port.number)

    (
        beacon_node_enr,
        beacon_multiaddr,
        beacon_peer_id,
    ) = cl_shared.get_beacon_node_identity(
        plan, service_name, participant, skip=skip_identity
    )

    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, BEACON_METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    return cl_context.new_cl_context(
        client_name="teku",
        enr=beacon_node_enr,
        ip_addr=service.name,
        http_port=beacon_http_port.number,
        beacon_http_url=beacon_http_url,
        cl_nodes_metrics_info=nodes_metrics_info,
        beacon_service_name=service_name,
        multiaddr=beacon_multiaddr,
        peer_id=beacon_peer_id,
        snooper_enabled=participant.snooper_enabled,
        snooper_el_engine_context=snooper_el_engine_context,
        validator_keystore_files_artifact_uuid=node_keystore_files.files_artifact_uuid
        if node_keystore_files
        else "",
        supernode=participant.supernode,
    )


def new_teku_launcher(el_cl_genesis_data, jwt_file, keymanager_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        keymanager_file=keymanager_file,
    )
