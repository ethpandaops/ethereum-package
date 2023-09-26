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


RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 100
EXECUTION_MAX_CPU = 1000
EXECUTION_MIN_MEMORY = 256
EXECUTION_MAX_MEMORY = 1024

# Port IDs
RPC_PORT_ID = "rpc"
WS_PORT_ID = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID = "engine-rpc"
METRICS_PORT_ID = "metrics"

# Paths
METRICS_PATH = "/metrics"
GENESIS_DATA_MOUNT_DIRPATH = "/genesis"
PREFUNDED_KEYS_MOUNT_DIRPATH = "/prefunded-keys"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/execution-data"

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

ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    package_io.GLOBAL_CLIENT_LOG_LEVEL.error: "v",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.warn: "vv",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.info: "vvv",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.debug: "vvvv",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.trace: "vvvvv",
}


def launch(
    plan,
    launcher,
    service_name,
    image,
    participant_log_level,
    global_log_level,
    # If empty then the node will be launched as a bootnode
    existing_el_clients,
    el_min_cpu,
    el_max_cpu,
    el_min_mem,
    el_max_mem,
    extra_params,
    extra_env_vars,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
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

    metric_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    reth_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metric_url
    )

    return el_client_context.new_el_client_context(
        "reth",
        "",  # reth has no enr
        enode,
        service.ip_address,
        RPC_PORT_NUM,
        WS_PORT_NUM,
        ENGINE_RPC_PORT_NUM,
        jwt_secret,
        service_name,
        [reth_metrics_info],
    )


def get_config(
    genesis_data,
    image,
    existing_el_clients,
    verbosity_level,
    el_min_cpu,
    el_max_cpu,
    el_min_mem,
    el_max_mem,
    extra_params,
    extra_env_vars,
):
    genesis_json_filepath_on_client = shared_utils.path_join(
        GENESIS_DATA_MOUNT_DIRPATH, genesis_data.geth_genesis_json_relative_filepath
    )
    jwt_secret_json_filepath_on_client = shared_utils.path_join(
        GENESIS_DATA_MOUNT_DIRPATH, genesis_data.jwt_secret_relative_filepath
    )

    init_datadir_cmd_str = "reth init --datadir={0} --chain={1}".format(
        EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        genesis_json_filepath_on_client,
    )

    cmd = [
        "reth",
        "node",
        "-{0}".format(verbosity_level),
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--chain=" + genesis_json_filepath_on_client,
        "--http",
        "--http.port={0}".format(RPC_PORT_NUM),
        "--http.addr=0.0.0.0",
        "--http.corsdomain=*",
        # WARNING: The admin info endpoint is enabled so that we can easily get ENR/enode, which means
        #  that users should NOT store private information in these Kurtosis nodes!
        "--http.api=admin,net,eth",
        "--ws",
        "--ws.addr=0.0.0.0",
        "--ws.port={0}".format(WS_PORT_NUM),
        "--ws.api=net,eth",
        "--ws.origins=*",
        "--nat=extip:" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.jwtsecret={0}".format(jwt_secret_json_filepath_on_client),
        "--authrpc.addr=0.0.0.0",
        "--metrics=0.0.0.0:{0}".format(METRICS_PORT_NUM),
    ]

    if len(existing_el_clients) > 0:
        cmd.append(
            "--bootnodes="
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

    cmd_str = " ".join(cmd)

    subcommand_strs = [
        init_datadir_cmd_str,
        cmd_str,
    ]
    command_str = " && ".join(subcommand_strs)

    return (
        ServiceConfig(
            image=image,
            ports=USED_PORTS,
            cmd=[command_str],
            files={
                GENESIS_DATA_MOUNT_DIRPATH: genesis_data.files_artifact_uuid,
            },
            entrypoint=ENTRYPOINT_ARGS,
            private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
            min_cpu=el_min_cpu,
            max_cpu=el_max_cpu,
            min_memory=el_min_mem,
            max_memory=el_max_mem,
            env_vars=extra_env_vars,
        ),
        jwt_secret_json_filepath_on_client,
    )


def new_reth_launcher(el_genesis_data):
    return struct(
        el_genesis_data=el_genesis_data,
    )
