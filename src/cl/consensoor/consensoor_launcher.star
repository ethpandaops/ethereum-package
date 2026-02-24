shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER = "/data/consensoor"

BEACON_DISCOVERY_PORT_NUM = 9000
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


def launch(
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
    tempo_otlp_grpc_url=None,
    bootnode_enr_override=None,
    cl_binary_artifact=None,
):
    beacon_config = get_beacon_config(
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
        bootnode_enr_override,
        cl_binary_artifact,
    )

    beacon_service = plan.add_service(
        beacon_service_name, beacon_config, force_update=participant.cl_force_restart
    )

    cl_context_obj = get_cl_context(
        plan,
        beacon_service_name,
        beacon_service,
        participant,
        snooper_el_engine_context,
        node_keystore_files,
        node_selectors,
    )

    return cl_context_obj


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
    bootnode_enr_override=None,
    cl_binary_artifact=None,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.cl_log_level, global_log_level, VERBOSITY_LEVELS
    )

    if participant.snooper_enabled:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            snooper_el_engine_context.ip_addr,
            snooper_el_engine_context.engine_rpc_port_num,
        )
    else:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            el_context.dns_name,
            el_context.engine_rpc_port_num,
        )

    public_ports = {}
    public_ports_for_component = None
    if port_publisher.cl_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "cl",
            port_publisher,
            participant_index,
        )
        public_ports = {
            constants.TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
                public_ports_for_component[0],
                shared_utils.TCP_PROTOCOL,
            ),
            constants.UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
                public_ports_for_component[0],
                shared_utils.UDP_PROTOCOL,
            ),
            constants.HTTP_PORT_ID: shared_utils.new_port_spec(
                public_ports_for_component[1],
                shared_utils.TCP_PROTOCOL,
                shared_utils.HTTP_APPLICATION_PROTOCOL,
            ),
            constants.METRICS_PORT_ID: shared_utils.new_port_spec(
                public_ports_for_component[2],
                shared_utils.TCP_PROTOCOL,
                shared_utils.HTTP_APPLICATION_PROTOCOL,
            ),
        }

    discovery_port = (
        public_ports_for_component[0]
        if public_ports_for_component
        else BEACON_DISCOVERY_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.HTTP_PORT_ID: BEACON_HTTP_PORT_NUM,
        constants.METRICS_PORT_ID: BEACON_METRICS_PORT_NUM,
    }

    used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "consensoor",
        "run",
        "--log-level=" + log_level,
        "--data-dir=" + BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER,
        "--engine-api-url=" + EXECUTION_ENGINE_ENDPOINT,
        "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--genesis-state="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/genesis.ssz",
        "--network-config="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--preset=" + network_params.preset,
        "--p2p-port={0}".format(discovery_port),
        "--p2p-host=0.0.0.0",
        "--beacon-api-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
        "--fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        "--graffiti=consensoor",
    ]

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

    if participant.supernode:
        cmd.append("--supernode")

    if len(participant.cl_extra_params) > 0:
        cmd.extend([param for param in participant.cl_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }

    if node_keystore_files != None:
        files[
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER
        ] = node_keystore_files.files_artifact_uuid

    if persistent:
        volume_size_key = (
            "devnets" if "devnet" in network_params.network else network_params.network
        )
        files[BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(beacon_service_name),
            size=int(participant.cl_volume_size)
            if int(participant.cl_volume_size) > 0
            else constants.VOLUME_SIZE[volume_size_key][
                constants.CL_TYPE.lighthouse + "_volume_size"
            ],
        )

    processed_mounts = shared_utils.process_extra_mounts(
        plan, participant.cl_extra_mounts, extra_files_artifacts
    )
    for mount_path, artifact in processed_mounts.items():
        files[mount_path] = artifact

    env_vars = participant.cl_extra_env_vars

    cmd_str = " ".join(cmd)
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
            connected_client=el_context.client_name,
            extra_labels=participant.cl_extra_labels
            | {constants.NODE_INDEX_LABEL_KEY: str(participant_index + 1)},
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if not participant.skip_start:
        config_args["ready_conditions"] = cl_node_ready_conditions.get_ready_conditions(
            constants.HTTP_PORT_ID
        )

    if int(participant.cl_min_cpu) > 0:
        config_args["min_cpu"] = int(participant.cl_min_cpu)
    if int(participant.cl_max_cpu) > 0:
        config_args["max_cpu"] = int(participant.cl_max_cpu)
    if int(participant.cl_min_mem) > 0:
        config_args["min_memory"] = int(participant.cl_min_mem)
    if int(participant.cl_max_mem) > 0:
        config_args["max_memory"] = int(participant.cl_max_mem)
    return ServiceConfig(**config_args)


def get_cl_context(
    plan,
    service_name,
    service,
    participant,
    snooper_el_engine_context,
    node_keystore_files,
    node_selectors,
):
    beacon_http_port = service.ports[constants.HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(service.name, beacon_http_port.number)

    if participant.skip_start:
        beacon_node_enr = ""
        beacon_multiaddr = ""
        beacon_peer_id = ""
    else:
        beacon_node_identity_recipe = GetHttpRequestRecipe(
            endpoint="/eth/v1/node/identity",
            port_id=constants.HTTP_PORT_ID,
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


def get_blobber_config(
    plan,
    participant,
    beacon_service_name,
    beacon_http_url,
    node_keystore_files,
    node_selectors,
):
    return None
