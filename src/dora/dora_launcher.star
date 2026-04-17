shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
SERVICE_NAME = "dora"

HTTP_PORT_NUMBER = 8080

DORA_CONFIG_FILENAME = "dora-config.yaml"

DORA_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE = "/validator-ranges"
VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"

# The min/max CPU/memory that dora can use
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


def launch_dora(
    plan,
    config_template,
    participant_contexts,
    participant_configs,
    network_params,
    dora_params,
    global_node_selectors,
    global_tolerations,
    mev_endpoints,
    mev_endpoint_names,
    port_publisher,
    additional_service_index,
    docker_cache_params,
    el_cl_data_files_artifact_uuid,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    all_cl_client_info = []
    all_el_client_info = []
    for index, participant in enumerate(participant_contexts):
        full_name, cl_client, el_client, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )
        all_cl_client_info.append(
            new_cl_client_info(
                cl_client.beacon_http_url,
                full_name,
            )
        )

        # Skip dummy EL clients - they don't have real execution endpoints
        el_type = participant_configs[index].el_type
        if el_type == "dummy":
            continue

        snooper_el_engine_context = participant_contexts[
            index
        ].snooper_el_engine_context
        execution_snooper_url = ""
        if snooper_el_engine_context:
            execution_snooper_url = "http://{0}:{1}".format(
                snooper_el_engine_context.ip_addr,
                snooper_el_engine_context.engine_rpc_port_num,
            )

        all_el_client_info.append(
            new_el_client_info(
                "http://{0}:{1}".format(
                    el_client.dns_name,
                    el_client.rpc_port_num,
                ),
                execution_snooper_url,
                full_name,
            )
        )

    mev_endpoint_info = []
    for index, endpoint in enumerate(mev_endpoints):
        mev_endpoint_info.append(
            {
                "Index": index,
                "Name": mev_endpoint_names[index],
                "Url": endpoint,
            }
        )

    template_data = new_config_template_data(
        network_params.network,
        HTTP_PORT_NUMBER,
        all_cl_client_info,
        all_el_client_info,
        mev_endpoint_info,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[DORA_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "dora-config"
    )
    config = get_config(
        config_files_artifact_name,
        network_params,
        dora_params,
        global_node_selectors,
        tolerations,
        port_publisher,
        additional_service_index,
        docker_cache_params,
        el_cl_data_files_artifact_uuid,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    network_params,
    dora_params,
    node_selectors,
    tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
    el_cl_data_files_artifact_uuid,
):
    config_file_path = shared_utils.path_join(
        DORA_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        DORA_CONFIG_FILENAME,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    IMAGE_NAME = dora_params.image
    env_vars = dora_params.env
    default_dora_image = (
        docker_cache_params.url
        + (docker_cache_params.dockerhub_prefix if docker_cache_params.enabled else "")
        + constants.DEFAULT_DORA_IMAGE
    )
    if dora_params.image == default_dora_image:
        if network_params.gloas_fork_epoch < constants.FAR_FUTURE_EPOCH:
            IMAGE_NAME = (
                docker_cache_params.url
                + (
                    docker_cache_params.dockerhub_prefix
                    if docker_cache_params.enabled
                    else ""
                )
                + "ethpandaops/dora:gloas-support"
            )
        if network_params.heze_fork_epoch < constants.FAR_FUTURE_EPOCH:
            IMAGE_NAME = (
                docker_cache_params.url
                + (
                    docker_cache_params.dockerhub_prefix
                    if docker_cache_params.enabled
                    else ""
                )
                + "ethpandaops/dora:heze-support"
            )

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            DORA_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
            VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE: VALIDATOR_RANGES_ARTIFACT_NAME,
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data_files_artifact_uuid,
        },
        cmd=["-config", config_file_path],
        env_vars=env_vars,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )


def new_config_template_data(
    network, listen_port_num, cl_client_info, el_client_info, mev_endpoint_info
):
    public_rpc = ""
    if len(el_client_info) > 0:
        public_rpc = el_client_info[0]["Execution_HTTP_URL"]

    return {
        "Network": network,
        "PublicRPC": public_rpc,
        "ListenPortNum": listen_port_num,
        "CLClientInfo": cl_client_info,
        "ELClientInfo": el_client_info,
        "MEVRelayInfo": mev_endpoint_info,
        "PublicNetwork": True if network in constants.PUBLIC_NETWORKS else False,
        "IsDevnet": True if "devnet" in network else False,
    }


def new_cl_client_info(beacon_http_url, full_name):
    return {
        "Beacon_HTTP_URL": beacon_http_url,
        "FullName": full_name,
    }


def new_el_client_info(execution_http_url, execution_snooper_url, full_name):
    return {
        "Execution_HTTP_URL": execution_http_url,
        "Execution_Engine_Snooper_URL": execution_snooper_url,
        "FullName": full_name,
    }
