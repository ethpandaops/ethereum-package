shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_client_context = import_module("../../el/el_client_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
genesis_constants = import_module(
    "../../prelaunch_data_generator/genesis_constants/genesis_constants.star"
)

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
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/geth/execution-data"

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
    constants.GLOBAL_CLIENT_LOG_LEVEL.error: "1",
    constants.GLOBAL_CLIENT_LOG_LEVEL.warn: "2",
    constants.GLOBAL_CLIENT_LOG_LEVEL.info: "3",
    constants.GLOBAL_CLIENT_LOG_LEVEL.debug: "4",
    constants.GLOBAL_CLIENT_LOG_LEVEL.trace: "5",
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
        launcher.capella_fork_epoch,
        launcher.electra_fork_epoch,
        launcher.cancun_time,
        launcher.prague_time,
        persistent,
        el_volume_size,
        tolerations,
        node_selectors,
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
    capella_fork_epoch,
    electra_fork_epoch,
    cancun_time,
    prague_time,
    persistent,
    el_volume_size,
    tolerations,
    node_selectors,
):
    # TODO: Remove this once electra fork has path based storage scheme implemented
    if (
        electra_fork_epoch != None or constants.NETWORK_NAME.verkle in network
    ) and constants.NETWORK_NAME.shadowfork not in network:
        if (
            electra_fork_epoch == 0 or constants.NETWORK_NAME.verkle + "-gen" in network
        ):  # verkle-gen
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
    elif "--builder" in extra_params or capella_fork_epoch != 0:
        init_datadir_cmd_str = "geth init --datadir={0} {1}".format(
            EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
            constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.json",
        )
    elif constants.NETWORK_NAME.shadowfork in network:
        init_datadir_cmd_str = "echo shadowfork"
    else:
        init_datadir_cmd_str = "geth init --state.scheme=path --datadir={0} {1}".format(
            EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
            constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.json",
        )

    cmd = [
        "geth",
        # Disable path based storage scheme for electra fork or when builder image or when capella is not 0 is used
        # TODO: REMOVE Once geth default db is path based, and builder rebased
        # TODO: capella fork epoch check is needed to ensure older versions of geth works.
        "{0}".format(
            "--state.scheme=path"
            if electra_fork_epoch == None
            and "verkle" not in network
            and constants.NETWORK_NAME.shadowfork not in network  # for now
            and "--builder" not in extra_params
            and capella_fork_epoch == 0
            else ""
        ),
        # Override prague fork timestamp for electra fork
        "{0}".format(
            "--cache.preimages"
            if electra_fork_epoch != None or "verkle" in network
            else ""
        ),
        # Override prague fork timestamp if electra_fork_epoch == 0
        "{0}".format(
            "--override.prague=" + str(prague_time)
            if electra_fork_epoch == 0 or "verkle-gen" in network
            else ""
        ),
        "{0}".format(
            "--{}".format(network) if network in constants.PUBLIC_NETWORKS else ""
        ),
        "{0}".format(
            "--override.cancun=" + str(cancun_time)
            if constants.NETWORK_NAME.shadowfork in network
            else ""
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
        "--nat=extip:" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--verbosity=" + verbosity_level,
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.addr=0.0.0.0",
        "--authrpc.vhosts=*",
        "--authrpc.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--syncmode=full",
        "--rpc.allow-unprotected-txs",
        "--metrics",
        "--metrics.addr=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
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
        if (
            constants.NETWORK_NAME.shadowfork in network and "verkle" in network
        ):  # verkle shadowfork
            cmd.append("--override.prague=" + str(prague_time))
            cmd.append("--override.overlay-stride=10000")
            cmd.append("--override.blockproof=true")
            cmd.append("--clear.verkle.costs=true")
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
        ports=USED_PORTS,
        cmd=[command_str],
        files=files,
        entrypoint=ENTRYPOINT_ARGS,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=el_min_cpu,
        max_cpu=el_max_cpu,
        min_memory=el_min_mem,
        max_memory=el_max_mem,
        env_vars=extra_env_vars,
        labels=shared_utils.label_maker(
            constants.EL_CLIENT_TYPE.geth,
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
    capella_fork_epoch,
    cancun_time,
    prague_time,
    electra_fork_epoch=None,
):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
        networkid=networkid,
        capella_fork_epoch=capella_fork_epoch,
        cancun_time=cancun_time,
        prague_time=prague_time,
        electra_fork_epoch=electra_fork_epoch,
    )
