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
RPC_PORT_NUM = 4000
HTTP_PORT_NUM = 3500
BEACON_MONITORING_PORT_NUM = 8080
PROFILING_PORT_NUM = 6060

METRICS_PATH = "/metrics"

MIN_PEERS = 1

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
    service_name,
    image,
    participant_log_level,
    global_log_level,
    bootnode_contexts,
    el_context,
    full_name,
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
    tolerations,
    node_selectors,
    use_separate_vc,
    keymanager_enabled,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    participant_index,
):
    beacon_service_name = "{0}".format(service_name)
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )

    beacon_config = get_beacon_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        launcher.network,
        image,
        beacon_service_name,
        bootnode_contexts,
        el_context,
        log_level,
        cl_min_cpu,
        cl_max_cpu,
        cl_min_mem,
        cl_max_mem,
        snooper_enabled,
        snooper_engine_context,
        extra_params,
        extra_env_vars,
        extra_labels,
        persistent,
        cl_volume_size,
        tolerations,
        node_selectors,
        checkpoint_sync_enabled,
        checkpoint_sync_url,
        port_publisher,
        launcher.preset,
        participant_index,
    )

    beacon_service = plan.add_service(beacon_service_name, beacon_config)

    beacon_http_port = beacon_service.ports[constants.HTTP_PORT_ID]

    beacon_http_url = "http://{0}:{1}".format(beacon_service.ip_address, HTTP_PORT_NUM)
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
    beacon_image,
    service_name,
    bootnode_contexts,
    el_context,
    log_level,
    cl_min_cpu,
    cl_max_cpu,
    cl_min_mem,
    cl_max_mem,
    snooper_enabled,
    snooper_engine_context,
    extra_params,
    extra_env_vars,
    extra_labels,
    persistent,
    cl_volume_size,
    tolerations,
    node_selectors,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    preset,
    participant_index,
):
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

    public_ports = {}
    discovery_port = DISCOVERY_TCP_PORT_NUM
    if port_publisher.cl_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "cl", port_publisher, participant_index
        )
        public_ports, discovery_port = cl_shared.get_general_cl_public_port_specs(
            public_ports_for_component
        )
        public_ports.update(
            shared_utils.get_port_specs(
                {constants.RPC_PORT_ID: public_ports_for_component[3]}
            )
        )
        public_ports.update(
            shared_utils.get_port_specs(
                {constants.PROFILING_PORT_ID: public_ports_for_component[4]}
            )
        )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.HTTP_PORT_ID: HTTP_PORT_NUM,
        constants.METRICS_PORT_ID: BEACON_MONITORING_PORT_NUM,
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
        "--grpc-gateway-host=0.0.0.0",
        "--grpc-gateway-corsdomain=*",
        "--grpc-gateway-port={0}".format(HTTP_PORT_NUM),
        "--p2p-host-ip=" + port_publisher.nat_exit_ip,
        "--p2p-tcp-port={0}".format(discovery_port),
        "--p2p-udp-port={0}".format(discovery_port),
        "--min-sync-peers={0}".format(MIN_PEERS),
        "--verbosity=" + log_level,
        "--slots-per-archive-point={0}".format(32 if constants.ARCHIVE_MODE else 8192),
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--enable-debug-rpc-endpoints=true",
        # vvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(BEACON_MONITORING_PORT_NUM),
        # vvvvvvvvv PROFILING CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--pprof",
        "--pprofaddr=0.0.0.0",
        "--pprofport={0}".format(PROFILING_PORT_NUM),
    ]

    # If checkpoint sync is enabled, add the checkpoint sync url
    if checkpoint_sync_enabled:
        if checkpoint_sync_url:
            cmd.append("--checkpoint-sync-url=" + checkpoint_sync_url)
            cmd.append(
                "--genesis-beacon-api-url=" + constants.CHECKPOINT_SYNC_URL[network]
            )
        else:
            if (
                network in constants.PUBLIC_NETWORKS
                or network == constants.NETWORK_NAME.ephemery
            ):
                cmd.append(
                    "--checkpoint-sync-url=" + constants.CHECKPOINT_SYNC_URL[network]
                )
                cmd.append(
                    "--genesis-beacon-api-url=" + constants.CHECKPOINT_SYNC_URL[network]
                )
            else:
                fail(
                    "Checkpoint sync URL is required if you enabled checkpoint_sync for custom networks. Please provide a valid URL."
                )

    if preset == "minimal":
        cmd.append("--minimal-config=true")

    if network not in constants.PUBLIC_NETWORKS:
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
            network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network
        ):
            if bootnode_contexts != None:
                for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]:
                    cmd.append("--bootstrap-node=" + ctx.enr)
        elif network == constants.NETWORK_NAME.ephemery:
            cmd.append(
                "--genesis-beacon-api-url=" + constants.CHECKPOINT_SYNC_URL[network]
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
        cmd.append("--{}".format(network))

    if len(extra_params) > 0:
        # we do the for loop as otherwise its a proto repeated array
        cmd.extend([param for param in extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=cl_volume_size,
        )

    config_args = {
        "image": beacon_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "cmd": cmd,
        "files": files,
        "env_vars": extra_env_vars,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "ready_conditions": cl_node_ready_conditions.get_ready_conditions(
            constants.HTTP_PORT_ID
        ),
        "labels": shared_utils.label_maker(
            constants.CL_TYPE.prysm,
            constants.CLIENT_TYPES.cl,
            beacon_image,
            el_context.client_name,
            extra_labels,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if cl_min_cpu > 0:
        config_args["min_cpu"] = cl_min_cpu

    if cl_max_cpu > 0:
        config_args["max_cpu"] = cl_max_cpu

    if cl_min_mem > 0:
        config_args["min_memory"] = cl_min_mem

    if cl_max_mem > 0:
        config_args["max_memory"] = cl_max_mem

    return ServiceConfig(**config_args)


def new_prysm_launcher(
    el_cl_genesis_data,
    jwt_file,
    network_params,
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network_params.network,
        preset=network_params.preset,
        prysm_password_artifact_uuid=prysm_password_artifact_uuid,
        prysm_password_relative_filepath=prysm_password_relative_filepath,
    )
