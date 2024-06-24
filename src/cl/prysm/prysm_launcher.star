shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
node_metrics = import_module("../../node_metrics_info.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
constants = import_module("../../package_io/constants.star")

#  ---------------------------------- Beacon client -------------------------------------
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/prysm/beacon-data/"

# Port IDs
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
RPC_PORT_ID = "rpc"
BEACON_HTTP_PORT_ID = "http"
BEACON_MONITORING_PORT_ID = "monitoring"

# Port nums
DISCOVERY_TCP_PORT_NUM = 13000
DISCOVERY_UDP_PORT_NUM = 12000
RPC_PORT_NUM = 4000
HTTP_PORT_NUM = 3500
BEACON_MONITORING_PORT_NUM = 8080

# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 100
BEACON_MIN_MEMORY = 256

METRICS_PATH = "/metrics"


MIN_PEERS = 1


def get_used_ports(discovery_port):
    used_ports = {
        TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port, shared_utils.TCP_PROTOCOL
        ),
        UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port, shared_utils.UDP_PROTOCOL
        ),
        RPC_PORT_ID: shared_utils.new_port_spec(
            RPC_PORT_NUM, shared_utils.TCP_PROTOCOL
        ),
        BEACON_HTTP_PORT_ID: shared_utils.new_port_spec(
            HTTP_PORT_NUM, shared_utils.TCP_PROTOCOL
        ),
        BEACON_MONITORING_PORT_ID: shared_utils.new_port_spec(
            BEACON_MONITORING_PORT_NUM, shared_utils.TCP_PROTOCOL
        ),
    }
    return used_ports


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
    cl_tolerations,
    participant_tolerations,
    global_tolerations,
    node_selectors,
    use_separate_vc,
    keymanager_enabled,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
):
    beacon_service_name = "{0}".format(service_name)
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )

    tolerations = input_parser.get_client_tolerations(
        cl_tolerations, participant_tolerations, global_tolerations
    )

    network_name = shared_utils.get_network_name(launcher.network)

    cl_min_cpu = int(cl_min_cpu) if int(cl_min_cpu) > 0 else BEACON_MIN_CPU
    cl_max_cpu = (
        int(cl_max_cpu)
        if int(cl_max_cpu) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["prysm_max_cpu"]
    )
    cl_min_mem = int(cl_min_mem) if int(cl_min_mem) > 0 else BEACON_MIN_MEMORY
    cl_max_mem = (
        int(cl_max_mem)
        if int(cl_max_mem) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["prysm_max_mem"]
    )

    cl_volume_size = (
        int(cl_volume_size)
        if int(cl_volume_size) > 0
        else constants.VOLUME_SIZE[network_name]["prysm_volume_size"]
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
    )

    beacon_service = plan.add_service(beacon_service_name, beacon_config)

    beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]

    beacon_http_url = "http://{0}:{1}".format(beacon_service.ip_address, HTTP_PORT_NUM)
    beacon_grpc_url = "{0}:{1}".format(beacon_service.ip_address, RPC_PORT_NUM)

    # TODO(old) add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module
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
        recipe=beacon_node_identity_recipe, service_name=beacon_service_name
    )
    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    beacon_metrics_port = beacon_service.ports[BEACON_MONITORING_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(
        beacon_service.ip_address, beacon_metrics_port.number
    )
    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        beacon_service_name, METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    return cl_context.new_cl_context(
        "prysm",
        beacon_node_enr,
        beacon_service.ip_address,
        beacon_http_port.number,
        beacon_http_url,
        nodes_metrics_info,
        beacon_service_name,
        beacon_grpc_url,
        beacon_multiaddr,
        beacon_peer_id,
        snooper_enabled,
        snooper_engine_context,
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
    if port_publisher.public_port_start:
        discovery_port = port_publisher.cl_start
        if bootnode_contexts and len(bootnode_contexts) > 0:
            discovery_port = discovery_port + len(bootnode_contexts)
        public_ports = {
            TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
                discovery_port, shared_utils.TCP_PROTOCOL
            ),
            UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
                discovery_port, shared_utils.UDP_PROTOCOL
            ),
        }
    used_ports = get_used_ports(discovery_port)

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
        # Set per Pari's recommendation to reduce noise
        "--subscribe-all-subnets=true",
        "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--enable-debug-rpc-endpoints=true",
        # vvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(BEACON_MONITORING_PORT_NUM)
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    # If checkpoint sync is enabled, add the checkpoint sync url
    if checkpoint_sync_enabled:
        if checkpoint_sync_url:
            cmd.append("--checkpoint-sync-url=" + checkpoint_sync_url)
        else:
            if network in ["mainnet", "ephemery"]:
                cmd.append(
                    "--checkpoint-sync-url=" + constants.CHECKPOINT_SYNC_URL[network]
                )
                cmd.append(
                    "--genesis-beacon-api-url=" + constants.CHECKPOINT_SYNC_URL[network]
                )
            else:
                cmd.append(
                    "--checkpoint-sync-url=https://checkpoint-sync.{0}.ethpandaops.io".format(
                        network
                    )
                )
                cmd.append(
                    "--genesis-beacon-api-url=https://checkpoint-sync.{0}.ethpandaops.io".format(
                        network
                    )
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

    return ServiceConfig(
        image=beacon_image,
        ports=used_ports,
        public_ports=public_ports,
        cmd=cmd,
        env_vars=extra_env_vars,
        files=files,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ready_conditions=cl_node_ready_conditions.get_ready_conditions(
            BEACON_HTTP_PORT_ID
        ),
        min_cpu=cl_min_cpu,
        max_cpu=cl_max_cpu,
        min_memory=cl_min_mem,
        max_memory=cl_max_mem,
        labels=shared_utils.label_maker(
            constants.CL_TYPE.prysm,
            constants.CLIENT_TYPES.cl,
            beacon_image,
            el_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )


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
