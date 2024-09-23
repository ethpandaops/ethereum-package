shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../..//package_io/input_parser.star")
el_context = import_module("../../el/el_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
el_shared = import_module("../el_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
WS_PORT_ENGINE_NUM = 8547
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

METRICS_PATH = "/metrics"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/ethereumjs/execution-data"

ENTRYPOINT_ARGS = []

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
    tolerations,
    node_selectors,
    port_publisher,
    participant_index,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
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
        node_selectors,
        port_publisher,
        participant_index,
    )

    service = plan.add_service(service_name, config)

    enode = el_admin_node_info.get_enode_for_node(
        plan, service_name, constants.RPC_PORT_ID
    )

    # TODO: Passing empty string for metrics_url for now https://github.com/ethpandaops/ethereum-package/issues/127
    # metrics_url = "http://{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    ethjs_metrics_info = None

    http_url = "http://{0}:{1}".format(service.ip_address, RPC_PORT_NUM)
    ws_url = "ws://{0}:{1}".format(service.ip_address, WS_PORT_NUM)

    return el_context.new_el_context(
        client_name="ethereumjs",
        enode=enode,
        ip_addr=service.ip_address,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        rpc_http_url=http_url,
        ws_url=ws_url,
        service_name=service_name,
        el_metrics_info=[ethjs_metrics_info],
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
    node_selectors,
    port_publisher,
    participant_index,
):
    public_ports = {}
    discovery_port = DISCOVERY_PORT_NUM
    if port_publisher.el_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "el", port_publisher, participant_index
        )
        public_ports, discovery_port = el_shared.get_general_el_public_port_specs(
            public_ports_for_component
        )
        additional_public_port_assignments = {
            constants.RPC_PORT_ID: public_ports_for_component[2],
            constants.WS_PORT_ID: public_ports_for_component[3],
            constants.ENGINE_WS_PORT_ID: public_ports_for_component[4],
        }
        public_ports.update(
            shared_utils.get_port_specs(additional_public_port_assignments)
        )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.ENGINE_RPC_PORT_ID: ENGINE_RPC_PORT_NUM,
        constants.RPC_PORT_ID: RPC_PORT_NUM,
        constants.WS_PORT_ID: WS_PORT_NUM,
        constants.ENGINE_WS_PORT_ID: WS_PORT_ENGINE_NUM,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "--dataDir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--port={0}".format(discovery_port),
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
        "--extIP={0}".format(port_publisher.nat_exit_ip),
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
    elif (
        network not in constants.PUBLIC_NETWORKS
        and constants.NETWORK_NAME.shadowfork not in network
    ):
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

    config_args = {
        "image": image,
        "ports": used_ports,
        "public_ports": public_ports,
        "cmd": cmd,
        "files": files,
        "entrypoint": ENTRYPOINT_ARGS,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": extra_env_vars,
        "labels": shared_utils.label_maker(
            constants.EL_TYPE.ethereumjs,
            constants.CLIENT_TYPES.el,
            image,
            cl_client_name,
            extra_labels,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if el_min_cpu > 0:
        config_args["min_cpu"] = el_min_cpu
    if el_max_cpu > 0:
        config_args["max_cpu"] = el_max_cpu
    if el_min_mem > 0:
        config_args["min_memory"] = el_min_mem
    if el_max_mem > 0:
        config_args["max_memory"] = el_max_mem
    return ServiceConfig(**config_args)


def new_ethereumjs_launcher(el_cl_genesis_data, jwt_file, network):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
    )
