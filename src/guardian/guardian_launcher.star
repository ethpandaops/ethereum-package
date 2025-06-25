shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME_PREFIX = "guardian"
HTTP_PORT_NUMBER = 9013
WEB_PORT_NUMBER = 8080

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    constants.WEB_PORT_ID: shared_utils.new_port_spec(
        WEB_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_guardian(
    plan,
    participant_contexts,
    participant_configs,
    network_params,
    guardian_params,
    global_node_selectors,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    plan.print("Launching DAS Guardian instances for each beacon node...")

    guardian_services = []

    for index, participant in enumerate(participant_contexts):
        full_name, cl_client, el_client, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )

        service_name = "{0}-{1}".format(SERVICE_NAME_PREFIX, index + 1)

        config = get_config(
            service_name,
            cl_client.beacon_http_url,
            cl_client.enr,
            guardian_params,
            global_node_selectors,
            docker_cache_params,
        )

        plan.add_service(service_name, config)
        guardian_services.append(service_name)

        plan.print(
            "Launched guardian instance {0} for beacon node {1} (ENR: {2})".format(
                service_name,
                full_name,
                cl_client.enr[:50] + "..."
                if len(cl_client.enr) > 50
                else cl_client.enr,
            )
        )

    plan.print(
        "Successfully launched {0} DAS Guardian instances".format(
            len(guardian_services)
        )
    )
    return guardian_services


def get_config(
    service_name,
    beacon_api_url,
    node_enr,
    guardian_params,
    node_selectors,
    docker_cache_params,
):
    cmd = [
        "--api.endpoint",
        beacon_api_url,
        "--libp2p.host",
        "0.0.0.0",
        "--libp2p.port",
        "9013",
        "--node.key",
        node_enr,
        "--connection.retries",
        "5",
        "--connection.timeout",
        "30s",
        "--web.mode",
        "--web.port",
        WEB_PORT_NUMBER,
    ]

    if len(guardian_params.extra_args) > 0:
        cmd.extend([param for param in guardian_params.extra_args])

    return ServiceConfig(
        image=guardian_params.image,
        ports=USED_PORTS,
        cmd=cmd,
        min_cpu=guardian_params.min_cpu,
        max_cpu=guardian_params.max_cpu,
        min_memory=guardian_params.min_mem,
        max_memory=guardian_params.max_mem,
        node_selectors=node_selectors,
    )
