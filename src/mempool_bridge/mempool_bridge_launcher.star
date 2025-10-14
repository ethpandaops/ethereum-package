shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "mempool-bridge"
MAX_ENODES_TO_FETCH = 5

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
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    network = network_params.network
    source_endpoints = []
    if mempool_bridge_params.source_enodes:
        source_endpoints = mempool_bridge_params.source_enodes
    else:
        if "shadowfork" in network_params.network:
            network = network_params.network.split("-shadowfork")[0]
        if network in constants.PUBLIC_NETWORKS:
            plan.print("Fetching enodes for {0} from eth-clients repo".format(network))
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

    # Build target endpoints from all EL contexts using enode/enr
    target_endpoints = []
    for context in all_el_contexts:
        # Prefer enode if available, fallback to enr
        if context.enode:
            target_endpoints.append(context.enode)
        elif context.enr:
            target_endpoints.append(context.enr)

    template_data = new_config_template_data(
        HTTP_PORT_NUMBER,
        source_endpoints,
        target_endpoints,
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
):
    return {
        "ListenPortNum": listen_port_num,
        "SourceEndpoints": source_endpoints,
        "TargetEndpoints": target_endpoints,
    }
