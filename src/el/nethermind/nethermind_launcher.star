shared_utils = import_module(
    "github.com/kurtosis-tech/eth-network-package/shared_utils/shared_utils.star"
)
input_parser = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/input_parser.star"
)
el_client_context = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/el_client_context.star"
)
el_admin_node_info = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/el/el_admin_node_info.star"
)

node_metrics = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/node_metrics_info.star"
)
package_io = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/constants.star"
)

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/execution-data"
KZG_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/genesis/output/trusted_setup.txt"
GENESIS_DATA_MOUNT_DIRPATH = "/genesis"

METRICS_PATH = "/metrics"

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
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
ENGINE_RPC_PORT_ID = "engine-rpc"
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
    ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(
        ENGINE_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    METRICS_PORT_ID: shared_utils.new_port_spec(
        METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}

NETHERMIND_LOG_LEVELS = {
    package_io.GLOBAL_CLIENT_LOG_LEVEL.error: "ERROR",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.warn: "WARN",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.info: "INFO",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.debug: "DEBUG",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.trace: "TRACE",
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
        participant_log_level, global_log_level, NETHERMIND_LOG_LEVELS
    )

    el_min_cpu = el_min_cpu if int(el_min_cpu) > 0 else EXECUTION_MIN_CPU
    el_max_cpu = el_max_cpu if int(el_max_cpu) > 0 else EXECUTION_MAX_CPU
    el_min_mem = el_min_mem if int(el_min_mem) > 0 else EXECUTION_MIN_MEMORY
    el_max_mem = el_max_mem if int(el_max_mem) > 0 else EXECUTION_MAX_MEMORY

    config, jwt_secret_json_filepath_on_client = get_config(
        launcher.el_genesis_data,
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

    jwt_secret = shared_utils.read_file_from_service(
        plan, service_name, jwt_secret_json_filepath_on_client
    )

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    nethermind_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    return el_client_context.new_el_client_context(
        "nethermind",
        "",  # nethermind has no ENR in the eth2-merge-kurtosis-module either
        # Nethermind node info endpoint doesn't return ENR field https://docs.nethermind.io/nethermind/ethereum-client/json-rpc/admin
        enode,
        service.ip_address,
        RPC_PORT_NUM,
        WS_PORT_NUM,
        ENGINE_RPC_PORT_NUM,
        jwt_secret,
        service_name,
        [nethermind_metrics_info],
    )


def get_config(
    genesis_data,
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
    genesis_json_filepath_on_client = shared_utils.path_join(
        GENESIS_DATA_MOUNT_DIRPATH,
        genesis_data.nethermind_genesis_json_relative_filepath,
    )
    jwt_secret_json_filepath_on_client = shared_utils.path_join(
        GENESIS_DATA_MOUNT_DIRPATH, genesis_data.jwt_secret_relative_filepath
    )

    cmd = [
        "--log=" + log_level,
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--Init.ChainSpecPath=" + genesis_json_filepath_on_client,
        "--Init.WebSocketsEnabled=true",
        "--Init.KzgSetupPath=" + KZG_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--config=none.cfg",
        "--JsonRpc.Enabled=true",
        "--JsonRpc.EnabledModules=net,eth,consensus,subscribe,web3,admin",
        "--JsonRpc.Host=0.0.0.0",
        "--JsonRpc.Port={0}".format(RPC_PORT_NUM),
        "--JsonRpc.WebSocketsPort={0}".format(WS_PORT_NUM),
        "--JsonRpc.EngineHost=0.0.0.0",
        "--JsonRpc.EnginePort={0}".format(ENGINE_RPC_PORT_NUM),
        "--Network.ExternalIp={0}".format(PRIVATE_IP_ADDRESS_PLACEHOLDER),
        "--Network.DiscoveryPort={0}".format(DISCOVERY_PORT_NUM),
        "--Network.P2PPort={0}".format(DISCOVERY_PORT_NUM),
        "--JsonRpc.JwtSecretFile={0}".format(jwt_secret_json_filepath_on_client),
        "--Network.OnlyStaticPeers=true",
        "--Metrics.Enabled=true",
        "--Metrics.ExposePort={0}".format(METRICS_PORT_NUM),
    ]

    if len(existing_el_clients) > 0:
        cmd.append(
            "--Network.StaticPeers="
            + ",".join(
                [
                    ctx.enode
                    for ctx in existing_el_clients[: package_io.MAX_ENODE_ENTRIES]
                ]
            )
        )

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    return (
        ServiceConfig(
            image=image,
            ports=USED_PORTS,
            cmd=cmd,
            files={
                GENESIS_DATA_MOUNT_DIRPATH: genesis_data.files_artifact_uuid,
            },
            private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
            min_cpu=el_min_cpu,
            max_cpu=el_max_cpu,
            min_memory=el_min_mem,
            max_memory=el_max_mem,
            env_vars=extra_env_vars,
        ),
        jwt_secret_json_filepath_on_client,
    )


def new_nethermind_launcher(el_genesis_data):
    return struct(el_genesis_data=el_genesis_data)
