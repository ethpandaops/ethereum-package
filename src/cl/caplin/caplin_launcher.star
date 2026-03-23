shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER = "/data/caplin/caplin-beacon-data"

BEACON_SENTINEL_PORT_NUM = 7777
BEACON_HTTP_PORT_NUM = 5555
BEACON_METRICS_PORT_NUM = 6060

METRICS_PATH = "/debug/metrics/prometheus"

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "1",
    constants.GLOBAL_LOG_LEVEL.warn: "2",
    constants.GLOBAL_LOG_LEVEL.info: "3",
    constants.GLOBAL_LOG_LEVEL.debug: "4",
    constants.GLOBAL_LOG_LEVEL.trace: "5",
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
        engine_host = "http://{0}".format(snooper_el_engine_context.ip_addr)
        engine_port = snooper_el_engine_context.engine_rpc_port_num
    else:
        engine_host = "http://{0}".format(el_context.dns_name)
        engine_port = el_context.engine_rpc_port_num

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

    sentinel_port = (
        public_ports_for_component[0]
        if public_ports_for_component
        else BEACON_SENTINEL_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: sentinel_port,
        constants.UDP_DISCOVERY_PORT_ID: sentinel_port,
        constants.HTTP_PORT_ID: BEACON_HTTP_PORT_NUM,
        constants.METRICS_PORT_ID: BEACON_METRICS_PORT_NUM,
    }

    used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "caplin",
        "--datadir=" + BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER,
        "--verbosity=" + log_level,
        "--engine.api",
        "--engine.api.host=" + engine_host,
        "--engine.api.port={0}".format(engine_port),
        "--engine.api.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--beacon.api=beacon,builder,config,debug,events,node,validator,lighthouse",
        "--beacon.api.addr=0.0.0.0",
        "--beacon.api.port={0}".format(BEACON_HTTP_PORT_NUM),
        "--sentinel.addr=0.0.0.0",
        "--sentinel.port={0}".format(sentinel_port),
        "--pprof",
        "--pprof.addr=0.0.0.0",
        "--pprof.port={0}".format(BEACON_METRICS_PORT_NUM),
    ]

    if checkpoint_sync_enabled and checkpoint_sync_url:
        cmd.append("--caplin.checkpoint-sync-url=" + checkpoint_sync_url)

    if network_params.network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--custom-config="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/config.yaml"
        )
        cmd.append(
            "--custom-genesis-state="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis.ssz"
        )
        if (
            network_params.network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network_params.network
        ):
            bootnode_arg = bootnode_enr_override
            if bootnode_arg == None and bootnode_contexts != None:
                bootnodes = []
                for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]:
                    if ctx.enr:
                        bootnodes.append(ctx.enr)
                    elif ctx.multiaddr:
                        bootnodes.append(ctx.multiaddr)
                if bootnodes:
                    cmd.append("--sentinel.bootnodes=" + ",".join(bootnodes))
    else:
        cmd.append("--chain=" + network_params.network)

    if len(participant.cl_extra_params) > 0:
        cmd.extend([param for param in participant.cl_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }

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

    if cl_binary_artifact != None:
        files["/opt/bin"] = cl_binary_artifact.artifact

    env_vars = participant.cl_extra_env_vars

    cmd_str = " ".join(cmd)
    if cl_binary_artifact != None:
        cmd_str = (
            "cp /opt/bin/{0} /usr/local/bin/caplin && exec ".format(
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
        "user": User(uid=0, gid=0),
        "entrypoint": ["sh", "-c"],
        "cmd": [cmd_str],
        "files": files,
        "env_vars": env_vars,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "labels": shared_utils.label_maker(
            client=constants.CL_TYPE.caplin,
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
        client_name="caplin",
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


def new_caplin_launcher(el_cl_genesis_data, jwt_file):
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
