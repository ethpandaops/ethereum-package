shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_context = import_module("../../el/el_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")
el_shared = import_module("../el_shared.star")

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

# Paths
METRICS_PATH = "/metrics"
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/ethrex/execution-data"


def get_used_ports(discovery_port):
    used_ports = {
        constants.RPC_PORT_ID: shared_utils.new_port_spec(
            RPC_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
        constants.ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(
            ENGINE_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL
        ),
        constants.METRICS_PORT_ID: shared_utils.new_port_spec(
            METRICS_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "trace",
}


def get_config(
    plan,
    launcher,
    participant,
    service_name,
    existing_el_clients,
    cl_client_name,
    global_log_level,
    persistent,
    tolerations,
    node_selectors,
    port_publisher,
    participant_index,
    network_params,
    extra_files_artifacts,
    bootnodoor_el_enr=None,
    el_binary_artifact=None,
    otel_otlp_grpc_url=None,
):
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
            # constants.WS_PORT_ID: public_ports_for_component[4],
        }
        public_ports.update(
            shared_utils.get_port_specs(additional_public_port_assignments)
        )

    discovery_port_tcp, discovery_port_udp = el_shared.get_discovery_ports(
        public_ports_for_component, DISCOVERY_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port_tcp,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port_udp,
        constants.ENGINE_RPC_PORT_ID: ENGINE_RPC_PORT_NUM,
        constants.RPC_PORT_ID: RPC_PORT_NUM,
        # constants.WS_PORT_ID: WS_PORT_NUM,
        constants.METRICS_PORT_ID: METRICS_PORT_NUM,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    log_level = input_parser.get_client_log_level_or_default(
        participant.el_log_level, global_log_level, VERBOSITY_LEVELS
    )

    cmd = [
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--network={0}".format(
            network_params.network
            if network_params.network in constants.PUBLIC_NETWORKS
            else constants.GENESIS_JSON_MOUNT_PATH_ON_CONTAINER
        ),
        "--syncmode=snap" if participant.checkpoint_sync_enabled else "--syncmode=full",
        "--log.level={0}".format(log_level),
        "--http.port={0}".format(RPC_PORT_NUM),
        "--http.addr=0.0.0.0",
        "--http.api=eth,net,web3,debug,admin,txpool",
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--authrpc.addr=0.0.0.0",
        "--p2p.port={0}".format(discovery_port_tcp),
        "--discovery.port={0}".format(discovery_port_udp),
        "--p2p.discv4=false",
        "--p2p.discv5=true",
        "--metrics",
        "--metrics.addr=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
        "--nat.extip=" + port_publisher.el_nat_exit_ip,
    ]
    # Handle bootnode configuration with bootnodoor_el_enr override
    bootnode_arg = el_shared.get_bootnode_arg(
        plan,
        launcher,
        network_params.network,
        existing_el_clients,
        bootnodoor_el_enr,
        "--bootnodes=",
    )
    if bootnode_arg != None:
        cmd.append(bootnode_arg)

    if network_params.gas_limit > 0:
        cmd.append("--builder.gas-limit={0}".format(network_params.gas_limit))

    if len(participant.el_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.el_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }

    if persistent:
        files[
            EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER
        ] = el_shared.get_persistent_data_directory(
            participant,
            service_name,
            network_params.network,
            constants.EL_TYPE.ethrex,
        )

    # Add extra mounts - automatically handle file uploads
    processed_mounts = shared_utils.process_extra_mounts(
        plan, participant.el_extra_mounts, extra_files_artifacts
    )
    for mount_path, artifact in processed_mounts.items():
        files[mount_path] = artifact

    el_shared.mount_el_binary_artifact(files, el_binary_artifact)

    config_args = {
        "image": participant.el_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.el_enabled,
        "cmd": cmd,
        "files": files,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": shared_utils.with_otel_env_vars(
            participant.el_extra_env_vars,
            otel_otlp_grpc_url,
            service_name,
        ),
        "labels": shared_utils.label_maker(
            client=constants.EL_TYPE.ethrex,
            client_type=constants.CLIENT_TYPES.el,
            image=participant.el_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=cl_client_name,
            extra_labels=participant.el_extra_labels
            | {constants.NODE_INDEX_LABEL_KEY: str(participant_index + 1)},
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    el_shared.apply_el_binary_override(
        config_args, el_binary_artifact, "/usr/local/bin/ethrex", "ethrex", cmd
    )

    el_shared.apply_resource_limits(config_args, participant)

    return ServiceConfig(**config_args)


# makes request to [service_name] for enode and enr and returns a full el_context
def get_el_context(
    plan,
    service_name,
    service,
    launcher,
    skip_enode=False,
):
    enode = ""
    enr = ""
    if not skip_enode:
        enode, enr = el_admin_node_info.get_enode_enr_for_node(
            plan, service_name, constants.RPC_PORT_ID
        )

    metrics_url = "{0}:{1}".format(service.name, METRICS_PORT_NUM)
    ethrex_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    http_url = "http://{0}:{1}".format(service.name, RPC_PORT_NUM)
    # ws_url = "ws://{0}:{1}".format(service.name, WS_PORT_NUM)

    return el_context.new_el_context(
        client_name="ethrex",
        enode=enode,
        dns_name=service.name,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        rpc_http_url=http_url,
        # ws_url=ws_url,
        enr=enr,
        service_name=service_name,
        el_metrics_info=[ethrex_metrics_info],
        ip_addr=service.ip_address,
    )


def new_ethrex_launcher(el_cl_genesis_data, jwt_file):
    return struct(el_cl_genesis_data=el_cl_genesis_data, jwt_file=jwt_file)
