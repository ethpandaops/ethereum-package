shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_context = import_module("../../el/el_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

WS_RPC_PORT_NUM = 8545
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 100
EXECUTION_MIN_MEMORY = 256

# Port IDs
WS_RPC_PORT_ID = "ws-rpc"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID = "engine-rpc"
METRICS_PORT_ID = "metrics"

# Paths
METRICS_PATH = "/metrics"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/nimbus/execution-data"


def get_used_ports(discovery_port=DISCOVERY_PORT_NUM):
    used_ports = {
        WS_RPC_PORT_ID: shared_utils.new_port_spec(
            WS_RPC_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
        TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port,
            shared_utils.TCP_PROTOCOL,
        ),
        UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port,
            shared_utils.UDP_PROTOCOL,
        ),
        ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(
            ENGINE_RPC_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
        ),
        METRICS_PORT_ID: shared_utils.new_port_spec(
            METRICS_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
        ),
    }
    return used_ports


VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
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
    extra_labels,
    persistent,
    el_volume_size,
    tolerations,
    node_selectors,
    port_publisher,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )

    network_name = shared_utils.get_network_name(launcher.network)

    el_min_cpu = int(el_min_cpu) if int(el_min_cpu) > 0 else EXECUTION_MIN_CPU
    el_max_cpu = (
        int(el_max_cpu)
        if int(el_max_cpu) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["nimbus_eth1_max_cpu"]
    )
    el_min_mem = int(el_min_mem) if int(el_min_mem) > 0 else EXECUTION_MIN_MEMORY
    el_max_mem = (
        int(el_max_mem)
        if int(el_max_mem) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["nimbus_eth1_max_mem"]
    )

    el_volume_size = (
        el_volume_size
        if int(el_volume_size) > 0
        else constants.VOLUME_SIZE[network_name]["nimbus_eth1_volume_size"]
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
    )

    service = plan.add_service(service_name, config)

    enode = el_admin_node_info.get_enode_for_node(plan, service_name, WS_RPC_PORT_ID)

    metric_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    nimbus_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metric_url
    )

    return el_context.new_el_context(
        "nimbus",
        "",  # nimbus has no enr
        enode,
        service.ip_address,
        WS_RPC_PORT_NUM,
        WS_RPC_PORT_NUM,
        ENGINE_RPC_PORT_NUM,
        service_name,
        [nimbus_metrics_info],
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
):
    public_ports = {}
    discovery_port = DISCOVERY_PORT_NUM
    if port_publisher.public_port_start:
        discovery_port = port_publisher.el_start + len(existing_el_clients)
        public_ports = {
            TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
                discovery_port, shared_utils.TCP_PROTOCOL
            ),
            UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
                discovery_port, shared_utils.UDP_PROTOCOL
            ),
        }
    used_ports = get_used_ports(discovery_port)

    cmd = [
        "--log-level={0}".format(verbosity_level),
        "--data-dir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--http-port={0}".format(WS_RPC_PORT_NUM),
        "--http-address=0.0.0.0",
        "--rpc",
        "--rpc-api=eth,debug,exp",
        "--ws",
        "--ws-api=eth,debug,exp",
        "--engine-api",
        "--engine-api-address=0.0.0.0",
        "--engine-api-port={0}".format(ENGINE_RPC_PORT_NUM),
        "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-port={0}".format(METRICS_PORT_NUM),
        "--nat=extip:{0}".format(port_publisher.nat_exit_ip),
        "--tcp-port={0}".format(discovery_port),
    ]
    if (
        network not in constants.PUBLIC_NETWORKS
        or constants.NETWORK_NAME.shadowfork in network
    ):
        cmd.append(
            "--custom-network="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis.json"
        )
    else:
        cmd.append("--network=" + network)

    if network == constants.NETWORK_NAME.kurtosis:
        if len(existing_el_clients) > 0:
            cmd.append(
                "--bootstrap-node="
                + ",".join(
                    [
                        ctx.enode
                        for ctx in existing_el_clients[: constants.MAX_ENODE_ENTRIES]
                    ]
                )
            )
    elif network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--bootstrap-node="
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

    return ServiceConfig(
        image=image,
        ports=used_ports,
        public_ports=public_ports,
        cmd=cmd,
        files=files,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=el_min_cpu,
        max_cpu=el_max_cpu,
        min_memory=el_min_mem,
        max_memory=el_max_mem,
        env_vars=extra_env_vars,
        labels=shared_utils.label_maker(
            constants.EL_TYPE.nimbus,
            constants.CLIENT_TYPES.el,
            image,
            cl_client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )


def new_nimbus_launcher(el_cl_genesis_data, jwt_file, network):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
    )
