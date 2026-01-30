shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "ews"
ZKBOOST_SERVICE_NAME = "zkboost"

HTTP_PORT_NUMBER = 3000
ZKBOOST_HTTP_PORT_NUMBER = 3000

EWS_CONFIG_FILENAME = "config.toml"
ZKBOOST_CONFIG_FILENAME = "zkboost-config.toml"

EWS_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"
ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 256
MAX_MEMORY = 2048

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
        wait=None,
    )
}

ZKBOOST_USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        ZKBOOST_HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
        wait=None,
    )
}


def launch_ews(
    plan,
    config_template,
    zkboost_config_template,
    participant_contexts,
    participant_configs,
    network_params,
    ews_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    first_real_el_info = None
    head_subscription_cl_info = None
    dummy_cl_client_info = []

    for index, participant in enumerate(participant_contexts):
        full_name, cl_client, el_client, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )
        el_type = participant_configs[index].el_type

        if el_type == "dummy":
            dummy_cl_client_info.append(
                new_cl_client_info(
                    full_name,
                    cl_client.beacon_http_url,
                )
            )
        else:
            if first_real_el_info == None:
                first_real_el_info = new_el_client_info(
                    full_name,
                    "http://{0}:{1}".format(el_client.dns_name, el_client.rpc_port_num),
                    "ws://{0}:{1}".format(el_client.dns_name, el_client.ws_port_num),
                )
                head_subscription_cl_info = new_cl_client_info(
                    full_name,
                    cl_client.beacon_http_url,
                )

    zkboost_info = new_zkboost_info(
        "http://{0}:{1}".format(ZKBOOST_SERVICE_NAME, ZKBOOST_HTTP_PORT_NUMBER),
    )

    template_data = new_config_template_data(
        network_params.network,
        ews_params.retain,
        ews_params.num_proofs,
        first_real_el_info,
        head_subscription_cl_info,
        dummy_cl_client_info,
        zkboost_info,
        ews_params.proof_types,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[EWS_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "ews-config"
    )
    config = get_config(
        config_files_artifact_name,
        ews_params,
        global_node_selectors,
        tolerations,
        port_publisher,
        additional_service_index,
        docker_cache_params,
    )

    plan.add_service(SERVICE_NAME, config)

    launch_zkboost(
        plan,
        zkboost_config_template,
        ews_params,
        global_node_selectors,
        tolerations,
        docker_cache_params,
    )


def get_config(
    config_files_artifact_name,
    ews_params,
    node_selectors,
    tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    config_file_path = shared_utils.path_join(
        EWS_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        EWS_CONFIG_FILENAME,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    IMAGE_NAME = shared_utils.docker_cache_image_calc(
        docker_cache_params,
        ews_params.image,
    )

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            EWS_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        entrypoint=["/usr/local/bin/execution-witness-sentry"],
        cmd=["--config", config_file_path],
        env_vars=ews_params.env,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
        ready_conditions=ReadyCondition(
            recipe=GetHttpRequestRecipe(
                port_id=constants.HTTP_PORT_ID,
                endpoint="/health",
            ),
            field="code",
            assertion="==",
            target_value=200,
        ),
    )


def launch_zkboost(
    plan,
    zkboost_config_template,
    ews_params,
    node_selectors,
    tolerations,
    docker_cache_params,
):
    ews_info = new_ews_info(
        "http://{0}:{1}".format(SERVICE_NAME, HTTP_PORT_NUMBER),
    )

    zkvms = []
    for zkvm in ews_params.zkboost.zkvms:
        zkvms.append(new_zkvm_info(zkvm))

    zkboost_template_data = new_zkboost_config_template_data(ews_info, zkvms)

    template_and_data = shared_utils.new_template_and_data(
        zkboost_config_template, zkboost_template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[ZKBOOST_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "zkboost-config"
    )

    config_file_path = shared_utils.path_join(
        ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        ZKBOOST_CONFIG_FILENAME,
    )

    IMAGE_NAME = shared_utils.docker_cache_image_calc(
        docker_cache_params,
        ews_params.zkboost.image,
    )

    config = ServiceConfig(
        image=IMAGE_NAME,
        ports=ZKBOOST_USED_PORTS,
        files={
            ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        entrypoint=["/usr/local/bin/zkboost-server"],
        cmd=["--config", config_file_path],
        env_vars=ews_params.zkboost.env,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
        ready_conditions=ReadyCondition(
            recipe=GetHttpRequestRecipe(
                port_id=constants.HTTP_PORT_ID,
                endpoint="/health",
            ),
            field="code",
            assertion="==",
            target_value=200,
        ),
    )

    plan.add_service(ZKBOOST_SERVICE_NAME, config)


def new_config_template_data(
    network,
    retain,
    num_proofs,
    el_client_info,
    head_subscription_cl_info,
    zkvm_cl_client_info,
    zkboost_info,
    proof_types,
):
    return {
        "Network": network,
        "Retain": retain,
        "NumProofs": num_proofs,
        "ELClientInfo": el_client_info,
        "HeadSubscriptionCLInfo": head_subscription_cl_info,
        "ZkvmCLClientInfo": zkvm_cl_client_info,
        "ZkboostInfo": zkboost_info,
        "ProofTypes": proof_types,
    }


def new_zkboost_config_template_data(ews_info, zkvms):
    return {
        "EWSInfo": ews_info,
        "Zkvms": zkvms,
    }


def new_zkboost_info(http_url):
    return {
        "HTTP_URL": http_url,
    }


def new_ews_info(http_url):
    return {
        "HTTP_URL": http_url,
    }


def new_zkvm_info(zkvm):
    info = {
        "ProgramId": zkvm.get("program_id", ""),
    }
    if zkvm.get("endpoint"):
        info["Endpoint"] = zkvm["endpoint"]
    if zkvm.get("mock_proving_time_ms"):
        info["MockProvingTimeMs"] = zkvm["mock_proving_time_ms"]
    if zkvm.get("mock_proof_size"):
        info["MockProofSize"] = zkvm["mock_proof_size"]
    return info


def new_el_client_info(full_name, el_http_url, el_ws_url):
    return {
        "FullName": full_name,
        "EL_HTTP_URL": el_http_url,
        "EL_WS_URL": el_ws_url,
    }


def new_cl_client_info(full_name, cl_http_url):
    return {
        "FullName": full_name,
        "CL_HTTP_URL": cl_http_url,
    }
