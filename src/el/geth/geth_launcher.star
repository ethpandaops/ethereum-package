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

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 300
EXECUTION_MIN_MEMORY = 512

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

    network_name = shared_utils.get_network_name(launcher.network)

    el_min_cpu = int(el_min_cpu) if int(el_min_cpu) > 0 else EXECUTION_MIN_CPU
    el_max_cpu = (
        int(el_max_cpu)
        if int(el_max_cpu) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["geth_max_cpu"]
    )
    el_min_mem = int(el_min_mem) if int(el_min_mem) > 0 else EXECUTION_MIN_MEMORY
    el_max_mem = (
        int(el_max_mem)
        if int(el_max_mem) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["geth_max_mem"]
    )

    el_volume_size = (
        el_volume_size
        if int(el_volume_size) > 0
        else constants.VOLUME_SIZE[network_name]["geth_volume_size"]
    )

    cl_client_name = service_name.split("-")[3]

    config = get_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        launcher.network,
        launcher.networkid,
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
        launcher.prague_time,
        persistent,
        el_volume_size,
        tolerations,
        node_selectors,
        port_publisher,
        participant_index,
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
        "geth",
        enr,
        enode,
        service.ip_address,
        RPC_PORT_NUM,
        WS_PORT_NUM,
        ENGINE_RPC_PORT_NUM,
        http_url,
        ws_url,
        service_name,
        [geth_metrics_info],
    )


def get_config(
    plan,
    el_cl_genesis_data,
    jwt_file,
    network,
    networkid,
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
    prague_time,
    persistent,
    el_volume_size,
    tolerations,
    node_selectors,
    port_publisher,
    participant_index,
):
    if "--gcmode=archive" in extra_params or "--gcmode archive" in extra_params:
        gcmode_archive = True
    else:
        gcmode_archive = False
    # TODO: Remove this once electra fork has path based storage scheme implemented
    if (
        constants.NETWORK_NAME.verkle in network
    ) and constants.NETWORK_NAME.shadowfork not in network:
        if constants.NETWORK_NAME.verkle + "-gen" in network:  # verkle-gen
            init_datadir_cmd_str = "geth --datadir={0} --cache.preimages --override.prague={1} init {2}".format(
                EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
                prague_time,
                constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.json",
            )
        else:  # verkle
            init_datadir_cmd_str = (
                "geth --datadir={0} --cache.preimages init {1}".format(
                    EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
                    constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.json",
                )
            )
    elif constants.NETWORK_NAME.shadowfork in network:  # shadowfork
        init_datadir_cmd_str = "echo shadowfork"

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
            constants.WS_RPC_PORT_ID: public_ports_for_component[3],
            constants.METRICS_PORT_ID: public_ports_for_component[4],
        }
        public_ports.update(
            shared_utils.get_port_specs(additional_public_port_assignments)
        )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.ENGINE_RPC_PORT_ID: ENGINE_RPC_PORT_NUM,
        constants.RPC_PORT_ID: RPC_PORT_NUM,
        constants.WS_RPC_PORT_ID: WS_PORT_NUM,
        constants.METRICS_PORT_ID: METRICS_PORT_NUM,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "geth",
        # Disable path based storage scheme for electra fork and verkle
        # TODO: REMOVE Once geth default db is path based, and builder rebased
        "{0}".format(
            "--state.scheme=hash" if "verkle" in network or gcmode_archive else ""
        ),
        # Override prague fork timestamp for electra fork
        "{0}".format("--cache.preimages" if "verkle" in network else ""),
        "{0}".format(
            "--{}".format(network) if network in constants.PUBLIC_NETWORKS else ""
        ),
        "--networkid={0}".format(networkid),
        "--verbosity=" + verbosity_level,
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
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
        "--nat=extip:" + port_publisher.nat_exit_ip,
        "--verbosity=" + verbosity_level,
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.addr=0.0.0.0",
        "--authrpc.vhosts=*",
        "--authrpc.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--syncmode=full" if not gcmode_archive else "--gcmode=archive",
        "--rpc.allow-unprotected-txs",
        "--metrics",
        "--metrics.addr=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
        "--discovery.port={0}".format(discovery_port),
        "--port={0}".format(discovery_port),
    ]

    if BUILDER_IMAGE_STR in image:
        for index, arg in enumerate(cmd):
            if "--http.api" in arg:
                cmd[index] = "--http.api=admin,engine,net,eth,web3,debug,mev,flashbots"
            if "--ws.api" in arg:
                cmd[index] = "--ws.api=admin,engine,net,eth,web3,debug,mev,flashbots"

    if SUAVE_ENABLED_GETH_IMAGE_STR in image:
        for index, arg in enumerate(cmd):
            if "--http.api" in arg:
                cmd[index] = "--http.api=admin,engine,net,eth,web3,debug,suavex"
            if "--ws.api" in arg:
                cmd[index] = "--ws.api=admin,engine,net,eth,web3,debug,suavex"

    if (
        network == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in network
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
        if constants.NETWORK_NAME.shadowfork in network:  # shadowfork
            cmd.append("--override.prague=" + str(prague_time))
            if "verkle" in network:  # verkle-shadowfork
                cmd.append("--override.overlay-stride=10000")
                cmd.append("--override.blockproof=true")
                cmd.append("--clear.verkle.costs=true")

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

    cmd_str = " ".join(cmd)
    if network not in constants.PUBLIC_NETWORKS:
        subcommand_strs = [
            init_datadir_cmd_str,
            cmd_str,
        ]
        command_str = " && ".join(subcommand_strs)
    else:
        command_str = cmd_str

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
        ports=used_ports,
        public_ports=public_ports,
        cmd=[command_str],
        files=files,
        entrypoint=ENTRYPOINT_ARGS,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=el_min_cpu,
        max_cpu=el_max_cpu,
        min_memory=el_min_mem,
        max_memory=el_max_mem,
        env_vars=extra_env_vars,
        labels=shared_utils.label_maker(
            constants.EL_TYPE.geth,
            constants.CLIENT_TYPES.el,
            image,
            cl_client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )


def new_geth_launcher(
    el_cl_genesis_data,
    jwt_file,
    network,
    networkid,
    prague_time,
):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
        networkid=networkid,
        prague_time=prague_time,
    )
