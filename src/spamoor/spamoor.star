shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "spamoor"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 8080

SPAMOOR_CONFIG_FILENAME = "startup-spammers.yaml"

SPAMOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

# The min/max CPU/memory that spamoor can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 20
MAX_MEMORY = 300

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_spamoor(
    plan,
    config_template,
    prefunded_addresses,
    participant_contexts,
    participant_configs,
    spamoor_params,
    global_node_selectors,
    network_params,
    osaka_time,
):
    spammers = []

    for index, spammer in enumerate(spamoor_params.spammers):
        if (
            "peerdas" in network_params.network
            or network_params.fulu_fork_epoch != constants.FAR_FUTURE_EPOCH
        ) and "blob" in spammer["scenario"]:
            if "config" not in spammer:
                spammer["config"] = {}
            spammer["config"]["fulu_activation"] = osaka_time

        spammers.append(spammer)

    template_data = new_config_template_data(spammers)

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[SPAMOOR_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "spamoor-config"
    )

    config = get_config(
        config_files_artifact_name,
        prefunded_addresses,
        participant_contexts,
        participant_configs,
        spamoor_params,
        global_node_selectors,
        network_params,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    prefunded_addresses,
    participant_contexts,
    participant_configs,
    spamoor_params,
    node_selectors,
    network_params,
):
    image_name = spamoor_params.image
    if spamoor_params.image == constants.DEFAULT_SPAMOOR_IMAGE:
        if (
            "peerdas" in network_params.network
            or network_params.fulu_fork_epoch != constants.FAR_FUTURE_EPOCH
        ):
            image_name = "ethpandaops/spamoor:blob-v1"

    config_file_path = shared_utils.path_join(
        SPAMOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        SPAMOOR_CONFIG_FILENAME,
    )

    rpchosts = []
    for index, participant in enumerate(participant_contexts):
        (
            full_name,
            cl_client,
            el_client,
            participant_config,
        ) = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )

        rpchost = "http://{0}:{1}".format(
            el_client.ip_addr,
            el_client.rpc_port_num,
        )

        if "builder" in full_name:
            rpchost = "group(mevbuilder)" + rpchost

        rpchosts.append(rpchost)

    cmd = [
        "--privkey={}".format(prefunded_addresses[13].private_key),
        "--rpchost={}".format(",".join(rpchosts)),
        "--startup-spammer={}".format(config_file_path),
    ]

    return ServiceConfig(
        image=image_name,
        entrypoint=["./spamoor-daemon"],
        cmd=cmd,
        ports=USED_PORTS,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        files={
            SPAMOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
    )


def new_config_template_data(
    startup_spammer,
):
    startup_spammer_json = []
    for index, spammer in enumerate(startup_spammer):
        startup_spammer_json.append(json.encode(spammer))

    return {
        "StartupSpammer": startup_spammer_json,
    }
