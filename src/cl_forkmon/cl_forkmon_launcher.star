shared_utils = import_module("../shared_utils/shared_utils.star")


SERVICE_NAME = "cl-forkmon"
IMAGE_NAME = "ethpandaops/consensus-monitor:main"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 80

CL_FORKMON_CONFIG_FILENAME = "cl-forkmon-config.toml"

CL_FORKMON_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_cl_forkmon(
    plan,
    config_template,
    cl_client_contexts,
    genesis_unix_timestamp,
    seconds_per_slot,
    slots_per_epoch,
):
    all_cl_client_info = []
    for client in cl_client_contexts:
        client_info = new_cl_client_info(client.ip_addr, client.http_port_num)
        all_cl_client_info.append(client_info)

    template_data = new_config_template_data(
        HTTP_PORT_NUMBER,
        all_cl_client_info,
        seconds_per_slot,
        slots_per_epoch,
        genesis_unix_timestamp,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        CL_FORKMON_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "cl-forkmon-config"
    )

    config = get_config(config_files_artifact_name)

    plan.add_service(SERVICE_NAME, config)


def get_config(config_files_artifact_name):
    config_file_path = shared_utils.path_join(
        CL_FORKMON_CONFIG_MOUNT_DIRPATH_ON_SERVICE, CL_FORKMON_CONFIG_FILENAME
    )
    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        files={
            CL_FORKMON_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=["--config-path", config_file_path],
    )


def new_config_template_data(
    listen_port_num,
    cl_client_info,
    seconds_per_slot,
    slots_per_epoch,
    genesis_unix_timestamp,
):
    return {
        "ListenPortNum": listen_port_num,
        "CLClientInfo": cl_client_info,
        "SecondsPerSlot": seconds_per_slot,
        "SlotsPerEpoch": slots_per_epoch,
        "GenesisUnixTimestamp": genesis_unix_timestamp,
    }


def new_cl_client_info(ip_addr, port_num):
    return {"IPAddr": ip_addr, "PortNum": port_num}
