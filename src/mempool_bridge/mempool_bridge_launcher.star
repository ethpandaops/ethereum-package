shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")

SERVICE_NAME = "mempool-bridge"
MAX_ENODES_TO_FETCH = 5

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "trace",
}

ENODE_URLS = {
    "mainnet": "https://raw.githubusercontent.com/eth-clients/mainnet/refs/heads/main/metadata/enodes.yaml",
    "sepolia": "https://raw.githubusercontent.com/eth-clients/sepolia/refs/heads/main/metadata/enodes.yaml",
    "hoodi": "https://raw.githubusercontent.com/eth-clients/hoodi/refs/heads/main/metadata/enodes.yaml",
    "holesky": "https://raw.githubusercontent.com/eth-clients/holesky/refs/heads/main/metadata/enodes.yaml",
}

HTTP_PORT_NUMBER = 9090

MEMPOOL_BRIDGE_CONFIG_FILENAME = "config.yaml"
MEMPOOL_BRIDGE_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 2048

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_mempool_bridge(
    plan,
    config_template,
    all_el_contexts,
    mempool_bridge_params,
    network_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
    global_log_level,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    network = network_params.network
    mode = mempool_bridge_params.mode

    if mode == "rpc" and not mempool_bridge_params.source_enodes:
        fail(
            "RPC mode requires source_enodes to be explicitly defined. Please provide dedicated RPC endpoints as the source when using RPC mode."
        )

    # Build source endpoints based on mode
    source_endpoints = []
    if mempool_bridge_params.source_enodes:
        source_endpoints = mempool_bridge_params.source_enodes
    else:
        # Only fetch enodes for p2p mode when using public networks
        if mode == "p2p":
            if "shadowfork" in network_params.network:
                network = network_params.network.split("-shadowfork")[0]
            if network in constants.PUBLIC_NETWORKS:
                plan.print(
                    "Fetching enodes for {0} from eth-clients repo".format(network)
                )
                for i in range(1, MAX_ENODES_TO_FETCH + 1):
                    enode = plan.run_sh(
                        name="fetch-enode-{0}".format(i),
                        description="Fetching enode #{0}".format(i),
                        run="curl -s {0} | grep -E '^[[:space:]]*-[[:space:]]*enode' | sed -n '{1}p' | sed 's/^[[:space:]]*-[[:space:]]*//; s/[[:space:]]*#.*//' | tr -d '\\n'".format(
                            ENODE_URLS[network], i
                        ),
                        node_selectors=global_node_selectors,
                        tolerations=tolerations,
                        wait=None,
                    )
                    source_endpoints.append(enode.output)

    # Build target endpoints from all EL contexts based on mode
    target_endpoints = []
    for context in all_el_contexts:
        if mode == "rpc":
            # For RPC mode, use HTTP RPC endpoint
            rpc_url = "http://{0}:{1}".format(context.dns_name, context.rpc_port_num)
            target_endpoints.append(rpc_url)
        else:
            # For P2P mode, prefer enode if available, fallback to enr
            if context.enode:
                target_endpoints.append(context.enode)
            elif context.enr:
                target_endpoints.append(context.enr)

    # Determine log level: use mempool_bridge_params.log_level if set, otherwise use global_log_level
    log_level = input_parser.get_client_log_level_or_default(
        mempool_bridge_params.log_level, global_log_level, VERBOSITY_LEVELS
    )

    template_data = new_config_template_data(
        HTTP_PORT_NUMBER,
        source_endpoints,
        target_endpoints,
        mempool_bridge_params.mode,
        log_level,
        mempool_bridge_params.send_concurrency,
        mempool_bridge_params.polling_interval,
        mempool_bridge_params.retry_interval,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        MEMPOOL_BRIDGE_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "mempool-bridge-config"
    )

    config = get_config(
        config_files_artifact_name,
        global_node_selectors,
        tolerations,
        port_publisher,
        additional_service_index,
        docker_cache_params,
        mempool_bridge_params,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    node_selectors,
    tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
    mempool_bridge_params,
):
    config_file_path = shared_utils.path_join(
        MEMPOOL_BRIDGE_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        MEMPOOL_BRIDGE_CONFIG_FILENAME,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            mempool_bridge_params.image,
        ),
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            MEMPOOL_BRIDGE_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=[
            "--config={0}".format(config_file_path),
        ],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )


def new_config_template_data(
    listen_port_num,
    source_endpoints,
    target_endpoints,
    mode,
    log_level,
    send_concurrency,
    polling_interval,
    retry_interval,
):
    return {
        "ListenPortNum": listen_port_num,
        "SourceEndpoints": source_endpoints,
        "TargetEndpoints": target_endpoints,
        "Mode": mode,
        "LogLevel": log_level,
        "SendConcurrency": send_concurrency,
        "PollingInterval": polling_interval,
        "RetryInterval": retry_interval,
    }
