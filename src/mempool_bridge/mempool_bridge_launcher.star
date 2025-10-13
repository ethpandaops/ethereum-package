shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

IMAGE_NAME = "ethpandaops/mempool-bridge:latest"
SERVICE_NAME = "mempool-bridge"
CURL_IMAGE = "badouralix/curl-jq"

# Enode source URLs for different networks
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

    # Build source endpoints - either from params, fetch from network, or use first node
    # Mempool-bridge uses ENR/enode for P2P connections, not HTTP RPC
    source_endpoints = []
    if len(mempool_bridge_params.source_enodes) > 0:
        # Use provided enodes
        for enode in mempool_bridge_params.source_enodes:
            source_endpoints.append(enode)
    elif constants.NETWORK_NAME.shadowfork in network_params.network:
        # For shadowforks, fetch enodes from eth-clients repos
        shadow_base = network_params.network.split("-shadowfork")[0]
        if shadow_base in ENODE_URLS:
            plan.print("Fetching enodes for {0} from eth-clients repo".format(shadow_base))
            source_endpoints = fetch_enodes_from_url(plan, ENODE_URLS[shadow_base], all_el_contexts)
            plan.print("Fetched {0} enodes for source".format(len(source_endpoints)))

    if len(source_endpoints) == 0 and len(all_el_contexts) > 0:
        # If no source specified, use first node as source for local testing
        first_context = all_el_contexts[0]
        if first_context.enode:
            source_endpoints.append(first_context.enode)
        elif first_context.enr:
            source_endpoints.append(first_context.enr)

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
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    node_selectors,
    tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
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
            IMAGE_NAME,
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


def fetch_enodes_from_url(plan, url, el_contexts):
    """
    Fetch and parse enodes from a YAML file URL using curl.
    Returns a list of enode strings.
    """
    # Use first EL service to run curl command
    if len(el_contexts) == 0:
        return []

    first_el_service = el_contexts[0].service_name

    # Use curl to fetch the YAML file
    curl_result = plan.exec(
        service_name=first_el_service,
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                'curl -s "{0}" | grep "^- enode:" | sed "s/^- //" | sed "s/ *#.*//"'.format(url),
            ]
        ),
    )

    # Parse the output to extract enodes
    enodes = []
    output = curl_result["output"]
    if output:
        lines = output.split("\n")
        for line in lines:
            line = line.strip()
            if line and line.startswith("enode://"):
                enodes.append(line)

    return enodes
