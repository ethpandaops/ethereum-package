shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
SERVICE_NAME = "spamoor"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 8080

SPAMOOR_CONFIG_FILENAME = "startup-spammers.yaml"
SPAMOOR_HOSTS_FILENAME = "rpc-hosts.txt"

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
    hosts_template,
    prefunded_addresses,
    participant_contexts,
    participant_configs,
    spamoor_params,
    global_node_selectors,
    global_tolerations,
    network_params,
    port_publisher,
    additional_service_index,
    osaka_time,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

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
                        "deploy_client_group": "default",
                    },
                }
            )

    template_and_data_by_rel_dest_filepath = {}

    config_template_data = new_config_template_data(spammers)
    config_template_and_data = shared_utils.new_template_and_data(
        config_template, config_template_data
    )
    template_and_data_by_rel_dest_filepath[
        SPAMOOR_CONFIG_FILENAME
    ] = config_template_and_data

    hosts_template_data = new_hosts_template_data(
        participant_contexts, participant_configs
    )
    hosts_template_and_data = shared_utils.new_template_and_data(
        hosts_template, hosts_template_data
    )
    template_and_data_by_rel_dest_filepath[
        SPAMOOR_HOSTS_FILENAME
    ] = hosts_template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "spamoor-config"
    )

    config = get_config(
        plan,
        config_files_artifact_name,
        prefunded_addresses,
        spamoor_params,
        global_node_selectors,
        tolerations,
        network_params,
        port_publisher,
        additional_service_index,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    plan,
    config_files_artifact_name,
    prefunded_addresses,
    spamoor_params,
    node_selectors,
    tolerations,
    network_params,
    port_publisher,
    additional_service_index,
):
    config_file_path = shared_utils.path_join(
        SPAMOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        SPAMOOR_CONFIG_FILENAME,
    )

    hosts_file_path = shared_utils.path_join(
        SPAMOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        SPAMOOR_HOSTS_FILENAME,
    )

    cmd = [
        "--privkey={}".format(prefunded_addresses[13].private_key),
        "--rpchost-file={}".format(hosts_file_path),
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
        tolerations=tolerations,
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


def new_hosts_template_data(
    participant_contexts,
    participant_configs,
):
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
        if participant.snooper_el_rpc_context:
            rpchost = "http://{0}:{1}".format(
                participant.snooper_el_rpc_context.ip_addr,
                participant.snooper_el_rpc_context.rpc_port_num,
            )
        else:
            rpchost = "http://{0}:{1}".format(
                el_client.ip_addr,
                el_client.rpc_port_num,
            )

        index_str = shared_utils.zfill_custom(
            index + 1, len(str(len(participant_contexts)))
        )
        rpchost = (
            "group({0},{1},{2})name({3})".format(
                index_str,
                cl_client.client_name,
                el_client.client_name,
                full_name,
            )
            + rpchost
        )

        if "builder" in full_name:
            rpchost = "group(mevbuilder)" + rpchost

        rpchosts.append(rpchost)

    return {
        "RPCHosts": rpchosts,
    }
