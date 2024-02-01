shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../..//package_io/input_parser.star")
el_client_context = import_module("../../el/el_client_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")

node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
WS_PORT_ENGINE_NUM = 8547
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 100
EXECUTION_MIN_MEMORY = 256

# Port IDs
RPC_PORT_ID = "rpc"
WS_PORT_ID = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID = "engine-rpc"
WS_PORT_ENGINE_ID = "ws-engine"
METRICS_PORT_ID = "metrics"
METRICS_PATH = "/metrics"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/ethereumjs/execution-data"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
    RPC_PORT_ID: shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
    WS_PORT_ID: shared_utils.new_port_spec(WS_PORT_NUM, shared_utils.TCP_PROTOCOL),
    WS_PORT_ENGINE_ID: shared_utils.new_port_spec(
        WS_PORT_ENGINE_NUM, shared_utils.TCP_PROTOCOL
    ),
    TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL
    ),
    ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(
        ENGINE_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    # METRICS_PORT_ID: shared_utils.new_port_spec(METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL)
}

ENTRYPOINT_ARGS = []

VERBOSITY_LEVELS = {
    constants.GLOBAL_CLIENT_LOG_LEVEL.error: "error",
    constants.GLOBAL_CLIENT_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_CLIENT_LOG_LEVEL.info: "info",
    constants.GLOBAL_CLIENT_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_CLIENT_LOG_LEVEL.trace: "trace",
}


def launch(
    plan,
    launcher,
    service_name,
    image,
    participant_log_level,
    global_log_level,
    existing_el_clients,
    el_min_cpu,
    el_max_cpu,
    el_min_mem,
    el_max_mem,
    extra_params,
    extra_env_vars,
    extra_labels,
    persistent,
    el_volume_size,
    el_tolerations,
    participant_tolerations,
    global_tolerations,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )
    tolerations = input_parser.get_client_tolerations(
        el_tolerations, participant_tolerations, global_tolerations
    )

    network_name = (
        "devnets"
        if launcher.network != "kurtosis"
        and launcher.network != "ephemery"
        and launcher.network not in constants.PUBLIC_NETWORKS
        else launcher.network
    )

    el_min_cpu = int(el_min_cpu) if int(el_min_cpu) > 0 else EXECUTION_MIN_CPU
    el_max_cpu = (
        int(el_max_cpu)
        if int(el_max_cpu) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["ethereumjs_max_cpu"]
    )
    el_min_mem = int(el_min_mem) if int(el_min_mem) > 0 else EXECUTION_MIN_MEMORY
    el_max_mem = (
        int(el_max_mem)
        if int(el_max_mem) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["ethereumjs_max_mem"]
    )

    el_volume_size = (
        el_volume_size
        if int(el_volume_size) > 0
        else constants.VOLUME_SIZE[network_name]["ethereumjs_volume_size"]
    )

    cl_client_name = service_name.split("-")[3]

    config = get_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        launcher.network,
        image,
        service_name,
        existing_el_clients,
        cl_client_name,
        log_level,
        el_min_cpu,
        el_max_cpu,
        el_min_mem,
        el_max_mem,
        extra_params,
        extra_env_vars,
        extra_labels,
        persistent,
        el_volume_size,
        tolerations,
    )

    service = plan.add_service(service_name, config)

    enode = el_admin_node_info.get_enode_for_node(plan, service_name, RPC_PORT_ID)

    # TODO: Passing empty string for metrics_url for now https://github.com/kurtosis-tech/ethereum-package/issues/127
    # metrics_url = "http://{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    ethjs_metrics_info = None

    return el_client_context.new_el_client_context(
        "ethereumjs",
        "",  # ethereumjs has no enr
        enode,
        service.ip_address,
        RPC_PORT_NUM,
        WS_PORT_NUM,
        ENGINE_RPC_PORT_NUM,
        service_name,
        [ethjs_metrics_info],
    )


def get_config(
    plan,
    el_cl_genesis_data,
    jwt_file,
    network,
    image,
    service_name,
    existing_el_clients,
    cl_client_name,
    verbosity_level,
    el_min_cpu,
    el_max_cpu,
    el_min_mem,
    el_max_mem,
    extra_params,
    extra_env_vars,
    extra_labels,
    persistent,
    el_volume_size,
    tolerations,
):
    cmd = [
        "--dataDir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--port={0}".format(DISCOVERY_PORT_NUM),
        "--rpc",
        "--rpcAddr=0.0.0.0",
        "--rpcPort={0}".format(RPC_PORT_NUM),
        "--rpcCors=*",
        "--rpcEngine",
        "--rpcEngineAddr=0.0.0.0",
        "--rpcEnginePort={0}".format(ENGINE_RPC_PORT_NUM),
        "--ws",
        "--wsAddr=0.0.0.0",
        "--wsPort={0}".format(WS_PORT_NUM),
        "--wsEnginePort={0}".format(WS_PORT_ENGINE_NUM),
        "--wsEngineAddr=0.0.0.0",
        "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--extIP={0}".format(PRIVATE_IP_ADDRESS_PLACEHOLDER),
        "--sync=full",
        "--isSingleNode=true",
        "--logLevel={0}".format(verbosity_level),
    ]

    if network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--gethGenesis="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis.json",
        )
    else:
        cmd.append("--network=" + network)

    if network == constants.NETWORK_NAME.kurtosis:
        if len(existing_el_clients) > 0:
            cmd.append(
                "--bootnodes="
                + ",".join(
                    [
                        ctx.enode
                        for ctx in existing_el_clients[: constants.MAX_ENODE_ENTRIES]
                    ]
                )
            )
    elif network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--bootnodes="
            + shared_utils.get_devnet_enodes(
                plan, el_cl_genesis_data.files_artifact_uuid
            )
        )

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    if persistent:
        files[EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=el_volume_size,
        )
    return ServiceConfig(
        image=image,
        ports=USED_PORTS,
        cmd=cmd,
        files=files,
        entrypoint=ENTRYPOINT_ARGS,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=el_min_cpu,
        max_cpu=el_max_cpu,
        min_memory=el_min_mem,
        max_memory=el_max_mem,
        env_vars=extra_env_vars,
        labels=shared_utils.label_maker(
            constants.EL_CLIENT_TYPE.ethereumjs,
            constants.CLIENT_TYPES.el,
            image,
            cl_client_name,
            extra_labels,
        ),
        tolerations=tolerations,
    )


def new_ethereumjs_launcher(el_cl_genesis_data, jwt_file, network):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
    )
