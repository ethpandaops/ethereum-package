shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "blutgang"

HTTP_PORT_NUMBER = 3000
ADMIN_PORT_NUMBER = 5715

BLUTGANG_CONFIG_FILENAME = "config.toml"

BLUTGANG_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

IMAGE_NAME = "makemake1337/blutgang:latest"
# IMAGE_NAME = "busybox:latest"

# The min/max CPU/memory that blutgang can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 2048

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    constants.ADMIN_PORT_ID: shared_utils.new_port_spec(
        ADMIN_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}


def launch_blutgang(
    plan,
    config_template,
    participant_contexts,
    participant_configs,
    network_params,
    global_node_selectors,
    port_publisher,
    additional_service_index,
):
    all_el_client_info = []
    for index, participant in enumerate(participant_contexts):
        full_name, _, el_client, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )
        all_el_client_info.append(
            new_el_client_info(
                el_client.ip_addr,
                el_client.rpc_port_num,
                el_client.ws_port_num,
                full_name,
            )
        )

    template_data = new_config_template_data(
        network_params.network, HTTP_PORT_NUMBER, all_el_client_info
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[BLUTGANG_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "blutgang-config"
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
        BLUTGANG_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        BLUTGANG_CONFIG_FILENAME,
    )

    public_ports = {}
    if port_publisher.additional_services_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "additional_services", port_publisher, additional_service_index
        )
        public_port_assignments = {
            constants.HTTP_PORT_ID: public_ports_for_component[0],
            constants.ADMIN_PORT_ID: public_ports_for_component[1],
        }
        public_ports = shared_utils.get_port_specs(public_port_assignments)

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            BLUTGANG_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=["/app/blutgang", "-c", config_file_path],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        ready_conditions=ReadyCondition(
            recipe=GetHttpRequestRecipe(
                port_id="admin",
                endpoint="/ready",
            ),
            field="code",
            assertion="==",
            target_value=200,
        ),
    )


def new_config_template_data(network, listen_port_num, el_client_info):
    return {
        "Network": network,
        "ListenPortNum": listen_port_num,
        "ELClientInfo": el_client_info,
    }


def new_el_client_info(ip_addr, rpc_port_num, ws_port_num, full_name):
    return {
        "IP_Addr": ip_addr,
        "RPC_PortNum": rpc_port_num,
        "WS_PortNum": ws_port_num,
        "FullName": full_name,
    }
