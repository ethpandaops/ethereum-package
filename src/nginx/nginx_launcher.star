shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
SERVICE_NAME = "nginx"
HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 80
NGINX_CONFIG_FILENAME = "index.html"
NGINX_ENR_FILENAME = "boot_enr.yaml"
NGINX_ENODE_FILENAME = "bootnode.txt"
NGINX_ENR_LIST_FILENAME = "bootstrap_nodes.txt"

NGINX_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/usr/share/nginx/html/"

IMAGE_NAME = "nginx:latest"
# The min/max CPU/memory that nginx can use
MIN_CPU = 100
MAX_CPU = 300
MIN_MEMORY = 128
MAX_MEMORY = 256

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_nginx(
    plan,
    el_cl_genesis_data,
    nginx_port,
    participant_contexts,
    participant_configs,
    port_publisher,
    index,
    global_node_selectors,
    global_tolerations,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    config_files_artifact_name = plan.upload_files(
        src=static_files.NGINX_CONFIG_FILEPATH, name="nginx-config"
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        0,
    )

    all_cl_client_info = []
    all_el_client_info = []
    for index, participant in enumerate(participant_contexts):
        _, cl_client, el_client, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )
        all_cl_client_info.append(new_cl_client_info(cl_client.enr))
        all_el_client_info.append(new_el_client_info(el_client.enode))

    template_data = new_config_template_data(
        all_cl_client_info,
        all_el_client_info,
    )

    enr_template_and_data = shared_utils.new_template_and_data(
        read_file(static_files.NGINX_ENR_FILEPATH),
        template_data,
    )

    enr_list_template_and_data = shared_utils.new_template_and_data(
        read_file(static_files.NGINX_ENR_LIST_FILEPATH),
        template_data,
    )

    enode_template_and_data = shared_utils.new_template_and_data(
        read_file(static_files.NGINX_ENODE_FILEPATH),
        template_data,
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[NGINX_ENR_FILENAME] = enr_template_and_data
    template_and_data_by_rel_dest_filepath[
        NGINX_ENR_LIST_FILENAME
    ] = enr_list_template_and_data
    template_and_data_by_rel_dest_filepath[
        NGINX_ENODE_FILENAME
    ] = enode_template_and_data

    bootstrap_info_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "nginx-bootstrap-info"
    )

    if nginx_port != None:
        public_ports = {
            HTTP_PORT_ID: shared_utils.new_port_spec(
                nginx_port, shared_utils.TCP_PROTOCOL
            )
        }

    config = get_config(
        config_files_artifact_name,
        el_cl_genesis_data,
        public_ports,
        bootstrap_info_files_artifact_name,
        global_node_selectors,
        tolerations,
        docker_cache_params,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    el_cl_genesis_data,
    public_ports,
    bootstrap_info_files_artifact_name,
    node_selectors,
    tolerations,
    docker_cache_params,
):
    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data,
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
        + "/boot": bootstrap_info_files_artifact_name,
        NGINX_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
    }

    cmd = [
        "mv",
        "/network-configs/boot/" + NGINX_ENR_FILENAME,
        "/network-configs/" + NGINX_ENR_FILENAME,
        "&&",
        "mv",
        "/network-configs/boot/" + NGINX_ENODE_FILENAME,
        "/network-configs/" + NGINX_ENODE_FILENAME,
        "&&",
        "mv",
        "/network-configs/boot/" + NGINX_ENR_LIST_FILENAME,
        "/network-configs/" + NGINX_ENR_LIST_FILENAME,
        "&&",
        "cp -R /network-configs /usr/share/nginx/html/",
        "&&",
        "tar",
        "-czvf",
        "/usr/share/nginx/html/network-config.tar",
        "-C",
        "/network-configs/",
        ".",
        "&&",
        'nginx -g "daemon off;"',
    ]

    cmd_str = " ".join(cmd)

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            IMAGE_NAME,
        ),
        ports=USED_PORTS,
        public_ports=public_ports,
        cmd=[cmd_str],
        entrypoint=["sh", "-c"],
        files=files,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )


def new_config_template_data(cl_client, el_client):
    return {
        "CLClient": cl_client,
        "ELClient": el_client,
    }


def new_cl_client_info(enr):
    return {
        "Enr": enr,
    }


def new_el_client_info(enode):
    return {
        "Enode": enode,
    }
