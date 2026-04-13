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

ERE_SERVER_HTTP_PORT_ID = "http"
ERE_SERVER_DEFAULT_PORT = 3000
ERE_SERVER_PROGRAMS_DIRPATH = "/programs"
ERE_SERVER_READY_TIMEOUT = "600s"
ERE_SERVER_READY_INTERVAL = "10s"


def _validate_ere_gpu_config(zkvms):
    """Validate that at most one ere zkvm uses gpu.count without gpu.device_ids.

    When gpu.count is specified without device_ids, Docker draws from the same shared
    GPU pool for every service that does this — resulting in the same physical GPU(s)
    being assigned to multiple containers. If more than one ere service needs a GPU,
    each one must use gpu.device_ids to pin it to a distinct set of devices.
    """
    services_using_count = []
    for zkvm in zkvms:
        if zkvm["kind"] != "ere":
            continue
        gpu_cfg = zkvm.get("gpu", {})
        count = gpu_cfg.get("count", 0)
        device_ids = gpu_cfg.get("device_ids", [])
        if count > 0 and len(device_ids) == 0:
            services_using_count.append(zkvm["proof_type"])

    if len(services_using_count) > 1:
        fail(
            "Multiple ere services specify gpu.count without gpu.device_ids: [{0}]. ".format(
                ", ".join(services_using_count)
            )
            + "Docker assigns GPUs from the same pool when gpu.count is used, so all services "
            + "requesting GPUs this way will receive the same device(s). "
            + "Use gpu.device_ids to explicitly assign distinct GPU(s) to each service instead "
            + '(e.g. gpu: {{device_ids: ["0"]}} and gpu: {{device_ids: ["1"]}}).'
        )


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
    _validate_ere_gpu_config(zkboost_params.zkvms)

    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Launch ere-server services once — shared across all zkboost instances.
    # Each `ere` zkvm entry results in a single long-lived service; all zkboost
    # instances reference it as an endpoint.
    ere_server_endpoints = {}
    for zkvm in zkboost_params.zkvms:
        if zkvm["kind"] == "ere":
            proof_type = zkvm["proof_type"]
            if proof_type not in ere_server_endpoints:
                endpoint = _launch_ere_server(
                    plan, zkvm, global_node_selectors, tolerations
                )
                ere_server_endpoints[proof_type] = endpoint

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
                entry["Endpoint"] = ere_server_endpoints[zkvm["proof_type"]]
            elif zkvm["kind"] == "external":
                entry[
                    "Kind"
                ] = "ere"  # zkboost config kind for any external prover connection
                entry["Endpoint"] = zkvm["endpoint"]
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


def _launch_ere_server(plan, zkvm, global_node_selectors, tolerations):
    """Launch an ere-server-zisk GPU prover service and return its HTTP endpoint.

    If 'program_url' is specified, the program binary is downloaded via a
    preparation task and mounted into the service at ERE_SERVER_PROGRAMS_DIRPATH.
    """
    proof_type = zkvm["proof_type"]
    service_name = "ere-server-{0}".format(proof_type)
    port = zkvm.get("port", ERE_SERVER_DEFAULT_PORT)

    # Download program binary if a URL is provided
    files = {}
    if "program_url" in zkvm:
        program_url = zkvm["program_url"]
        binary_name = program_url.split("/")[-1]
        artifact_name = service_name + "-program"
        plan.run_sh(
            name="download-" + service_name,
            description="Downloading {0} program binary".format(proof_type),
            run="mkdir -p /programs && wget -q -O /programs/{0} {1} && chmod +x /programs/{0}".format(
                binary_name, program_url
            ),
            image="alpine:latest",
            store=[StoreSpec(src="/programs", name=artifact_name)],
        )
        files[ERE_SERVER_PROGRAMS_DIRPATH] = artifact_name
        program_path = "{0}/{1}".format(ERE_SERVER_PROGRAMS_DIRPATH, binary_name)
    else:
        program_path = zkvm.get("program_path", "")
        if program_path == "":
            fail(
                "ere zkvm '{0}' requires either 'program_url' or 'program_path'".format(
                    proof_type
                )
            )

    used_ports = {
        ERE_SERVER_HTTP_PORT_ID: shared_utils.new_port_spec(
            port,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
            wait=None,
        )
    }

    env_vars = dict(zkvm.get("env", {}))

    plan.add_service(
        name=service_name,
        config=ServiceConfig(
            image=zkvm["image"],
            ports=used_ports,
            files=files,
            cmd=["--port", "{0}".format(port), "--program-path", program_path, "gpu"],
            env_vars=env_vars,
            gpu=GpuConfig(
                count=zkvm.get("gpu", {}).get("count", 0),
                device_ids=zkvm.get("gpu", {}).get("device_ids", []),
                shm_size=zkvm.get("gpu", {}).get("shm_size", 0),
                ulimits=zkvm.get("gpu", {}).get("ulimits", {}),
                driver=zkvm.get("gpu", {}).get("driver", "nvidia"),
            ),
            node_selectors=global_node_selectors,
            tolerations=tolerations,
            ready_conditions=ReadyCondition(
                recipe=GetHttpRequestRecipe(
                    port_id=ERE_SERVER_HTTP_PORT_ID,
                    endpoint="/health",
                ),
                field="code",
                assertion="==",
                target_value=200,
                timeout=ERE_SERVER_READY_TIMEOUT,
                interval=ERE_SERVER_READY_INTERVAL,
            ),
        ),
    )

    return "http://{0}:{1}".format(service_name, port)
