shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_context = import_module("../../el/el_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
el_shared = import_module("../el_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/besu/execution-data"

METRICS_PATH = "/metrics"

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_HTTP_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 100
EXECUTION_MAX_CPU = 1000
EXECUTION_MIN_MEMORY = 512
EXECUTION_MAX_MEMORY = 2048

JAVA_OPTS = {"JAVA_OPTS": "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n"}

ENTRYPOINT_ARGS = ["sh", "-c"]

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
        else constants.RAM_CPU_OVERRIDES[network_name]["besu_max_cpu"]
    )
    el_min_mem = int(el_min_mem) if int(el_min_mem) > 0 else EXECUTION_MIN_MEMORY
    el_max_mem = (
        int(el_max_mem)
        if int(el_max_mem) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["besu_max_mem"]
    )

    el_volume_size = (
        el_volume_size
        if int(el_volume_size) > 0
        else constants.VOLUME_SIZE[network_name]["besu_volume_size"]
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

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    besu_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )
    http_url = "http://{0}:{1}".format(service.ip_address, RPC_PORT_NUM)
    ws_url = "ws://{0}:{1}".format(service.ip_address, WS_PORT_NUM)

    return el_context.new_el_context(
        "besu",
        "",  # besu has no ENR
        enode,
        service.ip_address,
        RPC_PORT_NUM,
        WS_PORT_NUM,
        ENGINE_HTTP_RPC_PORT_NUM,
        http_url,
        ws_url,
        service_name,
        [besu_metrics_info],
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
            constants.WS_RPC_PORT_ID: public_ports_for_component[3],
            constants.METRICS_PORT_ID: public_ports_for_component[4],
        }
        public_ports.update(
            shared_utils.get_port_specs(additional_public_port_assignments)
        )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.ENGINE_RPC_PORT_ID: ENGINE_HTTP_RPC_PORT_NUM,
        constants.RPC_PORT_ID: RPC_PORT_NUM,
        constants.WS_RPC_PORT_ID: WS_PORT_NUM,
        constants.METRICS_PORT_ID: METRICS_PORT_NUM,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "besu",
        "--logging=" + log_level,
        "--data-path=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--host-allowlist=*",
        "--rpc-http-enabled=true",
        "--rpc-http-host=0.0.0.0",
        "--rpc-http-port={0}".format(RPC_PORT_NUM),
        "--rpc-http-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE,TRACE,WEB3",
        "--rpc-http-cors-origins=*",
        "--rpc-http-max-active-connections=300",
        "--rpc-ws-enabled=true",
        "--rpc-ws-host=0.0.0.0",
        "--rpc-ws-port={0}".format(WS_PORT_NUM),
        "--rpc-ws-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE,TRACE,WEB3",
        "--p2p-enabled=true",
        "--p2p-host=" + port_publisher.nat_exit_ip,
        "--p2p-port={0}".format(discovery_port),
        "--engine-rpc-enabled=true",
        "--engine-jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--engine-host-allowlist=*",
        "--engine-rpc-port={0}".format(ENGINE_HTTP_RPC_PORT_NUM),
        "--sync-mode=FULL",
        "--data-storage-format={0}".format(
            "VERKLE" if "verkle-gen" in network else "BONSAI"
        ),
        "--metrics-enabled=true",
        "--metrics-host=0.0.0.0",
        "--metrics-port={0}".format(METRICS_PORT_NUM),
        "--min-gas-price=1000000000",
        "--bonsai-limit-trie-logs-enabled=false" if "verkle" not in network else "",
    ]
    if network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--genesis-file="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/besu.json"
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
        # we do this as extra_params isn't a normal [] but a proto repeated array
        cmd.extend([param for param in extra_params])

    cmd_str = " ".join(cmd)

    extra_env_vars = extra_env_vars | JAVA_OPTS

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
        cmd=[cmd_str],
        files=files,
        env_vars=extra_env_vars,
        entrypoint=ENTRYPOINT_ARGS,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=el_min_cpu,
        max_cpu=el_max_cpu,
        min_memory=el_min_mem,
        max_memory=el_max_mem,
        labels=shared_utils.label_maker(
            constants.EL_TYPE.besu,
            constants.CLIENT_TYPES.el,
            image,
            cl_client_name,
            extra_labels,
        ),
        user=User(uid=0, gid=0),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )


def new_besu_launcher(el_cl_genesis_data, jwt_file, network):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
    )
