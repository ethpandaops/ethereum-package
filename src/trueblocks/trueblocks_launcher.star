shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "trueblocks"

HTTP_PORT_NUMBER = 8080

TRUEBLOCKS_CONFIG_FILENAME = "trueBlocks.toml"
TRUEBLOCKS_CONFIG_STAGING_DIRPATH = "/tb-config"

MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 2048

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

_PUBLIC_SCRAPE_PARAMS = {
    "apps_per_chunk": 2000000,
    "snap_to_grid": 100000,
    "first_snap": 2300000,
    "unripe_dist": 28,
}
_DEVNET_SCRAPE_PARAMS = {
    "apps_per_chunk": 200,
    "snap_to_grid": 100,
    "first_snap": 0,
    "unripe_dist": 1,
}


def launch_trueblocks(
    plan,
    config_template,
    all_el_contexts,
    network_params,
    trueblocks_params,
    prefunded_accounts,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    rpc_url = _resolve_rpc_url(trueblocks_params, all_el_contexts)
    scrape = _resolve_scrape_params(trueblocks_params, network_params.network)

    template_data = {
        "ChainName": network_params.network,
        "ChainId": str(network_params.network_id),
        "RpcProvider": rpc_url,
        "BlockTime": "{0}.0".format(network_params.seconds_per_slot),
        "AppsPerChunk": scrape["apps_per_chunk"],
        "SnapToGrid": scrape["snap_to_grid"],
        "FirstSnap": scrape["first_snap"],
        "UnripeDist": scrape["unripe_dist"],
    }
    config_files_artifact_name = plan.render_templates(
        {
            TRUEBLOCKS_CONFIG_FILENAME: shared_utils.new_template_and_data(
                config_template, template_data
            ),
        },
        "trueblocks-config",
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    probe_addr = prefunded_accounts[0].address if prefunded_accounts else ""

    env_vars = dict(trueblocks_params.env)
    env_vars["TB_CHAIN"] = network_params.network
    env_vars["TB_RPC_URL"] = rpc_url
    env_vars["TB_PROBE_ADDR"] = probe_addr.lower() if probe_addr else ""
    env_vars["TB_SCRAPE_SLEEP"] = str(trueblocks_params.scrape.sleep_seconds)
    env_vars["TB_HTTP_PORT"] = str(HTTP_PORT_NUMBER)
    env_vars["TB_CONFIG_STAGING"] = TRUEBLOCKS_CONFIG_STAGING_DIRPATH

    config = ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            trueblocks_params.image,
        ),
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            TRUEBLOCKS_CONFIG_STAGING_DIRPATH: config_files_artifact_name,
        },
        env_vars=env_vars,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=global_node_selectors,
        tolerations=tolerations,
        ready_conditions=ReadyCondition(
            recipe=GetHttpRequestRecipe(
                port_id=constants.HTTP_PORT_ID,
                endpoint="/status",
            ),
            field="code",
            assertion="==",
            target_value=200,
        ),
    )

    plan.add_service(SERVICE_NAME, config)


def _resolve_rpc_url(trueblocks_params, all_el_contexts):
    if trueblocks_params.target_rpc_url:
        return trueblocks_params.target_rpc_url

    if len(all_el_contexts) == 0:
        fail("trueblocks requires at least one EL client or target_rpc_url")

    idx = trueblocks_params.target_index
    if idx < 0 or idx >= len(all_el_contexts):
        fail(
            "trueblocks target_index {0} out of range (0..{1})".format(
                idx, len(all_el_contexts) - 1
            )
        )
    el = all_el_contexts[idx]
    if el == None:
        fail("trueblocks target_index {0} does not have an EL client".format(idx))
    return "http://{0}:{1}".format(el.dns_name, el.rpc_port_num)


def _resolve_scrape_params(trueblocks_params, network):
    defaults = (
        _PUBLIC_SCRAPE_PARAMS
        if network in constants.PUBLIC_NETWORKS
        else _DEVNET_SCRAPE_PARAMS
    )
    o = trueblocks_params.scrape
    return {
        "apps_per_chunk": o.apps_per_chunk
        if o.apps_per_chunk != 0
        else defaults["apps_per_chunk"],
        "snap_to_grid": o.snap_to_grid
        if o.snap_to_grid != 0
        else defaults["snap_to_grid"],
        "first_snap": o.first_snap if o.first_snap != 0 else defaults["first_snap"],
        "unripe_dist": o.unripe_dist if o.unripe_dist != 0 else defaults["unripe_dist"],
    }
