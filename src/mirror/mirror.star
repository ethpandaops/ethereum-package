shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
SERVICE_NAME = "mirror"
HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 5050

# MIN_CPU = 100
# MAX_CPU = 300
# MIN_MEMORY = 128
# MAX_MEMORY = 256

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_mirror(
    plan,
    mirror_port,
    participant_contexts,
    participant_configs,
    mirror_params,
    port_publisher,
    index,
    global_node_selectors,
    global_tolerations,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        0,
    )

    # all_cl_client_info = []
    # for index, participant in enumerate(participant_contexts):
    #     _, cl_client, _, _ = shared_utils.get_client_names(
    #         participant, index, participant_contexts, participant_configs
    #     )

    if mirror_port != None:
        public_ports = {
            HTTP_PORT_ID: shared_utils.new_port_spec(
                mirror_port, shared_utils.TCP_PROTOCOL
            )
        }

    config = get_config(
        mirror_params,
        public_ports,
        global_node_selectors,
        tolerations,
        docker_cache_params,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    mirror_params,
    public_ports,
    node_selectors,
    tolerations,
    docker_cache_params,
):
    cmd = []

    return ServiceConfig(
        image=mirror_params.image,
        ports=USED_PORTS,
        public_ports=public_ports,
        cmd=cmd,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )
