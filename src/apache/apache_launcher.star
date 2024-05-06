shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "apache"
HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 80

APACHE_CONFIG_FILENAME = "index.html"
APACHE_ENR_FILENAME = "boot_enr.txt"
APACHE_ENODE_FILENAME = "bootnode.txt"

APACHE_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/usr/local/apache2/htdocs/"

# The min/max CPU/memory that assertoor can use
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


def launch_apache(
    plan,
    el_cl_genesis_data,
    participant_contexts,
    participant_configs,
    global_node_selectors,
):
    config_files_artifact_name = plan.upload_files(
        src=static_files.APACHE_CONFIG_FILEPATH, name="apache-config"
    )

    all_enrs=[]
    all_enodes=[]
    for index, participant in enumerate(participant_contexts):
        _, cl_client, el_client, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )
        all_enrs.append(cl_client.enr)
        all_enodes.append(el_client.enode)


    template_data = new_config_template_data(
        all_enrs,
        all_enodes,
    )

    template_and_data = shared_utils.new_template_and_data(
        static_files.APACHE_ENR_FILEPATH,
        template_data,
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[APACHE_ENR_FILENAME] = template_and_data
    template_and_data_by_rel_dest_filepath[APACHE_ENODE_FILENAME] = template_and_data

    bootstrap_info_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "bootstrap-info"
    )

    config = get_config(
        config_files_artifact_name,
        el_cl_genesis_data,
        bootstrap_info_files_artifact_name,
        global_node_selectors,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    el_cl_genesis_data,
    bootstrap_info_files_artifact_name,
    node_selectors,
):
    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data,
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS + "/boot": bootstrap_info_files_artifact_name,
        APACHE_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
    }

    cmd = [
        # "echo",
        # "AddType application/octet-stream .tar",
        # ">>",
        # "/usr/local/apache2/conf/httpd.conf",
        # "&&",
        # "cat <<EOT > /network-configs/enodes.txt\n" + enode_list + "\nEOT",
        # "&&",
        # "tar",
        # "-czvf",
        # "/usr/local/apache2/htdocs/network-config.tar",
        # "-C",
        # "/network-configs/",
        # ".",
        # "&&",
        "httpd-foreground",
    ]

    cmd_str = " ".join(cmd)

    return ServiceConfig(
        image="httpd:latest",
        ports=USED_PORTS,
        cmd=[cmd_str],
        entrypoint=["sh", "-c"],
        files=files,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )

def new_config_template_data(cl_client_info, el_client_info):
    return {
        "CLClientInfo": cl_client_info,
        "ELClientInfo": el_client_info,
    }
