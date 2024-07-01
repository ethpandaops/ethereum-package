shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "dugtrio"

HTTP_PORT_NUMBER = 8080

DUGTRIO_CONFIG_FILENAME = "dugtrio-config.yaml"

DUGTRIO_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

IMAGE_NAME = "ethpandaops/dugtrio:latest"

# The min/max CPU/memory that dugtrio can use
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


def launch_dugtrio(
    plan,
    config_template,
    participant_contexts,
    participant_configs,
    network_params,
    global_node_selectors,
    port_publisher,
    additional_service_index,
):
    all_cl_client_info = []
    for index, participant in enumerate(participant_contexts):
        full_name, cl_client, _, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )
        all_cl_client_info.append(
            new_cl_client_info(
                cl_client.beacon_http_url,
                full_name,
            )
        )

    template_data = new_config_template_data(
        network_params.network, HTTP_PORT_NUMBER, all_cl_client_info
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[DUGTRIO_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "dugtrio-config"
    )
    config = get_config(
        config_files_artifact_name,
        network_params,
        global_node_selectors,
        port_publisher,
        additional_service_index,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    network_params,
    node_selectors,
    port_publisher,
    additional_service_index,
):
    config_file_path = shared_utils.path_join(
        DUGTRIO_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        DUGTRIO_CONFIG_FILENAME,
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
            DUGTRIO_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=["-config", config_file_path],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        ready_conditions=ReadyCondition(
            recipe=GetHttpRequestRecipe(
                port_id="http",
                endpoint="/healthcheck",
            ),
            field="code",
            assertion="==",
            target_value=200,
        ),
    )


def new_config_template_data(network, listen_port_num, cl_client_info):
    return {
        "Network": network,
        "ListenPortNum": listen_port_num,
        "CLClientInfo": cl_client_info,
    }


def new_cl_client_info(beacon_http_url, full_name):
    return {
        "Beacon_HTTP_URL": beacon_http_url,
        "FullName": full_name,
    }
