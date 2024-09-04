shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

IMAGE_NAME = "ethpandaops/tracoor:latest"
SERVICE_NAME = "tracoor"

HTTP_PORT_NUMBER = 7007

TRACOOR_CONFIG_FILENAME = "tracoor-config.yaml"

TRACOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

# The min/max CPU/memory that tracoor can use
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


def launch_tracoor(
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
    all_client_info = []
    for index, participant in enumerate(participant_contexts):
        full_name, cl_client, el_client, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )

        beacon = new_cl_client_info(cl_client.beacon_http_url, full_name)
        execution = new_el_client_info(
            "http://{0}:{1}".format(
                el_client.ip_addr,
                el_client.rpc_port_num,
            ),
            full_name,
        )

        client_info = {
            "Beacon": beacon,
            "Execution": execution,
            "Network": network_params.network,
        }
        all_client_info.append(client_info)
    plan.print(network_params.network)
    template_data = new_config_template_data(
        HTTP_PORT_NUMBER,
        all_client_info,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[TRACOOR_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "tracoor-config"
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
        TRACOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        TRACOOR_CONFIG_FILENAME,
    )

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
            TRACOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=[
            "single",
            "--single-config={0}".format(config_file_path),
        ],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )


def new_config_template_data(
    listen_port_num,
    client_info,
):
    return {
        "ListenPortNum": listen_port_num,
        "ParticipantClientInfo": client_info,
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
