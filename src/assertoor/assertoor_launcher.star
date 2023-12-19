shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "assertoor"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 8080

ASSERTOOR_CONFIG_FILENAME = "assertoor-config.yaml"

ASSERTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE = "/validator-ranges"
VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"

# The min/max CPU/memory that assertoor can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 2048

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_assertoor(
    plan,
    config_template,
    cl_client_contexts,
    el_client_contexts,
):
    all_client_info = []
    for index, client in enumerate(cl_client_contexts):
        el_client = el_client_contexts[index]
        all_client_info.append(
            new_client_info(
                client.ip_addr, client.http_port_num, el_client.ip_addr, el_client.rpc_port_num, client.beacon_service_name
            )
        )

    template_data = new_config_template_data(HTTP_PORT_NUMBER, all_client_info)

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[ASSERTOOR_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "assertoor-config"
    )
    config = get_config(
        config_files_artifact_name,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name
):
    config_file_path = shared_utils.path_join(
        ASSERTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        ASSERTOOR_CONFIG_FILENAME,
    )

    IMAGE_NAME = "ethpandaops/assertoor:master"

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        files={
            ASSERTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
            VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE: VALIDATOR_RANGES_ARTIFACT_NAME,
        },
        cmd=["--config", config_file_path],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
    )


def new_config_template_data(listen_port_num, client_info):
    return {
        "ListenPortNum": listen_port_num,
        "ClientInfo": client_info,
    }


def new_client_info(cl_ip_addr, cl_port_num, el_ip_addr, el_port_num, service_name):
    return {"CLIPAddr": cl_ip_addr, "CLPortNum": cl_port_num, "ELIPAddr": el_ip_addr, "ELPortNum": el_port_num, "Name": service_name}
