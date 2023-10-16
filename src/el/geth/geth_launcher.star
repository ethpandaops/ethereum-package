shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/parse_input.star")
el_client_context = import_module("../../el/el_client_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
genesis_constants = import_module(
    "../../prelaunch_data_generator/genesis_constants/genesis_constants.star"
)

node_metrics = import_module("../../node_metrics_info.star")
package_io = import_module("../../package_io/constants.star")

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
ENGINE_WS_PORT_ID = "engineWs"
METRICS_PORT_ID = "metrics"

# TODO(old) Scale this dynamically based on CPUs available and Geth nodes mining
NUM_MINING_THREADS = 1

METRICS_PATH = "/debug/metrics/prometheus"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/execution-data"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
    RPC_PORT_ID: shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
    # WS_PORT_ID: shared_utils.new_port_spec(WS_PORT_NUM, shared_utils.TCP_PROTOCOL),
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
    package_io.GLOBAL_CLIENT_LOG_LEVEL.error: "1",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.warn: "2",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.info: "3",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.debug: "4",
    package_io.GLOBAL_CLIENT_LOG_LEVEL.trace: "5",
}

BUILDER_IMAGE_STR = "builder"


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
        launcher.electra_fork_epoch,
    )

    service = plan.add_service(service_name, config)

    enode, enr = el_admin_node_info.get_enode_enr_for_node(
        plan, service_name, RPC_PORT_ID
    )

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    geth_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    return el_client_context.new_el_client_context(
        "geth",
        enr,
        enode,
        service.ip_address,
        RPC_PORT_NUM,
        WS_PORT_NUM,
        ENGINE_RPC_PORT_NUM,
        service_name,
        [geth_metrics_info],
    )


def get_config(
    network_id,
    el_cl_genesis_data,
    image,
    existing_el_clients,
    verbosity_level,
    el_min_cpu,
    el_max_cpu,
    el_min_mem,
    el_max_mem,
    extra_params,
    extra_env_vars,
    electra_fork_epoch,
):
    init_datadir_cmd_str = "geth init {0} --state.scheme=path --datadir={1} {2}".format(
        "--cache.preimages" if electra_fork_epoch != None else "",
        EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        package_io.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.json",
    )

    cmd = [
        "geth",
        "--state.scheme=path",
        "--verbosity=" + verbosity_level,
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--networkid=" + network_id,
        "--http",
        "--http.addr=0.0.0.0",
        "--http.vhosts=*",
        "--http.corsdomain=*",
        # WARNING: The admin info endpoint is enabled so that we can easily get ENR/enode, which means
        #  that users should NOT store private information in these Kurtosis nodes!
        "--http.api=admin,engine,net,eth,web3,debug",
        "--ws",
        "--ws.addr=0.0.0.0",
        "--ws.port={0}".format(WS_PORT_NUM),
        "--ws.api=admin,engine,net,eth,web3,debug",
        "--ws.origins=*",
        "--allow-insecure-unlock",
        "--nat=extip:" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--verbosity=" + verbosity_level,
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.addr=0.0.0.0",
        "--authrpc.vhosts=*",
        "--authrpc.jwtsecret=" + package_io.JWT_AUTH_PATH,
        "--syncmode=full",
        "--rpc.allow-unprotected-txs",
        "--metrics",
        "--metrics.addr=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
    ]

    if BUILDER_IMAGE_STR in image:
        cmd[10] = "--http.api=admin,engine,net,eth,web3,debug,flashbots"
        cmd[14] = "--ws.api=admin,engine,net,eth,web3,debug,flashbots"

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

    return ServiceConfig(
        image=image,
        ports=USED_PORTS,
        cmd=[command_str],
        files={
            package_io.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid
        },
        entrypoint=ENTRYPOINT_ARGS,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=el_min_cpu,
        max_cpu=el_max_cpu,
        min_memory=el_min_mem,
        max_memory=el_max_mem,
        env_vars=extra_env_vars,
    )


def new_geth_launcher(
    network_id,
    el_cl_genesis_data,
    electra_fork_epoch=None,
):
    return struct(
        network_id=network_id,
        el_cl_genesis_data=el_cl_genesis_data,
        electra_fork_epoch=electra_fork_epoch,
    )
