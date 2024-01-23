shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "dora"

HTTP_PORT_ID = "http"
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
    el_cl_data_files_artifact_uuid,
    electra_fork_epoch,
    network,
):
    all_cl_client_info = []
    for index, client in enumerate(cl_client_contexts):
        all_cl_client_info.append(
            new_cl_client_info(
                client.ip_addr, client.http_port_num, client.beacon_service_name
            )
        )

    template_data = new_config_template_data(
        network, HTTP_PORT_NUMBER, all_cl_client_info
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[DORA_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "dora-config"
    )
    el_cl_data_files_artifact_uuid = el_cl_data_files_artifact_uuid
    config = get_config(
        config_files_artifact_name,
        el_cl_data_files_artifact_uuid,
        electra_fork_epoch,
        network,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    el_cl_data_files_artifact_uuid,
    electra_fork_epoch,
    network,
):
    config_file_path = shared_utils.path_join(
        DORA_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        DORA_CONFIG_FILENAME,
    )

    # TODO: This is a hack to get the verkle support image for the electra fork
    if electra_fork_epoch != None or "verkle" in network:
        IMAGE_NAME = "ethpandaops/dora:verkle-support"
    else:
        IMAGE_NAME = "ethpandaops/dora:master"

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        public_ports=USED_PORTS,
        files={
            DORA_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
            VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE: VALIDATOR_RANGES_ARTIFACT_NAME,
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data_files_artifact_uuid,
        },
        cmd=["-config", config_file_path],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
    )


def new_config_template_data(network, listen_port_num, cl_client_info):
    return {
        "Network": network,
        "ListenPortNum": listen_port_num,
        "CLClientInfo": cl_client_info,
        "PublicNetwork": True if network in constants.PUBLIC_NETWORKS else False,
    }


def new_cl_client_info(ip_addr, port_num, service_name):
    return {"IPAddr": ip_addr, "PortNum": port_num, "Name": service_name}
