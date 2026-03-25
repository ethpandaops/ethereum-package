shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "zkboost"

HTTP_PORT_NUMBER = 3000

ZKBOOST_CONFIG_FILENAME = "config.toml"

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


def launch_zkboost(
    plan,
    config_template,
    participant_contexts,
    participant_configs,
    zkboost_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    first_real_el_endpoint = None
    for index, participant in enumerate(participant_contexts):
        el_type = participant_configs[index].el_type
        if el_type != "dummy":
            el_client = participant.el_context
            first_real_el_endpoint = "http://{0}:{1}".format(
                el_client.dns_name, el_client.rpc_port_num
            )
            break

    zkvms = []
    for zkvm in zkboost_params.zkvms:
        entry = {
            "Kind": zkvm["kind"],
            "ProofType": zkvm["proof_type"],
        }
        if zkvm["kind"] == "external":
            fail("TODO: external zkvm kind is not yet supported")
        elif zkvm["kind"] == "mock":
            entry["MockProvingTimeMs"] = zkvm.get("mock_proving_time_ms", 5000)
            entry["MockProofSize"] = zkvm.get("mock_proof_size", 1024)
        zkvms.append(entry)

    template_data = {
        "ELEndpoint": first_real_el_endpoint,
        "WitnessTimeoutSecs": zkboost_params.witness_timeout_secs,
        "ProofTimeoutSecs": zkboost_params.proof_timeout_secs,
        "WitnessCacheSize": zkboost_params.witness_cache_size,
        "ProofCacheSize": zkboost_params.proof_cache_size,
        "Zkvms": zkvms,
    }

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[ZKBOOST_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "zkboost-config"
    )
    config = get_config(
        config_files_artifact_name,
        zkboost_params,
        global_node_selectors,
        tolerations,
        port_publisher,
        additional_service_index,
        docker_cache_params,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    zkboost_params,
    node_selectors,
    tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    config_file_path = shared_utils.path_join(
        ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        ZKBOOST_CONFIG_FILENAME,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    IMAGE_NAME = shared_utils.docker_cache_image_calc(
        docker_cache_params,
        zkboost_params.image,
    )

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        entrypoint=["/usr/local/bin/zkboost-server"],
        cmd=["--config", config_file_path],
        env_vars=zkboost_params.env,
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
