shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "cadvisor"

HTTP_PORT_NUMBER = 8080
USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

IMAGE_NAME = "gcr.io/cadvisor/cadvisor:v0.38.7"


def launch_cadvisor(
    plan,
    port_publisher,
    additional_service_index,
    global_node_selectors,
):
    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )
    files = {"/var/run/docker.sock": "/var/run/docker.sock"}

    config = ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        public_ports=public_ports,
        node_selectors=global_node_selectors,
        files=files,
    )

    plan.add_service(SERVICE_NAME, config)
