shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_client_context = import_module("../../el/el_client_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/opt/besu/execution-data"

METRICS_PATH = "/metrics"

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_HTTP_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 100
EXECUTION_MAX_CPU = 1000
EXECUTION_MIN_MEMORY = 512
EXECUTION_MAX_MEMORY = 2048

# Port IDs
RPC_PORT_ID = "rpc"
WS_PORT_ID = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_HTTP_RPC_PORT_ID = "engine-rpc"
METRICS_PORT_ID = "metrics"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
    RPC_PORT_ID: shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
    WS_PORT_ID: shared_utils.new_port_spec(WS_PORT_NUM, shared_utils.TCP_PROTOCOL),
    TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL
    ),
    ENGINE_HTTP_RPC_PORT_ID: shared_utils.new_port_spec(
        ENGINE_HTTP_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    METRICS_PORT_ID: shared_utils.new_port_spec(
        METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}

ENTRYPOINT_ARGS = ["sh", "-c"]

BESU_LOG_LEVELS = {
    constants.GLOBAL_CLIENT_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_CLIENT_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_CLIENT_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_CLIENT_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_CLIENT_LOG_LEVEL.trace: "TRACE",
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
):
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, BESU_LOG_LEVELS
    )

    el_min_cpu = int(el_min_cpu) if int(el_min_cpu) > 0 else EXECUTION_MIN_CPU
    el_max_cpu = int(el_max_cpu) if int(el_max_cpu) > 0 else EXECUTION_MAX_CPU
    el_min_mem = int(el_min_mem) if int(el_min_mem) > 0 else EXECUTION_MIN_MEMORY
    el_max_mem = int(el_max_mem) if int(el_max_mem) > 0 else EXECUTION_MAX_MEMORY

    config = get_config(
        launcher.network_id,
        launcher.el_cl_genesis_data,
        image,
        existing_el_clients,
        log_level,
        el_min_cpu,
        el_max_cpu,
        el_min_mem,
        el_max_mem,
        extra_params,
        extra_env_vars,
    )

    service = plan.add_service(service_name, config)

    enode = el_admin_node_info.get_enode_for_node(plan, service_name, RPC_PORT_ID)

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    besu_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    return el_client_context.new_el_client_context(
        "besu",
        "",  # besu has no ENR
        enode,
        service.ip_address,
        RPC_PORT_NUM,
        WS_PORT_NUM,
        ENGINE_HTTP_RPC_PORT_NUM,
        service_name,
        [besu_metrics_info],
    )


def get_config(
    network_id,
    el_cl_genesis_data,
    image,
    existing_el_clients,
    log_level,
    el_min_cpu,
    el_max_cpu,
    el_min_mem,
    el_max_mem,
    extra_params,
    extra_env_vars,
):
    cmd = [
        "besu",
        "--logging=" + log_level,
        "--data-path=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--genesis-file="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/besu.json",
        "--network-id=" + network_id,
        "--host-allowlist=*",
        "--rpc-http-enabled=true",
        "--rpc-http-host=0.0.0.0",
        "--rpc-http-port={0}".format(RPC_PORT_NUM),
        "--rpc-http-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE,TRACE,WEB3",
        "--rpc-http-cors-origins=*",
        "--rpc-ws-enabled=true",
        "--rpc-ws-host=0.0.0.0",
        "--rpc-ws-port={0}".format(WS_PORT_NUM),
        "--rpc-ws-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE,TRACE,WEB3",
        "--p2p-enabled=true",
        "--p2p-host=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--p2p-port={0}".format(DISCOVERY_PORT_NUM),
        "--engine-rpc-enabled=true",
        "--engine-jwt-secret=" + constants.JWT_AUTH_PATH,
        "--engine-host-allowlist=*",
        "--engine-rpc-port={0}".format(ENGINE_HTTP_RPC_PORT_NUM),
        "--sync-mode=FULL",
        "--data-storage-format=BONSAI",
        "--kzg-trusted-setup=" + constants.KZG_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--metrics-enabled=true",
        "--metrics-host=0.0.0.0",
        "--metrics-port={0}".format(METRICS_PORT_NUM),
    ]

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

    if len(extra_params) > 0:
        # we do this as extra_params isn't a normal [] but a proto repeated array
        cmd.extend([param for param in extra_params])

    cmd_str = " ".join(cmd)

    return ServiceConfig(
        image=image,
        ports=USED_PORTS,
        cmd=[cmd_str],
        files={
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        },
        entrypoint=ENTRYPOINT_ARGS,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=el_min_cpu,
        max_cpu=el_max_cpu,
        min_memory=el_min_mem,
        max_memory=el_max_mem,
        env_vars=extra_env_vars,
    )


def new_besu_launcher(network_id, el_cl_genesis_data):
    return struct(network_id=network_id, el_cl_genesis_data=el_cl_genesis_data)
