shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "trueblocks"

HTTP_PORT_NUMBER = 8080

TRUEBLOCKS_DATA_DIR = "/config"
TRUEBLOCKS_CONFIG_FILENAME = "trueBlocks.toml"

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

    toml_artifact = plan.render_templates(
        {
            TRUEBLOCKS_CONFIG_FILENAME: shared_utils.new_template_and_data(
                config_template,
                {
                    "ChainName": network_params.network,
                    "ChainId": str(network_params.network_id),
                    "RpcProvider": rpc_url,
                    "BlockTime": "{0}.0".format(network_params.seconds_per_slot),
                    "AppsPerChunk": scrape["apps_per_chunk"],
                    "SnapToGrid": scrape["snap_to_grid"],
                    "FirstSnap": scrape["first_snap"],
                    "UnripeDist": scrape["unripe_dist"],
                },
            ),
        },
        "trueblocks-toml",
    )

    image = shared_utils.docker_cache_image_calc(
        docker_cache_params,
        trueblocks_params.image,
    )
    data_artifact = _bootstrap_data_dir(
        plan,
        image,
        toml_artifact,
        network_params.network,
        rpc_url,
        prefunded_accounts[0].address.lower() if prefunded_accounts else "",
        global_node_selectors,
        tolerations,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    env_vars = dict(trueblocks_params.env)
    # Defensive: the image bakes this in, but set it here too so a
    # user-overridden image still reads from /config.
    env_vars["XDG_CONFIG_HOME"] = TRUEBLOCKS_DATA_DIR

    plan.add_service(
        SERVICE_NAME,
        ServiceConfig(
            image=image,
            ports=USED_PORTS,
            public_ports=public_ports,
            files={TRUEBLOCKS_DATA_DIR: data_artifact},
            cmd=["daemon", "--url", ":{0}".format(HTTP_PORT_NUMBER)],
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
        ),
    )


def _bootstrap_data_dir(
    plan,
    image,
    toml_artifact,
    chain,
    rpc_url,
    probe_addr,
    node_selectors,
    tolerations,
):
    # Assembles chifra's $XDG_DATA_HOME/trueblocks/ dir as a single files
    # artifact. Starts from the bundled per-chain configs in the image, drops
    # the rendered trueBlocks.toml in place, and (for chains that don't ship
    # a bundled allocs.csv) writes one keyed off the probe address's actual
    # block-0 balance — works around chifra IsNodeArchive (see
    # TrueBlocks/trueblocks-core#4044).
    run = (
        "set -eu; "
        + "cp -r {0} /out; ".format(TRUEBLOCKS_DATA_DIR)
        + "cp /tb-toml/{0} /out/{0}; ".format(TRUEBLOCKS_CONFIG_FILENAME)
        + "mkdir -p /out/config/$CHAIN; "
    )
    if probe_addr:
        run += (
            "if [ ! -f /out/config/$CHAIN/allocs.csv ]; then "
            + "  for i in $(seq 1 60); do "
            + "    BAL=$(curl -fsS -X POST -H 'Content-Type: application/json' "
            + '          -d "{\\"jsonrpc\\":\\"2.0\\",\\"method\\":\\"eth_getBalance\\",\\"params\\":[\\"$PROBE_ADDR\\",\\"0x0\\"],\\"id\\":1}" '
            + '          "$RPC_URL" 2>/dev/null | sed -n \'s/.*"result":"\\([^"]*\\)".*/\\1/p\'); '
            + "    echo \"$BAL\" | grep -qE '^0x[0-9a-fA-F]+$' && break; "
            + "    sleep 2; "
            + "  done; "
            + "  echo \"$BAL\" | grep -qE '^0x[0-9a-fA-F]+$' || { echo 'trueblocks: balance probe failed' >&2; exit 1; }; "
            + '  printf \'address,balance\\n%s,%s\\n\' "$PROBE_ADDR" "$BAL" > /out/config/$CHAIN/allocs.csv; '
            + "fi"
        )

    result = plan.run_sh(
        name="trueblocks-bootstrap",
        description="Render chifra config dir + probe RPC for the chain's prefund balance",
        image=image,
        run=run,
        files={"/tb-toml": toml_artifact},
        env_vars={
            "CHAIN": chain,
            "RPC_URL": rpc_url,
            "PROBE_ADDR": probe_addr,
        },
        store=[StoreSpec(src="/out", name="trueblocks-data")],
        node_selectors=node_selectors,
        tolerations=tolerations,
    )
    return result.files_artifacts[0]


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
