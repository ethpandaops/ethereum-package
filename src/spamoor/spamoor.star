shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "spamoor"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 8080

SPAMOOR_CONFIG_FILENAME = "startup-spammers.yaml"

SPAMOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

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
    port_publisher,
    additional_service_index,
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

    for index, participant in enumerate(participant_contexts):
        (
            full_name,
            cl_client,
            el_client,
            participant_config,
        ) = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )

        if "builder" in full_name:
            spammers.append(
                {
                    "scenario": "uniswap-swaps",
                    "name": "Uniswap Swaps",
                    "config": {
                        "throughput": 100,
                        "max_pending": 200,
                        "max_wallets": 200,
                        "client_group": "mevbuilder",
                    },
                }
            )

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
        port_publisher,
        additional_service_index,
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
    port_publisher,
    additional_service_index,
):
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

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    for index, extra_arg in enumerate(spamoor_params.extra_args):
        cmd.append(extra_arg)

    return ServiceConfig(
        image=spamoor_params.image,
        entrypoint=["./spamoor-daemon"],
        cmd=cmd,
        ports=USED_PORTS,
        public_ports=public_ports,
        min_cpu=spamoor_params.min_cpu,
        max_cpu=spamoor_params.max_cpu,
        min_memory=spamoor_params.min_mem,
        max_memory=spamoor_params.max_mem,
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
