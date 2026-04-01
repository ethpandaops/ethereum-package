shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME_PREFIX = "zkboost"

ZKBOOST_CONFIG_FILENAME = "config.toml"

ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 256
MAX_MEMORY = 2048


def launch_zkboost(
    plan,
    config_template,
    participant_contexts,
    zkboost_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    metrics_jobs = []
    for instance_index, instance in enumerate(zkboost_params.instances):
        name = instance["name"]
        el_participant_index = instance["el_participant_index"]

        if el_participant_index >= len(participant_contexts):
            fail(
                "zkboost instance '{0}' references el_participant_index {1} but only {2} participants exist".format(
                    name, el_participant_index, len(participant_contexts)
                )
            )

        el_client = participant_contexts[el_participant_index].el_context
        el_endpoint = "http://{0}:{1}".format(
            el_client.dns_name, el_client.rpc_port_num
        )

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
            "Port": zkboost_params.port,
            "ELEndpoint": el_endpoint,
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
        template_and_data_by_rel_dest_filepath[
            ZKBOOST_CONFIG_FILENAME
        ] = template_and_data

        config_files_artifact_name = plan.render_templates(
            template_and_data_by_rel_dest_filepath, name + "-config"
        )
        config = get_config(
            name,
            config_files_artifact_name,
            zkboost_params,
            global_node_selectors,
            tolerations,
            port_publisher,
            additional_service_index + instance_index,
            docker_cache_params,
        )

        plan.add_service(name, config)
        metrics_jobs.append(get_metrics_job(name, zkboost_params.port))

    return metrics_jobs


def get_metrics_job(service_name, port):
    return {
        "Name": service_name,
        "Endpoint": "{0}:{1}".format(service_name, port),
        "MetricsPath": "/metrics",
        "Labels": {
            "service": service_name,
            "client_type": SERVICE_NAME_PREFIX,
        },
        "ScrapeInterval": "15s",
    }


def get_config(
    service_name,
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

    used_ports = {
        constants.HTTP_PORT_ID: shared_utils.new_port_spec(
            zkboost_params.port,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
            wait=None,
        )
    }

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
        ports=used_ports,
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
