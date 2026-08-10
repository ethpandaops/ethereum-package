shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

LIGHTHOUSE_ENTRYPOINT_COMMAND = "lighthouse"

RUST_BACKTRACE_ENVVAR_NAME = "RUST_BACKTRACE"
RUST_FULL_BACKTRACE_KEYWORD = "full"

#  ---------------------------------- Beacon client -------------------------------------
BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER = "/data/lighthouse/beacon-data"
NODE_KEY_MOUNTPOINT_ON_CLIENTS = (
    BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER + "/beacon/network"
)
# Port nums
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_HTTP_PORT_NUM = 4000
BEACON_METRICS_PORT_NUM = 5054
BEACON_QUIC_PORT_NUM = 9001
# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 50
BEACON_MIN_MEMORY = 256

METRICS_PATH = "/metrics"

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
        public_ports_for_component[3]
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
        LIGHTHOUSE_ENTRYPOINT_COMMAND,
        "beacon_node",
        "--debug-level=" + log_level,
        "--datadir=" + BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER,
        "--listen-address=0.0.0.0",
        "--port={0}".format(
            discovery_port_tcp
        ),  # NOTE: Remove for connecting to external net!
        "--http",
        "--http-address=0.0.0.0",
        "--http-port={0}".format(BEACON_HTTP_PORT_NUM),
        # NOTE: This comes from:
        #   https://github.com/sigp/lighthouse/blob/7c88f582d955537f7ffff9b2c879dcf5bf80ce13/scripts/local_testnet/beacon_node.sh
        # and the option says it's "useful for testing in smaller networks" (unclear what happens in larger networks)
        "--disable-packet-filter",
        # ENR
        "--disable-enr-auto-update",
        "--enr-address={0}".format(
            "${K8S_POD_IP}"
            if backend == "kubernetes"
            else port_publisher.cl_nat_exit_ip
        ),
        "--enr-tcp-port={0}".format(discovery_port_tcp),
        "--enr-udp-port={0}".format(discovery_port_udp),
        # QUIC
        "--enr-quic-port={0}".format(discovery_port_quic),
        "--quic-port={0}".format(discovery_port_quic),
        # Metrics
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-allow-origin=*",
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
        "--enable-private-discovery",
    ]

    if el_context != None:
        cmd.append("--execution-endpoints=" + EXECUTION_ENGINE_ENDPOINT)
        cmd.append("--jwt-secrets=" + constants.JWT_MOUNT_PATH_ON_CONTAINER)
        cmd.append("--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT)

    supernode_cmd = [
        "--supernode",
    ]

    if participant.supernode:
        cmd.extend(supernode_cmd)

    if checkpoint_sync_enabled:
        cmd.append("--checkpoint-sync-url=" + checkpoint_sync_url)
    else:
        cmd.append("--allow-insecure-genesis-sync")

    if network_params.network not in constants.PUBLIC_NETWORKS:
        cmd.append("--testnet-dir=" + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER)
    else:  # Public networks
        cmd.append("--network=" + network_params.network)

    # Add bootnode argument if set
    cl_shared.append_bootnode_arg(
        plan,
        cmd,
        "--boot-nodes=",
        launcher,
        network_params,
        bootnode_contexts,
        bootnode_enr_override,
    )

    telemetry_url = (
        otel_otlp_grpc_url if otel_otlp_grpc_url != None else tempo_otlp_grpc_url
    )
    if telemetry_url != None:
        cmd.append("--telemetry-collector-url={}".format(telemetry_url))
        cmd.append("--telemetry-service-name={}".format(beacon_service_name))

    if len(participant.cl_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.cl_extra_params])

    recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity", port_id=constants.HTTP_PORT_ID
    )
    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
    }
    if el_context != None:
        files[constants.JWT_MOUNTPOINT_ON_CLIENTS] = launcher.jwt_file

    if network_params.perfect_peerdas_enabled and participant_index < 16:
        files[NODE_KEY_MOUNTPOINT_ON_CLIENTS] = "node-key-file-{0}".format(
            participant_index + 1
        )

    if persistent:
        files[
            BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER
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
    # The artifact is a directory, so we mount it and reference the binary inside
    if cl_binary_artifact != None:
        files["/opt/bin"] = cl_binary_artifact.artifact

    env_vars = {RUST_BACKTRACE_ENVVAR_NAME: RUST_FULL_BACKTRACE_KEYWORD}
    env_vars.update(
        shared_utils.with_otel_env_vars(
            participant.cl_extra_env_vars,
            otel_otlp_grpc_url,
            beacon_service_name,
        )
    )

    # Build the command string, copying injected binary if provided
    cmd_str = " ".join(cmd)
    if cl_binary_artifact != None:
        cmd_str = (
            "cp /opt/bin/{0} /usr/local/bin/lighthouse && exec ".format(
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
        "env_vars": env_vars,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "labels": shared_utils.label_maker(
            client=constants.CL_TYPE.lighthouse,
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

    # TODO(old) add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module
    (
        beacon_node_enr,
        beacon_multiaddr,
        beacon_peer_id,
    ) = cl_shared.get_beacon_node_identity(
        plan, service_name, participant, skip=skip_identity
    )

    beacon_metrics_port = service.ports[constants.METRICS_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(service.name, beacon_metrics_port.number)
    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]
    return cl_context.new_cl_context(
        client_name="lighthouse",
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
        validator_keystore_files_artifact_uuid=(
            node_keystore_files.files_artifact_uuid if node_keystore_files else ""
        ),
        supernode=participant.supernode,
    )


def new_lighthouse_launcher(el_cl_genesis_data, jwt_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
    )
