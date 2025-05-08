shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_context = import_module("../../el/el_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
genesis_constants = import_module(
    "../../prelaunch_data_generator/genesis_constants/genesis_constants.star"
)
el_shared = import_module("../el_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

# TODO(old) Scale this dynamically based on CPUs available and Geth nodes mining
NUM_MINING_THREADS = 1

METRICS_PATH = "/debug/metrics/prometheus"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/geth/execution-data"

ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "1",
    constants.GLOBAL_LOG_LEVEL.warn: "2",
    constants.GLOBAL_LOG_LEVEL.info: "3",
    constants.GLOBAL_LOG_LEVEL.debug: "4",
    constants.GLOBAL_LOG_LEVEL.trace: "5",
}

BUILDER_IMAGE_STR = "builder"
SUAVE_ENABLED_GETH_IMAGE_STR = "suave"


def launch(
    plan,
    launcher,
    service_name,
    participant,
    global_log_level,
    existing_el_clients,
    persistent,
    tolerations,
    node_selectors,
    port_publisher,
    participant_index,
    network_params,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.el_log_level, global_log_level, VERBOSITY_LEVELS
    )

    cl_client_name = service_name.split("-")[3]

    config = get_config(
        plan,
        launcher,
        participant,
        service_name,
        existing_el_clients,
        cl_client_name,
        log_level,
        persistent,
        tolerations,
        node_selectors,
        port_publisher,
        participant_index,
        network_params,
    )

    service = plan.add_service(service_name, config)

    enode, enr = el_admin_node_info.get_enode_enr_for_node(
        plan, service_name, constants.RPC_PORT_ID
    )

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    geth_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    http_url = "http://{0}:{1}".format(service.ip_address, RPC_PORT_NUM)
    ws_url = "ws://{0}:{1}".format(service.ip_address, WS_PORT_NUM)

    return el_context.new_el_context(
        client_name="geth",
        enode=enode,
        ip_addr=service.ip_address,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        rpc_http_url=http_url,
        ws_url=ws_url,
        enr=enr,
        service_name=service_name,
        el_metrics_info=[geth_metrics_info],
    )


def get_config(
    plan,
    launcher,
    participant,
    service_name,
    existing_el_clients,
    cl_client_name,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    port_publisher,
    participant_index,
    network_params,
):
    if (
        "--gcmode=archive" in participant.el_extra_params
        or "--gcmode archive" in participant.el_extra_params
    ):
        gcmode_archive = True
    else:
        gcmode_archive = False

    if constants.NETWORK_NAME.shadowfork in network_params.network:  # shadowfork
        init_datadir_cmd_str = "echo shadowfork"

    # TODO: Remove once archive mode works with path based storage scheme
    elif gcmode_archive:  # Disable path based storage scheme archive mode
        init_datadir_cmd_str = "geth init --state.scheme=hash --datadir={0} {1}".format(
            EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
            constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.json",
        )
    else:
        init_datadir_cmd_str = "geth init --datadir={0} {1}".format(
            EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
            constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.json",
        )

    public_ports = {}
    public_ports_for_component = None
    if port_publisher.el_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "el", port_publisher, participant_index
        )
        public_ports = el_shared.get_general_el_public_port_specs(
            public_ports_for_component
        )
        additional_public_port_assignments = {
            constants.RPC_PORT_ID: public_ports_for_component[3],
            constants.WS_PORT_ID: public_ports_for_component[4],
        }
        public_ports.update(
            shared_utils.get_port_specs(additional_public_port_assignments)
        )

    discovery_port_tcp = (
        public_ports_for_component[0]
        if public_ports_for_component
        else DISCOVERY_PORT_NUM
    )
    discovery_port_udp = (
        public_ports_for_component[0]
        if public_ports_for_component
        else DISCOVERY_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port_tcp,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port_udp,
        constants.ENGINE_RPC_PORT_ID: ENGINE_RPC_PORT_NUM,
        constants.RPC_PORT_ID: RPC_PORT_NUM,
        constants.WS_PORT_ID: WS_PORT_NUM,
        constants.METRICS_PORT_ID: METRICS_PORT_NUM,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "geth",
        # TODO: REMOVE Once geth default db is path based, and builder rebased
        "{0}".format("--state.scheme=hash" if gcmode_archive else ""),
        "{0}".format(
            "--{}".format(network_params.network)
            if network_params.network in constants.PUBLIC_NETWORKS
            else ""
        ),
        "{0}".format(
            "--networkid={0}".format(launcher.networkid)
            if network_params.network not in constants.PUBLIC_NETWORKS
            else ""
        ),
        "--verbosity=" + log_level,
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--http",
        "--http.addr=0.0.0.0",
        "--http.port={0}".format(RPC_PORT_NUM),
        "--http.vhosts=*",
        "--http.corsdomain=*",
        # WARNING: The admin info endpoint is enabled so that we can easily get ENR/enode, which means
        #  that users should NOT store private information in these Kurtosis nodes!
        "--http.api=admin,engine,net,eth,web3,debug,txpool",
        "--ws",
        "--ws.addr=0.0.0.0",
        "--ws.port={0}".format(WS_PORT_NUM),
        "--ws.api=admin,engine,net,eth,web3,debug,txpool",
        "--ws.origins=*",
        "--allow-insecure-unlock",
        "--nat=extip:" + port_publisher.nat_exit_ip,
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.addr=0.0.0.0",
        "--authrpc.vhosts=*",
        "--authrpc.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--syncmode=full"
        if network_params.network == "kurtosis" and not gcmode_archive
        else "--syncmode=snap"
        if not gcmode_archive
        else "--gcmode=archive",
        "--rpc.allow-unprotected-txs",
        "--metrics",
        "--metrics.addr=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
        "--discovery.port={0}".format(discovery_port_tcp),
        "--port={0}".format(discovery_port_tcp),
    ]

    if network_params.gas_limit > 0:
        cmd.append("--miner.gaslimit={0}".format(network_params.gas_limit))

    if BUILDER_IMAGE_STR in participant.el_image:
        for index, arg in enumerate(cmd):
            if "--http.api" in arg:
                cmd[index] = "--http.api=admin,engine,net,eth,web3,debug,mev,flashbots"
            if "--ws.api" in arg:
                cmd[index] = "--ws.api=admin,engine,net,eth,web3,debug,mev,flashbots"

    if SUAVE_ENABLED_GETH_IMAGE_STR in participant.el_image:
        for index, arg in enumerate(cmd):
            if "--http.api" in arg:
                cmd[index] = "--http.api=admin,engine,net,eth,web3,debug,suavex"
            if "--ws.api" in arg:
                cmd[index] = "--ws.api=admin,engine,net,eth,web3,debug,suavex"

    if (
        network_params.network == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in network_params.network
    ):
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
        if constants.NETWORK_NAME.shadowfork in network_params.network:  # shadowfork
            if launcher.prague_time:
                cmd.append("--override.prague=" + str(launcher.prague_time))

    elif (
        network_params.network not in constants.PUBLIC_NETWORKS
        and constants.NETWORK_NAME.shadowfork not in network_params.network
    ):
        cmd.append(
            "--bootnodes="
            + shared_utils.get_devnet_enodes(
                plan, launcher.el_cl_genesis_data.files_artifact_uuid
            )
        )

    if len(participant.el_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.el_extra_params])

    cmd_str = " ".join(cmd)
    if network_params.network not in constants.PUBLIC_NETWORKS:
        subcommand_strs = [
            init_datadir_cmd_str,
            cmd_str,
        ]
        command_str = " && ".join(subcommand_strs)
    else:
        command_str = cmd_str

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }
    if persistent:
        files[EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=int(participant.el_volume_size)
            if int(participant.el_volume_size) > 0
            else constants.VOLUME_SIZE[network_params.network][
                constants.EL_TYPE.geth + "_volume_size"
            ],
        )
    env_vars = participant.el_extra_env_vars
    config_args = {
        "image": participant.el_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "cmd": [command_str],
        "files": files,
        "entrypoint": ENTRYPOINT_ARGS,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": env_vars,
        "labels": shared_utils.label_maker(
            client=constants.EL_TYPE.geth,
            client_type=constants.CLIENT_TYPES.el,
            image=participant.el_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=cl_client_name,
            extra_labels=participant.el_extra_labels,
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if participant.el_min_cpu > 0:
        config_args["min_cpu"] = participant.el_min_cpu
    if participant.el_max_cpu > 0:
        config_args["max_cpu"] = participant.el_max_cpu
    if participant.el_min_mem > 0:
        config_args["min_memory"] = participant.el_min_mem
    if participant.el_max_mem > 0:
        config_args["max_memory"] = participant.el_max_mem
    return ServiceConfig(**config_args)


def new_geth_launcher(
    el_cl_genesis_data,
    jwt_file,
    networkid,
    prague_time,
):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        networkid=networkid,
        prague_time=prague_time,
    )
