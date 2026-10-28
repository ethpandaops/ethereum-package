shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

# ethlambda's beacon node runs no validators itself, so they always run in a
# separate validator client (by default ethlambda's own, src/vc/ethlambda.star),
# which reaches it over the validator API.

ETHLAMBDA_BINARY_PATH = "/usr/local/bin/ethlambda"

BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/ethlambda/beacon-data"
NODE_KEY_MOUNTPOINT_ON_CLIENTS = "/node-key"
# ethlambda takes its bootnodes as a file of ENRs rather than a flag value, so
# the resolved list is written here at container start.
BOOTNODES_FILEPATH_ON_SERVICE_CONTAINER = "/tmp/ethlambda-bootnodes.txt"

# Port nums
# discv5 binds UDP on its own port, while libp2p binds both QUIC (UDP) and the
# noise+yamux fallback (TCP) on a second one.
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_LIBP2P_PORT_NUM = 9001
BEACON_HTTP_PORT_NUM = 5052
BEACON_METRICS_PORT_NUM = 5054
BEACON_METRICS_PATH = "/metrics"

# Custodying every group is what makes a node a supernode
NUMBER_OF_CUSTODY_GROUPS = 128

# ethlambda filters its logs through RUST_LOG (tracing's EnvFilter).
LOG_LEVEL_ENV_VAR = "RUST_LOG"
VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "trace",
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
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.cl_log_level, global_log_level, VERBOSITY_LEVELS
    )

    # If snooper is enabled use the snooper engine context, otherwise use the execution client context
    execution_engine_endpoint = cl_shared.get_execution_engine_endpoint(
        participant, el_context, snooper_el_engine_context
    )

    public_ports = {}
    public_ports_for_component = None
    if port_publisher.cl_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "cl", port_publisher, participant_index
        )
        # The libp2p TCP and QUIC listeners share one number, so they share the
        # QUIC slot; discv5 takes the discovery slot on its own.
        public_ports = shared_utils.get_port_specs(
            {
                constants.TCP_DISCOVERY_PORT_ID: public_ports_for_component[4],
                constants.UDP_DISCOVERY_PORT_ID: public_ports_for_component[0],
                constants.QUIC_DISCOVERY_PORT_ID: public_ports_for_component[4],
                constants.HTTP_PORT_ID: public_ports_for_component[1],
                constants.METRICS_PORT_ID: public_ports_for_component[2],
            }
        )

    discovery_port = (
        public_ports_for_component[0]
        if public_ports_for_component
        else BEACON_DISCOVERY_PORT_NUM
    )
    libp2p_port = (
        public_ports_for_component[4]
        if public_ports_for_component
        else BEACON_LIBP2P_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: libp2p_port,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.QUIC_DISCOVERY_PORT_ID: libp2p_port,
        constants.HTTP_PORT_ID: BEACON_HTTP_PORT_NUM,
        constants.METRICS_PORT_ID: BEACON_METRICS_PORT_NUM,
    }
    # Disable port checks if skip_start is enabled
    if participant.skip_start:
        used_ports = shared_utils.get_port_specs(used_port_assignments, wait=None)
    else:
        used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        ETHLAMBDA_BINARY_PATH,
        "beacon",
        # The built-in networks are exactly constants.PUBLIC_NETWORKS; anything
        # else is read from the mounted network config directory.
        "--network={0}".format(
            network_params.network
            if network_params.network in constants.PUBLIC_NETWORKS
            else constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        ),
        "--data-dir=" + BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--http-address=0.0.0.0",
        "--api-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
        "--gossipsub-port={0}".format(libp2p_port),
        "--discovery.port={0}".format(discovery_port),
        # The ENR otherwise advertises the 0.0.0.0 bind address
        "--discovery.advertise-ip={0}".format(
            "${K8S_POD_IP}"
            if backend == "kubernetes"
            else port_publisher.cl_nat_exit_ip
        ),
    ]

    if el_context != None:
        cmd.append("--execution-endpoint=" + execution_engine_endpoint)
        cmd.append("--execution-jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER)

    if participant.supernode:
        cmd.append("--custody-group-count={0}".format(NUMBER_OF_CUSTODY_GROUPS))

    if checkpoint_sync_enabled:
        cmd.append("--checkpoint-sync-url=" + checkpoint_sync_url)

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
    }
    if el_context != None:
        files[constants.JWT_MOUNTPOINT_ON_CLIENTS] = launcher.jwt_file

    if network_params.perfect_peerdas_enabled and participant_index < 16:
        files[NODE_KEY_MOUNTPOINT_ON_CLIENTS] = "node-key-file-{0}".format(
            participant_index + 1
        )
        cmd.append(
            "--node-key="
            + NODE_KEY_MOUNTPOINT_ON_CLIENTS
            + "/node-key-file-{0}".format(participant_index + 1)
        )

    # Shell commands run before the client starts
    setup_cmds = []
    bootnode_arg = cl_shared.get_bootnode_arg(
        plan,
        launcher,
        network_params,
        bootnode_contexts,
        bootnode_enr_override,
    )
    if bootnode_arg != None:
        setup_cmds.append(
            "echo '{0}' | tr ',' '\\n' > {1}".format(
                bootnode_arg, BOOTNODES_FILEPATH_ON_SERVICE_CONTAINER
            )
        )
        cmd.append("--bootnodes=" + BOOTNODES_FILEPATH_ON_SERVICE_CONTAINER)

    if len(participant.cl_extra_params) > 0:
        # we do the list comprehension as the default participant.extra_params is a proto repeated string
        cmd.extend([param for param in participant.cl_extra_params])

    if persistent:
        files[
            BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER
        ] = cl_shared.get_beacon_data_directory(
            beacon_service_name,
            participant,
            network_params,
            constants.CL_TYPE.lighthouse,
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
        setup_cmds.append(
            "cp /opt/bin/{0} {1}".format(
                cl_binary_artifact.filename, ETHLAMBDA_BINARY_PATH
            )
        )

    cmd_str = " && ".join(setup_cmds + ["exec " + " ".join(cmd)])

    env_vars = {LOG_LEVEL_ENV_VAR: log_level}
    env_vars.update(
        shared_utils.with_otel_env_vars(
            participant.cl_extra_env_vars,
            otel_otlp_grpc_url,
            beacon_service_name,
        )
    )

    config_args = {
        "image": participant.cl_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.cl_enabled,
        "entrypoint": ["sh", "-c"],
        "cmd": [cmd_str],
        "files": files,
        "env_vars": env_vars,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "labels": shared_utils.label_maker(
            client=constants.CL_TYPE.ethlambda,
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

    if len(participant.cl_devices) > 0:
        config_args["devices"] = participant.cl_devices
    # Only add ready_conditions if not skipping start
    if not participant.skip_start:
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
):
    beacon_http_port = service.ports[constants.HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(service.name, beacon_http_port.number)

    beacon_metrics_port = service.ports[constants.METRICS_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(service.name, beacon_metrics_port.number)

    # The ENR is what later CLs bootstrap from; without it an ethlambda node
    # cannot be the network's bootnode. ethlambda lists its QUIC address first
    # and its TCP one last, and not every client dials QUIC, so take the last.
    (
        beacon_node_enr,
        beacon_multiaddr,
        beacon_peer_id,
    ) = cl_shared.get_beacon_node_identity(
        plan,
        service_name,
        participant,
        multiaddr_index=-1,
    )

    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, BEACON_METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]
    return cl_context.new_cl_context(
        client_name="ethlambda",
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


def new_ethlambda_launcher(el_cl_genesis_data, jwt_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
    )
