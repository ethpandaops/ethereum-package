shared_utils = import_module("../shared_utils/shared_utils.star")


SERVICE_NAME = "dora"
IMAGE_NAME = "ethpandaops/dora:master"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 8080

DORA_CONFIG_FILENAME = "dora-config.yaml"

DORA_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE = "/validator-ranges"
VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"

CL_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/cl-genesis-data"
CL_CONFIG_ARTIFACT_NAME = "cl-genesis-data"


USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_dora(
    plan,
    config_template,
    cl_client_contexts,
):
    all_cl_client_info = []
    for index, client in enumerate(cl_client_contexts):
        all_cl_client_info.append(
            new_cl_client_info(
                client.ip_addr, client.http_port_num, client.beacon_service_name
            )
        )

    template_data = new_config_template_data(HTTP_PORT_NUMBER, all_cl_client_info)

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[DORA_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "dora-config"
    )

    config = get_config(config_files_artifact_name)

    plan.add_service(SERVICE_NAME, config)


def get_config(config_files_artifact_name):
    config_file_path = shared_utils.path_join(
        DORA_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        DORA_CONFIG_FILENAME,
    )
    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        files={
            DORA_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
            VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE: VALIDATOR_RANGES_ARTIFACT_NAME,
            CL_CONFIG_MOUNT_DIRPATH_ON_SERVICE: CL_CONFIG_ARTIFACT_NAME,
        },
        cmd=["-config", config_file_path],
    )


def new_config_template_data(listen_port_num, cl_client_info):
    return {
        "ListenPortNum": listen_port_num,
        "CLClientInfo": cl_client_info,
    }


def new_cl_client_info(ip_addr, port_num, service_name):
    return {"IPAddr": ip_addr, "PortNum": port_num, "Name": service_name}
