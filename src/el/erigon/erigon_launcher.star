shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
el_client_context = import_module("../../el/el_client_context.star")

node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/home/erigon/execution-data"

METRICS_PATH = "/metrics"

WS_RPC_PORT_NUM = 8545
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 100
EXECUTION_MAX_CPU = 1000
EXECUTION_MIN_MEMORY = 512
EXECUTION_MAX_MEMORY = 2048

# Port IDs
WS_RPC_PORT_ID = "ws-rpc"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID = "engine-rpc"
METRICS_PORT_ID = "metrics"


PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
    WS_RPC_PORT_ID: shared_utils.new_port_spec(
        WS_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL
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
    METRICS_PORT_ID: shared_utils.new_port_spec(
        METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}

ENTRYPOINT_ARGS = ["sh", "-c"]

ERIGON_LOG_LEVELS = {
    constants.GLOBAL_CLIENT_LOG_LEVEL.error: "1",
    constants.GLOBAL_CLIENT_LOG_LEVEL.warn: "2",
    constants.GLOBAL_CLIENT_LOG_LEVEL.info: "3",
    constants.GLOBAL_CLIENT_LOG_LEVEL.debug: "4",
    constants.GLOBAL_CLIENT_LOG_LEVEL.trace: "5",
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
):
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, ERIGON_LOG_LEVELS
    )

    el_min_cpu = el_min_cpu if int(el_min_cpu) > 0 else EXECUTION_MIN_CPU
    el_max_cpu = el_max_cpu if int(el_max_cpu) > 0 else EXECUTION_MAX_CPU
    el_min_mem = el_min_mem if int(el_min_mem) > 0 else EXECUTION_MIN_MEMORY
    el_max_mem = el_max_mem if int(el_max_mem) > 0 else EXECUTION_MAX_MEMORY

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
    )

    service = plan.add_service(service_name, config)

    enode, enr = el_admin_node_info.get_enode_enr_for_node(
        plan, service_name, WS_RPC_PORT_ID
    )

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    erigon_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    return el_client_context.new_el_client_context(
        "erigon",
        enr,
        enode,
        service.ip_address,
        WS_RPC_PORT_NUM,
        WS_RPC_PORT_NUM,
        ENGINE_RPC_PORT_NUM,
        service_name,
        [erigon_metrics_info],
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
):
    init_datadir_cmd_str = "erigon init --datadir={0} {1}".format(
        EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.json",
    )

    cmd = [
        "erigon",
        "--log.console.verbosity=" + verbosity_level,
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--port={0}".format(DISCOVERY_PORT_NUM),
        "--http.api=eth,erigon,engine,web3,net,debug,trace,txpool,admin",
        "--http.vhosts=*",
        "--ws",
        "--allow-insecure-unlock",
        "--nat=extip:" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--http",
        "--http.addr=0.0.0.0",
        "--http.corsdomain=*",
        "--http.port={0}".format(WS_RPC_PORT_NUM),
        "--authrpc.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--authrpc.addr=0.0.0.0",
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.vhosts=*",
        "--metrics",
        "--metrics.addr=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
    ]

    if network == "kurtosis":
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
            cmd.append(
                "--staticpeers="
                + ",".join(
                    [
                        ctx.enode
                        for ctx in existing_el_clients[: constants.MAX_ENODE_ENTRIES]
                    ]
                )
            )
    elif network not in constants.PUBLIC_NETWORKS:
        cmd.append("--db.size.limit=100GB")
        cmd.append(
            "--bootnodes="
            + shared_utils.get_devnet_enodes(
                plan, el_cl_genesis_data.files_artifact_uuid
            )
        )
        cmd.append(
            "--staticpeers="
            + shared_utils.get_devnet_enodes(
                plan, el_cl_genesis_data.files_artifact_uuid
            )
        )

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    if network not in constants.PUBLIC_NETWORKS:
        command_arg = [init_datadir_cmd_str, " ".join(cmd)]

        command_arg_str = " && ".join(command_arg)
    else:
        cmd.append("--chain={0}".format(network))
        cmd.append("--db.size.limit=3TB")
        command_arg = cmd
        command_arg_str = " ".join(command_arg)

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    if persistent:
        files[EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
        )
    return ServiceConfig(
        image=image,
        ports=USED_PORTS,
        cmd=[command_arg_str],
        files=files,
        entrypoint=ENTRYPOINT_ARGS,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=el_min_cpu,
        max_cpu=el_max_cpu,
        min_memory=el_min_mem,
        max_memory=el_max_mem,
        env_vars=extra_env_vars,
        labels=shared_utils.label_maker(
            constants.EL_CLIENT_TYPE.erigon,
            constants.CLIENT_TYPES.el,
            image,
            cl_client_name,
            extra_labels,
        ),
    )


def new_erigon_launcher(el_cl_genesis_data, jwt_file, network):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
    )
