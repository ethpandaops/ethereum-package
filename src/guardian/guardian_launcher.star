shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME_PREFIX = "guardian"
DEFAULT_IMAGE = "bbusa/das:latest"

# The min/max CPU/memory that guardian can use
MIN_CPU = 100
MAX_CPU = 500
MIN_MEMORY = 128
MAX_MEMORY = 512

# No ports needed as this is a one-shot scanning tool
USED_PORTS = {}


def launch_guardian(
    plan,
    participant_contexts,
    participant_configs,
    network_params,
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

        service_name = "{0}-{1}".format(SERVICE_NAME_PREFIX, index)

        config = get_config(
            service_name,
            cl_client.beacon_http_url,
            cl_client.enr,
            global_node_selectors,
            docker_cache_params,
        )

        plan.add_service(service_name, config)
        guardian_services.append(service_name)

        plan.print("Launched guardian instance {0} for beacon node {1} (ENR: {2})".format(
            service_name,
            full_name,
            cl_client.enr[:50] + "..." if len(cl_client.enr) > 50 else cl_client.enr
        ))

    plan.print("Successfully launched {0} DAS Guardian instances".format(len(guardian_services)))
    return guardian_services


def get_config(
    service_name,
    beacon_api_url,
    node_enr,
    node_selectors,
    docker_cache_params,
):
    cmd = [
        "--api.endpoint", beacon_api_url,
        "--libp2p.host", "0.0.0.0",
        "--libp2p.port", "9013",
        "--node.key", node_enr,
        "--connection.retries", "5",
        "--connection.timeout", "30s"
    ]

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            DEFAULT_IMAGE,
        ),
        ports=USED_PORTS,
        cmd=cmd,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
