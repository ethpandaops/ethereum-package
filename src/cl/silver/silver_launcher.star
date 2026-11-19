shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")
static_files = import_module("../../static_files/static_files.star")

BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER = "/data/silver"

BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_QUIC_PORT_NUM = 9001
BEACON_HTTP_PORT_NUM = 5051

CONFIG_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/silver-config"
CONFIG_FILENAME = "silver.toml"
# silver reads its secp256k1 key, hex, from this file in its data dir.
NODE_KEY_FILENAME = "node.key"

# silver serves `/metrics` from the beacon API's own binds, so there is no
# second port to publish.
METRICS_PATH = "/metrics"

# Full custody: 128 groups is every group there is
# (`NUMBER_OF_CUSTODY_GROUPS`), and silver floors any lower value at
# `SAMPLES_PER_SLOT` (8) when it builds its ENR.
SUPERNODE_CUSTODY_GROUP_COUNT = 128
DEFAULT_CUSTODY_GROUP_COUNT = 8

# silver takes no `--log-level`: `RUST_LOG` carries both the level and the
# per-module filters, and the tracing subscriber reads it directly.
RUST_LOG_LEVELS = {
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
    if network_params.preset != "mainnet":
        fail("silver supports only the mainnet preset")

    log_level = input_parser.get_client_log_level_or_default(
        participant.cl_log_level, global_log_level, RUST_LOG_LEVELS
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
        # Not `cl_shared.get_general_cl_public_port_specs`: it publishes a
        # `metrics` port, and Kurtosis rejects a public port with no private
        # port of the same id behind it.
        public_ports = shared_utils.get_port_specs(
            {
                constants.UDP_DISCOVERY_PORT_ID: public_ports_for_component[0],
                constants.HTTP_PORT_ID: public_ports_for_component[1],
                constants.QUIC_DISCOVERY_PORT_ID: public_ports_for_component[3],
            }
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

    # No `tcp-discovery` and no `metrics`: silver reaches peers over discv5 and
    # QUIC, both UDP, and serves `/metrics` from the beacon API's own port. A
    # declared TCP port Kurtosis then waits to see opened would never open.
    used_port_assignments = {
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.QUIC_DISCOVERY_PORT_ID: discovery_port_quic,
        constants.HTTP_PORT_ID: BEACON_HTTP_PORT_NUM,
    }

    # Disable port checks if skip_start is enabled
    if participant.skip_start:
        used_ports = shared_utils.get_port_specs(used_port_assignments, wait=None)
    else:
        # Silver opens its ports after genesis.
        used_ports = shared_utils.get_port_specs(
            used_port_assignments,
            wait="{0}s".format(network_params.genesis_delay + 120),
        )

    config_artifact = render_config(
        plan,
        beacon_service_name,
        participant,
        discovery_port,
        discovery_port_quic,
        EXECUTION_ENGINE_ENDPOINT,
        el_context,
        bootnode_contexts,
        bootnode_enr_override,
        network_params,
        checkpoint_sync_enabled,
        checkpoint_sync_url,
    )

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        CONFIG_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: config_artifact,
    }
    if el_context != None:
        files[constants.JWT_MOUNTPOINT_ON_CLIENTS] = launcher.jwt_file

    node_key_path = None
    if network_params.perfect_peerdas_enabled and participant_index < 16:
        files[constants.NODE_KEY_MOUNTPOINT_ON_CLIENTS] = Directory(
            artifact_names=["node-key-file-{0}".format(participant_index + 1)]
        )
        node_key_path = shared_utils.path_join(
            constants.NODE_KEY_MOUNTPOINT_ON_CLIENTS,
            "node-key-file-{0}".format(participant_index + 1),
        )

    if persistent:
        files[
            BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER
        ] = cl_shared.get_beacon_data_directory(
            beacon_service_name,
            participant,
            network_params,
            constants.CL_TYPE.silver,
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
        {"RUST_LOG": log_level} | participant.cl_extra_env_vars,
        otel_otlp_grpc_url,
        beacon_service_name,
    )

    config_path = shared_utils.path_join(
        CONFIG_MOUNT_DIRPATH_ON_SERVICE_CONTAINER, CONFIG_FILENAME
    )
    external_ip = (
        "${K8S_POD_IP}" if backend == "kubernetes" else port_publisher.cl_nat_exit_ip
    )
    cmd = ["silver", "--config", "/tmp/" + CONFIG_FILENAME]

    if len(participant.cl_extra_params) > 0:
        cmd.extend([param for param in participant.cl_extra_params])

    config_args = {
        "image": participant.cl_image,
        # Flux queues and profiling exceed Docker's 64 MiB shared-memory default.
        "gpu": GpuConfig(count=0, shm_size=2048),
        # silver's storage needs io_uring, which Docker's default seccomp
        # profile blocks. Runs with silver need `kurtosis run --privileged`.
        "privileged": True,
        "ports": used_ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.cl_enabled,
        "entrypoint": ["sh", "-c"],
        "cmd": [
            start_command(
                cmd, config_path, external_ip, node_key_path, cl_binary_artifact
            )
        ],
        "files": files,
        "env_vars": env_vars,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "labels": shared_utils.label_maker(
            client=constants.CL_TYPE.silver,
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
    if not participant.skip_start:
        config_args["ready_conditions"] = cl_node_ready_conditions.get_ready_conditions(
            constants.HTTP_PORT_ID
        )

    cl_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)


def render_config(
    plan,
    beacon_service_name,
    participant,
    discovery_port,
    discovery_port_quic,
    execution_engine_endpoint,
    el_context,
    bootnode_contexts,
    bootnode_enr_override,
    network_params,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
):
    if network_params.network in constants.PUBLIC_NETWORKS:
        network = network_params.network
    else:
        network = constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
    bootstrap_enrs = bootstrap_enrs_override(
        network_params, bootnode_contexts, bootnode_enr_override
    )
    template_data = {
        "Network": network,
        "ServiceName": beacon_service_name,
        # Lighthouse likewise skips the check only when syncing from genesis.
        "DisableWsCheck": "false" if checkpoint_sync_enabled else "true",
        "CheckpointSyncUrl": checkpoint_sync_url if checkpoint_sync_enabled else "",
        "FeeRecipient": constants.VALIDATING_REWARDS_ACCOUNT
        if el_context != None
        else "",
        "DiscoveryPort": discovery_port,
        "QuicPort": discovery_port_quic,
        "HttpPort": BEACON_HTTP_PORT_NUM,
        "CustodyGroupCount": SUPERNODE_CUSTODY_GROUP_COUNT
        if participant.supernode
        else DEFAULT_CUSTODY_GROUP_COUNT,
        "DataDir": BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER,
        "ExecutionEndpoint": execution_engine_endpoint
        if el_context != None
        else "http://127.0.0.1:8551",
        "JwtSecret": constants.JWT_MOUNT_PATH_ON_CONTAINER,
        # No EL means nothing can answer newPayload, so the engine tile has to
        # rule every payload VALID by itself.
        "UnsafeNoEl": "true" if el_context == None else "false",
        "OverrideBootstrapEnrs": bootstrap_enrs != None,
        "BootstrapEnrs": bootstrap_enrs or [],
    }

    template = read_file(static_files.SILVER_CONFIG_TEMPLATE_FILEPATH)
    return plan.render_templates(
        {
            CONFIG_FILENAME: shared_utils.new_template_and_data(
                template, template_data
            ),
        },
        "{0}-config".format(beacon_service_name),
    )


# silver dials ENRs only — it speaks QUIC, and a multiaddr carries no QUIC
# port or custody-group count for it to read. None leaves silver its own list:
# the bundled one on a public network, `bootstrap_nodes.yaml` on a devnet.
def bootstrap_enrs_override(network_params, bootnode_contexts, bootnode_enr_override):
    if bootnode_enr_override != None:
        return [bootnode_enr_override]
    if (
        network_params.network != constants.NETWORK_NAME.kurtosis
        and constants.NETWORK_NAME.shadowfork not in network_params.network
    ):
        return None
    if bootnode_contexts == None:
        return []
    return [
        ctx.enr for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES] if ctx.enr
    ]


# A rendered artifact predates the service that gets the address, so the
# config carries a placeholder and the container substitutes it on the way in.
# silver publishes no QUIC address in its ENR without it, and then no peer can
# dial it back.
def start_command(cmd, config_path, external_ip, node_key_path, cl_binary_artifact):
    prelude = [
        'sed "s/EXTERNAL_IP/'
        + external_ip
        + '/" '
        + config_path
        + " > /tmp/"
        + CONFIG_FILENAME,
    ]
    if node_key_path != None:
        prelude.append("mkdir -p " + BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER)
        prelude.append(
            "cp {0} {1}".format(
                node_key_path,
                shared_utils.path_join(
                    BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER, NODE_KEY_FILENAME
                ),
            )
        )
    if cl_binary_artifact != None:
        prelude.append(
            "cp /opt/bin/{0} /usr/local/bin/silver".format(cl_binary_artifact.filename)
        )
    return " && ".join(prelude + ["exec " + " ".join(cmd)])


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

    (
        beacon_node_enr,
        beacon_multiaddr,
        beacon_peer_id,
    ) = cl_shared.get_beacon_node_identity(plan, service_name, participant)

    # silver publishes `/metrics` on the beacon API's port, so prometheus
    # scrapes the one port this service listens on.
    beacon_metrics_url = "{0}:{1}".format(service.ip_address, beacon_http_port.number)
    nodes_metrics_info = [
        node_metrics.new_node_metrics_info(
            service_name, METRICS_PATH, beacon_metrics_url
        ),
    ]
    return cl_context.new_cl_context(
        client_name="silver",
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


def new_silver_launcher(el_cl_genesis_data, jwt_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
    )
