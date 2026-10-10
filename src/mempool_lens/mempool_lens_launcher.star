shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "mempool-lens"
HTTP_PORT_NUMBER = 8670

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

# The lens is a thin WS proxy + static UI
MIN_CPU = 10
MAX_CPU = 500
MIN_MEMORY = 64
MAX_MEMORY = 512


def launch_mempool_lens(
    plan,
    all_el_contexts,
    mempool_lens_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    rpc_url = _resolve_rpc_url(mempool_lens_params, all_el_contexts)

    config = get_config(
        mempool_lens_params,
        rpc_url,
        global_node_selectors,
        tolerations,
        port_publisher,
        additional_service_index,
        docker_cache_params,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    mempool_lens_params,
    rpc_url,
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

    cmd = [
        "--addr=0.0.0.0:{0}".format(HTTP_PORT_NUMBER),
        "--rpc={0}".format(rpc_url),
        "--proxy",
    ]
    if len(mempool_lens_params.extra_args) > 0:
        cmd.extend(mempool_lens_params.extra_args)

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            mempool_lens_params.image,
        ),
        ports=USED_PORTS,
        public_ports=public_ports,
        cmd=cmd,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )


def _resolve_rpc_url(mempool_lens_params, all_el_contexts):
    if mempool_lens_params.target_rpc_url:
        return mempool_lens_params.target_rpc_url

    if len(all_el_contexts) == 0:
        fail("mempool-lens requires at least one EL client or target_rpc_url")

    idx = mempool_lens_params.target_index
    if idx >= 0:
        if idx >= len(all_el_contexts):
            fail(
                "mempool-lens target_index {0} out of range (0..{1})".format(
                    idx, len(all_el_contexts) - 1
                )
            )
        el = all_el_contexts[idx]
        if not el.ws_url:
            fail(
                "mempool-lens target_index {0} ({1}) does not expose a WS endpoint".format(
                    idx, el.service_name
                )
            )
        return el.ws_url

    # Auto-select: prefer a geth node (the txtracker/peerstats namespaces are
    # a geth patch), otherwise the first EL exposing a WS endpoint.
    for el in all_el_contexts:
        if el.client_name == constants.EL_TYPE.geth and el.ws_url:
            return el.ws_url
    for el in all_el_contexts:
        if el.ws_url:
            return el.ws_url
    fail("mempool-lens found no EL client exposing a WS endpoint; set target_rpc_url")
