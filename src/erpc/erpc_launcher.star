shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
SERVICE_NAME = "erpc"

HTTP_PORT_NUMBER = 4000
METRICS_PORT_NUMBER = 4001

ERPC_CONFIG_FILENAME = "erpc.yaml"

ERPC_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/root"

IMAGE_NAME = "ghcr.io/erpc/erpc:latest"

MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 2048

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    constants.METRICS_PORT_ID: shared_utils.new_port_spec(
        METRICS_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}


def launch_erpc(
    plan,
    config_template,
    participant_contexts,
    participant_configs,
    network_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    all_el_client_info = []
    for index, participant in enumerate(participant_contexts):
        full_name, _, el_client, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )
        all_el_client_info.append(
            new_el_client_info(
                el_client.ip_addr,
                el_client.rpc_port_num,
                el_client.ws_port_num,
                full_name,
            )
        )

    template_data = new_config_template_data(
        network_params.network,
        network_params.network_id,
        HTTP_PORT_NUMBER,
        METRICS_PORT_NUMBER,
        all_el_client_info,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[ERPC_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "erpc-config"
    )

    config = get_config(
        config_files_artifact_name,
        network_params,
        global_node_selectors,
        tolerations,
        port_publisher,
        additional_service_index,
        docker_cache_params,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    network_params,
    node_selectors,
    tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    config_file_path = shared_utils.path_join(
        ERPC_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        ERPC_CONFIG_FILENAME,
    )

    public_ports = {}
    if port_publisher.additional_services_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "additional_services", port_publisher, additional_service_index
        )
        public_port_assignments = {
            constants.HTTP_PORT_ID: public_ports_for_component[0],
            constants.METRICS_PORT_ID: public_ports_for_component[1],
        }
        public_ports = shared_utils.get_port_specs(public_port_assignments)

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            IMAGE_NAME,
        ),
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            ERPC_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=["/erpc-server", config_file_path],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
        ready_conditions=ReadyCondition(
            recipe=PostHttpRequestRecipe(
                port_id="http",
                endpoint="/",
                content_type="application/json",
                body='{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}',
            ),
            field="code",
            assertion="==",
            target_value=200,
        ),
    )


def new_config_template_data(
    network, network_id, http_port, metrics_port, el_client_info
):
    return {
        "Network": network,
        "NetworkID": network_id,
        "HTTPPort": http_port,
        "MetricsPort": metrics_port,
        "ELClientInfo": el_client_info,
    }


def new_el_client_info(ip_addr, rpc_port_num, ws_port_num, full_name):
    return {
        "IP_Addr": ip_addr,
        "RPC_PortNum": rpc_port_num,
        "WS_PortNum": ws_port_num,
        "FullName": full_name,
    }
