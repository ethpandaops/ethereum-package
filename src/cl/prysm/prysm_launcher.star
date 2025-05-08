shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

#  ---------------------------------- Beacon client -------------------------------------
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/prysm/beacon-data/"

# Port nums
DISCOVERY_TCP_PORT_NUM = 13000
DISCOVERY_UDP_PORT_NUM = 12000
DISCOVERY_QUIC_PORT_NUM = 13000
BEACON_HTTP_PORT_NUM = 3500
RPC_PORT_NUM = 4000
BEACON_MONITORING_PORT_NUM = 8080
PROFILING_PORT_NUM = 6060

METRICS_PATH = "/metrics"

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "trace",
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
    snooper_engine_context,
    persistent,
    tolerations,
    node_selectors,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    participant_index,
    network_params,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.cl_log_level, global_log_level, VERBOSITY_LEVELS
    )

    beacon_config = get_beacon_config(
        plan,
        launcher,
        beacon_service_name,
        participant,
        log_level,
        bootnode_contexts,
        el_context,
        full_name,
        node_keystore_files,
        snooper_engine_context,
        persistent,
        tolerations,
        node_selectors,
        checkpoint_sync_enabled,
        checkpoint_sync_url,
        port_publisher,
        participant_index,
        network_params,
    )

    beacon_service = plan.add_service(beacon_service_name, beacon_config)

    beacon_http_port = beacon_service.ports[constants.HTTP_PORT_ID]

    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, BEACON_HTTP_PORT_NUM
    )
    beacon_grpc_url = "{0}:{1}".format(beacon_service.ip_address, RPC_PORT_NUM)

    # TODO(old) add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module
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
        recipe=beacon_node_identity_recipe, service_name=beacon_service_name
    )
    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    beacon_metrics_port = beacon_service.ports[constants.METRICS_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(
        beacon_service.ip_address, beacon_metrics_port.number
    )
    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        beacon_service_name, METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    return cl_context.new_cl_context(
        client_name="prysm",
        enr=beacon_node_enr,
        ip_addr=beacon_service.ip_address,
        http_port=beacon_http_port.number,
        beacon_http_url=beacon_http_url,
        cl_nodes_metrics_info=nodes_metrics_info,
        beacon_service_name=beacon_service_name,
        beacon_grpc_url=beacon_grpc_url,
        multiaddr=beacon_multiaddr,
        peer_id=beacon_peer_id,
        snooper_enabled=participant.snooper_enabled,
        snooper_engine_context=snooper_engine_context,
        validator_keystore_files_artifact_uuid=node_keystore_files.files_artifact_uuid
        if node_keystore_files
        else "",
        supernode=participant.supernode,
    )


def get_beacon_config(
    plan,
    launcher,
    beacon_service_name,
    participant,
    log_level,
    bootnode_contexts,
    el_context,
    full_name,
    node_keystore_files,
    snooper_engine_context,
    persistent,
    tolerations,
    node_selectors,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    participant_index,
    network_params,
):
    # If snooper is enabled use the snooper engine context, otherwise use the execution client context
    if participant.snooper_enabled:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            snooper_engine_context.ip_addr,
            snooper_engine_context.engine_rpc_port_num,
        )
    else:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            el_context.ip_addr,
            el_context.engine_rpc_port_num,
        )

    public_ports = {}
    public_ports_for_component = None
    if port_publisher.cl_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "cl", port_publisher, participant_index
        )
        public_ports = cl_shared.get_general_cl_public_port_specs(
            public_ports_for_component
        )

        public_ports.update(
            shared_utils.get_port_specs(
                {constants.QUIC_DISCOVERY_PORT_ID: public_ports_for_component[0]}
            )
        )
        public_ports.update(
            shared_utils.get_port_specs(
                {constants.UDP_DISCOVERY_PORT_ID: public_ports_for_component[1]}
            )
        )
        public_ports.update(
            shared_utils.get_port_specs(
                {constants.RPC_PORT_ID: public_ports_for_component[5]}
            )
        )
        public_ports.update(
            shared_utils.get_port_specs(
                {constants.PROFILING_PORT_ID: public_ports_for_component[6]}
            )
        )

    discovery_port_tcp = (
        public_ports_for_component[0]
        if public_ports_for_component
        else DISCOVERY_TCP_PORT_NUM
    )
    discovery_port_udp = (
        public_ports_for_component[1]
        if public_ports_for_component
        else DISCOVERY_UDP_PORT_NUM
    )
    discovery_port_quic = (
        public_ports_for_component[0]
        if public_ports_for_component
        else DISCOVERY_QUIC_PORT_NUM
    )  # use the same port for quic and tcp

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port_tcp,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port_udp,
        constants.HTTP_PORT_ID: BEACON_HTTP_PORT_NUM,
        constants.METRICS_PORT_ID: BEACON_MONITORING_PORT_NUM,
        constants.QUIC_DISCOVERY_PORT_ID: discovery_port_quic,
        constants.RPC_PORT_ID: RPC_PORT_NUM,
        constants.PROFILING_PORT_ID: PROFILING_PORT_NUM,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "--accept-terms-of-use=true",  # it's mandatory in order to run the node
        "--datadir=" + BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--execution-endpoint=" + EXECUTION_ENGINE_ENDPOINT,
        "--rpc-host=0.0.0.0",
        "--rpc-port={0}".format(RPC_PORT_NUM),
        "--http-host=0.0.0.0",
        "--http-cors-domain=*",
        "--http-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--p2p-host-ip=" + port_publisher.nat_exit_ip,
        "--p2p-tcp-port={0}".format(discovery_port_tcp),
        "--p2p-udp-port={0}".format(discovery_port_udp),
        "--p2p-quic-port={0}".format(discovery_port_quic),
        "--min-sync-peers={0}".format(constants.MIN_PEERS),
        "--verbosity=" + log_level,
        "--slots-per-archive-point={0}".format(32 if constants.ARCHIVE_MODE else 8192),
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        # vvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(BEACON_MONITORING_PORT_NUM),
        # vvvvvvvvv PROFILING CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--pprof",
        "--pprofaddr=0.0.0.0",
        "--pprofport={0}".format(PROFILING_PORT_NUM),
    ]

    supernode_cmd = [
        "--subscribe-all-data-subnets=true",
    ]

    if network_params.perfect_peerdas_enabled and participant_index < 16:
        cmd.append(
            "--p2p-priv-key="
            + constants.NODE_KEY_MOUNTPOINT_ON_CLIENTS
            + "/node-key-file-{0}".format(participant_index + 1)
        )

    if participant.supernode:
        cmd.extend(supernode_cmd)

    if checkpoint_sync_enabled:
        cmd.append("--checkpoint-sync-url=" + checkpoint_sync_url)
        cmd.append("--genesis-beacon-api-url=" + checkpoint_sync_url)

    if network_params.preset == "minimal":
        cmd.append("--minimal-config=true")

    if network_params.network not in constants.PUBLIC_NETWORKS:
        cmd.append("--p2p-static-id=true")
        cmd.append(
            "--chain-config-file="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/config.yaml"
        )
        cmd.append(
            "--genesis-state="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis.ssz",
        )
        cmd.append("--contract-deployment-block=0")
        if (
            network_params.network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network_params.network
        ):
            if bootnode_contexts != None:
                for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]:
                    cmd.append("--bootstrap-node=" + ctx.enr)
        elif network_params.network == constants.NETWORK_NAME.ephemery:
            cmd.append(
                "--genesis-beacon-api-url="
                + constants.CHECKPOINT_SYNC_URL[network_params.network]
            )
            cmd.append(
                "--bootstrap-node="
                + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
                + "/bootstrap_nodes.yaml"
            )
        else:  # Devnets
            cmd.append(
                "--bootstrap-node="
                + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
                + "/bootstrap_nodes.yaml"
            )
    else:  # Public network
        cmd.append("--{}".format(network_params.network))

    if len(participant.cl_extra_params) > 0:
        # we do the for loop as otherwise its a proto repeated array
        cmd.extend([param for param in participant.cl_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }
    if network_params.perfect_peerdas_enabled and participant_index < 16:
        files[constants.NODE_KEY_MOUNTPOINT_ON_CLIENTS] = Directory(
            artifact_names=["node-key-file-{0}".format(participant_index + 1)]
        )
    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(beacon_service_name),
            size=int(participant.cl_volume_size)
            if int(participant.cl_volume_size) > 0
            else constants.VOLUME_SIZE[network_params.network][
                constants.CL_TYPE.prysm + "_volume_size"
            ],
        )

    config_args = {
        "image": participant.cl_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "cmd": cmd,
        "files": files,
        "env_vars": participant.cl_extra_env_vars,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "ready_conditions": cl_node_ready_conditions.get_ready_conditions(
            constants.HTTP_PORT_ID
        ),
        "labels": shared_utils.label_maker(
            client=constants.CL_TYPE.prysm,
            client_type=constants.CLIENT_TYPES.cl,
            image=participant.cl_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=el_context.client_name,
            extra_labels=participant.cl_extra_labels,
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if int(participant.cl_min_cpu) > 0:
        config_args["min_cpu"] = int(participant.cl_min_cpu)
    if int(participant.cl_max_cpu) > 0:
        config_args["max_cpu"] = int(participant.cl_max_cpu)
    if int(participant.cl_min_mem) > 0:
        config_args["min_memory"] = int(participant.cl_min_mem)
    if int(participant.cl_max_mem) > 0:
        config_args["max_memory"] = int(participant.cl_max_mem)
    return ServiceConfig(**config_args)


def new_prysm_launcher(
    el_cl_genesis_data,
    jwt_file,
):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
    )
