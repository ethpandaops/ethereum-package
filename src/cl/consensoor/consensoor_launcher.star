shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER = "/data/consensoor"

BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_QUIC_PORT_NUM = 9001
BEACON_HTTP_PORT_NUM = 5052
BEACON_METRICS_PORT_NUM = 8008

METRICS_PATH = "/metrics"

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARNING",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "DEBUG",
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

    # If snooper is enabled use the snooper engine context, otherwise use the execution client context
    EXECUTION_ENGINE_ENDPOINT = cl_shared.get_execution_engine_endpoint(
        participant, el_context, snooper_el_engine_context
    )

    public_ports = {}
    public_ports_for_component = None
    if port_publisher.cl_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "cl",
            port_publisher,
            participant_index,
        )
        public_ports = cl_shared.get_general_cl_public_port_specs(
            public_ports_for_component
        )
        public_ports.update(
            shared_utils.get_port_specs(
                {constants.QUIC_DISCOVERY_PORT_ID: public_ports_for_component[3]}
            )
        )

    discovery_port = (
        public_ports_for_component[0]
        if public_ports_for_component
        else BEACON_DISCOVERY_PORT_NUM
    )
    discovery_port_quic = (
        public_ports_for_component[3]
        if public_ports_for_component
        else BEACON_QUIC_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
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
        "consensoor",
        "run",
        "--log-level=" + log_level,
        "--data-dir=" + BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER,
        "--genesis-state="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/genesis.ssz",
        "--network-config="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--preset=" + network_params.preset,
        "--p2p-port={0}".format(discovery_port),
        "--p2p-host=0.0.0.0",
        "--quic-port={0}".format(discovery_port_quic),
        "--beacon-api-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
        "--fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
    ]

    if el_context != None:
        cmd.append("--engine-api-url=" + EXECUTION_ENGINE_ENDPOINT)
        cmd.append("--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER)

    if checkpoint_sync_enabled and checkpoint_sync_url:
        cmd.append("--checkpoint-sync-url=" + checkpoint_sync_url)

    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            shared_utils.path_base(node_keystore_files.teku_keys_relative_dirpath),
        )
        validator_secrets_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            shared_utils.path_base(node_keystore_files.teku_secrets_relative_dirpath),
        )
        cmd.append(
            "--validator-keys={0}:{1}".format(
                validator_keys_dirpath,
                validator_secrets_dirpath,
            )
        )

    bootnode_arg = bootnode_enr_override
    if network_params.network not in constants.PUBLIC_NETWORKS:
        if (
            network_params.network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network_params.network
        ):
            if bootnode_arg == None and bootnode_contexts != None:
                for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]:
                    if ctx.enr:
                        cmd.append("--bootnodes=" + ctx.enr)
                    elif ctx.multiaddr:
                        cmd.append("--bootnodes=" + ctx.multiaddr)
        elif bootnode_arg == None:  # Ephemery and devnets
            bootnode_arg = shared_utils.get_devnet_enrs_list(
                plan, launcher.el_cl_genesis_data.files_artifact_uuid
            )

    if bootnode_arg != None:
        cmd.append("--bootnodes=" + bootnode_arg)

    if participant.supernode:
        cmd.append("--supernode")

    if len(participant.cl_extra_params) > 0:
        cmd.extend([param for param in participant.cl_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
    }
    if el_context != None:
        files[constants.JWT_MOUNTPOINT_ON_CLIENTS] = launcher.jwt_file

    if node_keystore_files != None:
        files[
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER
        ] = node_keystore_files.files_artifact_uuid

    if persistent:
        # Consensoor has no volume-size entry of its own in constants.VOLUME_SIZE,
        # so it reuses the lighthouse key.
        files[
            BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER
        ] = cl_shared.get_beacon_data_directory(
            beacon_service_name,
            participant,
            network_params,
            constants.CL_TYPE.lighthouse,
        )

    processed_mounts = shared_utils.process_extra_mounts(
        plan, participant.cl_extra_mounts, extra_files_artifacts
    )
    for mount_path, artifact in processed_mounts.items():
        files[mount_path] = artifact

    # Binary injection - mount custom binary directory if provided
    if cl_binary_artifact != None:
        files["/opt/bin"] = cl_binary_artifact.artifact

    env_vars = shared_utils.with_otel_env_vars(
        participant.cl_extra_env_vars,
        otel_otlp_grpc_url,
        beacon_service_name,
    )

    # Build the command string, copying injected binary if provided
    cmd_str = " ".join(cmd)
    if cl_binary_artifact != None:
        cmd_str = (
            "cp /opt/bin/{0} /usr/local/bin/consensoor && exec ".format(
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
        "entrypoint": ["sh", "-c"],
        "cmd": [cmd_str],
        "files": files,
        "env_vars": env_vars,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "labels": shared_utils.label_maker(
            client=constants.CL_TYPE.consensoor,
            client_type=constants.CLIENT_TYPES.cl,
            image=participant.cl_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=el_context.client_name if el_context != None else "none",
            extra_labels=participant.cl_extra_labels
            | {constants.NODE_INDEX_LABEL_KEY: str(participant_index + 1)},
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

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

    (
        beacon_node_enr,
        beacon_multiaddr,
        beacon_peer_id,
    ) = cl_shared.get_beacon_node_identity(
        plan, service_name, participant, skip=skip_identity
    )

    beacon_metrics_port = service.ports[constants.METRICS_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(
        service.ip_address, beacon_metrics_port.number
    )
    nodes_metrics_info = [
        node_metrics.new_node_metrics_info(
            service_name, METRICS_PATH, beacon_metrics_url
        ),
    ]
    return cl_context.new_cl_context(
        client_name="consensoor",
        enr=beacon_node_enr,
        ip_addr=service.name,
        ip_address=service.ip_address,
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


def new_consensoor_launcher(el_cl_genesis_data, jwt_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
    )
