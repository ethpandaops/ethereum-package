shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME_PREFIX = "zkboost"

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
    ),
}


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
    tempo_otlp_grpc_url=None,
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
                "ProofTimeoutSecs": zkvm.get("proof_timeout_secs", 12),
            }
            if zkvm["kind"] == "ere":
                fail("TODO: Ere zkvm kind is not yet supported")
            elif zkvm["kind"] == "mock":
                mock_proving_time = zkvm.get(
                    "mock_proving_time", {"kind": "constant", "ms": 6000}
                )
                entry["MockProvingTimeKind"] = mock_proving_time.get("kind", "constant")
                entry["MockProvingTimeConstantMs"] = mock_proving_time.get("ms", 0)
                entry["MockProvingTimeRandomMinMs"] = mock_proving_time.get("min_ms", 0)
                entry["MockProvingTimeRandomMaxMs"] = mock_proving_time.get("max_ms", 0)
                entry["MockProvingTimeLinearMsPerMgas"] = mock_proving_time.get(
                    "ms_per_mgas", 0
                )
                entry["MockProofSize"] = zkvm.get("mock_proof_size", 128 << 10)
                entry["MockFailure"] = zkvm.get("mock_failure", False)
            zkvms.append(entry)

        template_data = {
            "Port": HTTP_PORT_NUMBER,
            "ELEndpoint": el_endpoint,
            "WitnessTimeoutSecs": 12,
            "WitnessCacheSize": 128,
            "ProofCacheSize": 128,
            "DashboardEnabled": zkboost_params.dashboard_enabled,
            "DashboardRetention": 256,
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
            tempo_otlp_grpc_url,
        )

        plan.add_service(name, config)
        metrics_jobs.append(get_metrics_job(name))

    return metrics_jobs


def get_metrics_job(service_name):
    return {
        "Name": service_name,
        "Endpoint": "{0}:{1}".format(service_name, HTTP_PORT_NUMBER),
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
    tempo_otlp_grpc_url,
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

    env_vars = dict(zkboost_params.env)
    if tempo_otlp_grpc_url != None:
        env_vars["OTEL_EXPORTER_OTLP_ENDPOINT"] = tempo_otlp_grpc_url
        env_vars["OTEL_SERVICE_NAME"] = service_name

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            zkboost_params.image,
        ),
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            ZKBOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        entrypoint=["/usr/local/bin/zkboost"],
        cmd=["--config", config_file_path],
        env_vars=env_vars,
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
