shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
el_context = import_module("../../el/el_context.star")
el_shared = import_module("../el_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/erigon/execution-data"

METRICS_PATH = "/metrics"

WS_RPC_PORT_NUM = 8545
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001
TORRENT_PORT_NUM = 42069

ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "1",
    constants.GLOBAL_LOG_LEVEL.warn: "2",
    constants.GLOBAL_LOG_LEVEL.info: "3",
    constants.GLOBAL_LOG_LEVEL.debug: "4",
    constants.GLOBAL_LOG_LEVEL.trace: "5",
}


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
        plan, service_name, constants.WS_RPC_PORT_ID
    )

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    erigon_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    http_url = "http://{0}:{1}".format(service.ip_address, WS_RPC_PORT_NUM)
    ws_url = "ws://{0}:{1}".format(service.ip_address, WS_RPC_PORT_NUM)

    return el_context.new_el_context(
        client_name="erigon",
        enode=enode,
        ip_addr=service.ip_address,
        rpc_port_num=WS_RPC_PORT_NUM,
        ws_port_num=WS_RPC_PORT_NUM,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        rpc_http_url=http_url,
        ws_url=ws_url,
        enr=enr,
        service_name=service_name,
        el_metrics_info=[erigon_metrics_info],
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
    init_datadir_cmd_str = "erigon init --datadir={0} {1}".format(
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
            constants.WS_RPC_PORT_ID: public_ports_for_component[3],
            constants.TORRENT_PORT_ID: public_ports_for_component[4],
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
    torrent_port = (
        public_ports_for_component[4]
        if public_ports_for_component
        else TORRENT_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port_tcp,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port_udp,
        constants.ENGINE_RPC_PORT_ID: ENGINE_RPC_PORT_NUM,
        constants.WS_RPC_PORT_ID: WS_RPC_PORT_NUM,
        constants.METRICS_PORT_ID: METRICS_PORT_NUM,
        constants.TORRENT_PORT_ID: torrent_port,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "erigon",
        "{0}".format(
            "--override.prague=" + str(launcher.prague_time)
            if constants.NETWORK_NAME.shadowfork in network_params.network
            else ""
        ),
        "--networkid={0}".format(launcher.networkid),
        "--log.console.verbosity=" + log_level,
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--port={0}".format(discovery_port_tcp),
        "--http.api=eth,erigon,engine,web3,net,debug,trace,txpool,admin",
        "--http.vhosts=*",
        "--ws",
        "--allow-insecure-unlock",
        "--nat=extip:" + port_publisher.nat_exit_ip,
        "--http",
        "--http.addr=0.0.0.0",
        "--http.corsdomain=*",
        "--http.port={0}".format(WS_RPC_PORT_NUM),
        "--authrpc.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--authrpc.addr=0.0.0.0",
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.vhosts=*",
        "--externalcl",
        "--metrics",
        "--metrics.addr=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
        "--torrent.port={0}".format(torrent_port),
    ]

    if network_params.gas_limit > 0:
        cmd.append("--miner.gaslimit={0}".format(network_params.gas_limit))

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }

    if persistent:
        cmd.append(
            "--db.size.limit={0}MB".format(
                int(participant.el_volume_size)
                if int(participant.el_volume_size) > 0
                else constants.VOLUME_SIZE[network_params.network][
                    constants.EL_TYPE.erigon + "_volume_size"
                ],
            )
        )
        files[EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=int(participant.el_volume_size)
            if int(participant.el_volume_size) > 0
            else constants.VOLUME_SIZE[network_params.network][
                constants.EL_TYPE.erigon + "_volume_size"
            ],
        )

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
        cmd.extend([param for param in participant.el_extra_params])

    if network_params.network not in constants.PUBLIC_NETWORKS:
        command_arg = [init_datadir_cmd_str, " ".join(cmd)]
        command_arg_str = " && ".join(command_arg)
    else:
        command_arg_str = " ".join(cmd)

    env_vars = participant.el_extra_env_vars
    config_args = {
        "image": participant.el_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "cmd": [command_arg_str],
        "files": files,
        "entrypoint": ENTRYPOINT_ARGS,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": env_vars,
        "labels": shared_utils.label_maker(
            client=constants.EL_TYPE.erigon,
            client_type=constants.CLIENT_TYPES.el,
            image=participant.el_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=cl_client_name,
            extra_labels=participant.el_extra_labels,
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
        "user": User(uid=0, gid=0),
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


def new_erigon_launcher(el_cl_genesis_data, jwt_file, networkid, prague_time):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        networkid=networkid,
        prague_time=prague_time,
    )
