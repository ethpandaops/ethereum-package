shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "cadvisor"
HTTP_PORT_NUMBER = 8080
METRICS_PATH = "/metrics"

DOCKER_SOCKET_PATH = "/var/run/docker.sock"

# Kurtosis only permits the docker socket as a host bind mount. Combined with
# privileged mode and the host PID namespace, cAdvisor reads container metrics
# via the docker socket and the host cgroup hierarchy.
CADVISOR_BIND_MOUNTS = {
    DOCKER_SOCKET_PATH: DOCKER_SOCKET_PATH,
}

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}


def launch_cadvisor(
    plan,
    cadvisor_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    config = get_config(
        cadvisor_params,
        global_node_selectors,
        tolerations,
        port_publisher,
        additional_service_index,
        docker_cache_params,
    )
    plan.add_service(SERVICE_NAME, config)

    return get_metrics_job()


def get_config(
    cadvisor_params,
    node_selectors,
    tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    config_args = {
        "image": shared_utils.docker_cache_image_calc(
            docker_cache_params,
            cadvisor_params.image,
        ),
        "ports": USED_PORTS,
        "public_ports": public_ports,
        # cAdvisor needs privileged access, the host docker socket, and the host
        # PID namespace to collect per-container metrics. This is why cadvisor is
        # Docker-backend only (guarded in main.star).
        "privileged": True,
        "host_pid_namespace": True,
        "bind_mounts": CADVISOR_BIND_MOUNTS,
        "min_cpu": cadvisor_params.min_cpu,
        "max_cpu": cadvisor_params.max_cpu,
        "min_memory": cadvisor_params.min_mem,
        "max_memory": cadvisor_params.max_mem,
        "node_selectors": node_selectors,
        "tolerations": tolerations,
    }

    return ServiceConfig(**config_args)


def get_metrics_job():
    return {
        "Name": SERVICE_NAME,
        "Endpoint": "{0}:{1}".format(SERVICE_NAME, HTTP_PORT_NUMBER),
        "MetricsPath": METRICS_PATH,
        "Labels": {
            "service": SERVICE_NAME,
            "client_type": SERVICE_NAME,
        },
        "ScrapeInterval": "15s",
    }
