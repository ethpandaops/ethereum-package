shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME_PREFIX = "ere-server"
HTTP_PORT_NUMBER = 3000

PROGRAMS_MOUNT_PATH = "/programs"

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
        wait=None,
    )
}

MIN_CPU = 100
MAX_CPU = 0
MIN_MEMORY = 256
MAX_MEMORY = 0


def launch_ere_server(
    plan,
    program_id,
    ere_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    service_name = "{0}-{1}".format(SERVICE_NAME_PREFIX, program_id)
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Download the program binary
    program_filename = "stateless-validator-{0}".format(program_id)
    program_artifact_name = "ere-program-{0}".format(program_id)
    plan.run_sh(
        name="download-ere-program-{0}".format(program_id),
        description="Downloading ERE program binary for {0}".format(program_id),
        run="mkdir -p /programs && curl -fsSL '{0}' -o /programs/{1}".format(
            ere_params.program_url, program_filename
        ),
        store=[StoreSpec(src="/programs/", name=program_artifact_name)],
        image="alpine/curl:latest",
        tolerations=tolerations,
        node_selectors=global_node_selectors,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    IMAGE_NAME = shared_utils.docker_cache_image_calc(
        docker_cache_params,
        ere_params.image,
    )

    # Determine GPU devices - explicit gpu_devices takes priority over gpu_count
    devices = []
    resource_type = "cpu"
    if len(ere_params.gpu_devices) > 0:
        resource_type = "gpu"
        devices = list(ere_params.gpu_devices)
    elif ere_params.gpu_count > 0:
        resource_type = "gpu"
        for i in range(ere_params.gpu_count):
            devices.append("/dev/nvidia{0}".format(i))
        devices.append("/dev/nvidiactl")
        devices.append("/dev/nvidia-uvm")

    program_path = "{0}/{1}".format(PROGRAMS_MOUNT_PATH, program_filename)

    config = ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            PROGRAMS_MOUNT_PATH: program_artifact_name,
        },
        entrypoint=["sh", "-c"],
        cmd=[
            # Create a nice wrapper that skips priority setting (SYS_NICE not available in container)
            # nice is called as: nice -5 cmd args... or nice -n 5 cmd args...
            "printf '#!/bin/sh\\nwhile [ $# -gt 0 ]; do case \"$1\" in -n) shift 2;; -*) shift;; *) break;; esac; done\\nexec \"$@\"\\n' > /usr/local/bin/nice && chmod +x /usr/local/bin/nice && "
            + "exec /ere/bin/ere-server --port {0} --program-path {1} {2}".format(
                str(HTTP_PORT_NUMBER), program_path, resource_type
            ),
        ],
        env_vars=ere_params.env,
        devices=devices if devices else [],
        node_selectors=global_node_selectors,
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

    plan.add_service(service_name, config)
    return "http://{0}:{1}".format(service_name, HTTP_PORT_NUMBER)
