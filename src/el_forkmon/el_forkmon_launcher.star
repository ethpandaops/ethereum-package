shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "el-forkmon"
IMAGE_NAME = "ethpandaops/execution-monitor:master"

HTTP_PORT_NUMBER = 8080

EL_FORKMON_CONFIG_FILENAME = "el-forkmon-config.toml"

EL_FORKMON_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

# The min/max CPU/memory that el-forkmon can use
MIN_CPU = 10
MAX_CPU = 100
MIN_MEMORY = 32
MAX_MEMORY = 256


def launch_el_forkmon(
    plan,
    config_template,
    el_contexts,
    global_node_selectors,
    port_publisher,
    additional_service_index,
):
    all_el_client_info = []
    for client in el_contexts:
        client_info = new_el_client_info(
            client.ip_addr, client.rpc_port_num, client.service_name
        )
        all_el_client_info.append(client_info)

    template_data = new_config_template_data(HTTP_PORT_NUMBER, all_el_client_info)

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        EL_FORKMON_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "el-forkmon-config"
    )

    config = get_config(
        config_files_artifact_name,
        global_node_selectors,
        port_publisher,
        additional_service_index,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    node_selectors,
    port_publisher,
    additional_service_index,
):
    config_file_path = shared_utils.path_join(
        EL_FORKMON_CONFIG_MOUNT_DIRPATH_ON_SERVICE, EL_FORKMON_CONFIG_FILENAME
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
            EL_FORKMON_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=[config_file_path],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )


def new_config_template_data(listen_port_num, el_client_info):
    return {
        "ListenPortNum": listen_port_num,
        "ELClientInfo": el_client_info,
    }


def new_el_client_info(ip_addr, port_num, service_name):
    return {"IPAddr": ip_addr, "PortNum": port_num, "Name": service_name}
