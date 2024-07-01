shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "forky"

HTTP_PORT_NUMBER = 8080

FORKY_CONFIG_FILENAME = "forky-config.yaml"

FORKY_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE = "/validator-ranges"
VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"

# The min/max CPU/memory that forky can use
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


def launch_forky(
    plan,
    config_template,
    participant_contexts,
    participant_configs,
    el_cl_data_files_artifact_uuid,
    network_params,
    global_node_selectors,
    final_genesis_timestamp,
    port_publisher,
    additional_service_index,
):
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
        all_el_client_info.append(
            new_el_client_info(
                "http://{0}:{1}".format(
                    el_client.ip_addr,
                    el_client.rpc_port_num,
                ),
                full_name,
            )
        )

    template_data = new_config_template_data(
        network_params.network,
        network_params.seconds_per_slot,
        final_genesis_timestamp,
        network_params.preset,
        HTTP_PORT_NUMBER,
        all_cl_client_info,
        all_el_client_info,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[FORKY_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "forky-config"
    )
    el_cl_data_files_artifact_uuid = el_cl_data_files_artifact_uuid
    config = get_config(
        config_files_artifact_name,
        el_cl_data_files_artifact_uuid,
        network_params,
        global_node_selectors,
        port_publisher,
        additional_service_index,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    el_cl_data_files_artifact_uuid,
    network_params,
    node_selectors,
    port_publisher,
    additional_service_index,
):
    config_file_path = shared_utils.path_join(
        FORKY_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        FORKY_CONFIG_FILENAME,
    )

    IMAGE_NAME = "ethpandaops/forky:latest"

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            FORKY_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
            VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE: VALIDATOR_RANGES_ARTIFACT_NAME,
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data_files_artifact_uuid,
        },
        cmd=["--config", config_file_path],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )


def new_config_template_data(
    network,
    seconds_per_slot,
    final_genesis_timestamp,
    preset,
    listen_port_num,
    cl_client_info,
    el_client_info,
):
    return {
        "Network": network,
        "SecondsPerSlot": seconds_per_slot,
        "FinalGenesisTimestamp": final_genesis_timestamp,
        "Preset": preset,
        "ListenPortNum": listen_port_num,
        "CLClientInfo": cl_client_info,
        "ELClientInfo": el_client_info,
        "PublicNetwork": True if network in constants.PUBLIC_NETWORKS else False,
    }


def new_cl_client_info(beacon_http_url, full_name):
    return {
        "Beacon_HTTP_URL": beacon_http_url,
        "FullName": full_name,
    }


def new_el_client_info(execution_http_url, full_name):
    return {
        "Execution_HTTP_URL": execution_http_url,
        "FullName": full_name,
    }
