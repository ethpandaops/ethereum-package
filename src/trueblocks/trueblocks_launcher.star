shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "trueblocks"
IMAGE_NAME = "ethereum-package/trueblocks"

HTTP_PORT_NUMBER = 8080

TRUEBLOCKS_DATA_DIR = "/root/.local/share/trueblocks"
TRUEBLOCKS_CHAIN_CONFIG_BASE = shared_utils.path_join(TRUEBLOCKS_DATA_DIR, "config")
TRUEBLOCKS_CONFIG_FILENAME = "trueBlocks.toml"
TRUEBLOCKS_CONFIG_STAGING_DIRPATH = "/tb-config"
TRUEBLOCKS_CONFIG_TARGET_PATH = shared_utils.path_join(
    TRUEBLOCKS_DATA_DIR,
    TRUEBLOCKS_CONFIG_FILENAME,
)

# build_context_dir is resolved relative to this .star file's directory.
BUILD_CONTEXT_DIR = "."

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

# chifra defaults assume a long-lived, high-throughput chain (mainnet); on a
# fresh kurtosis devnet they would never produce visible chunks. We pick scrape
# tuning per network: public chains get chifra's stock values; devnets get
# small, responsive ones so chunks appear within a few slots. Any field a user
# sets explicitly (non-zero) in trueblocks_params.scrape overrides these.
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
        "Version": trueblocks_params.version,
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

    config = ServiceConfig(
        image=_resolve_image(trueblocks_params, docker_cache_params),
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            TRUEBLOCKS_CONFIG_STAGING_DIRPATH: config_files_artifact_name,
        },
        entrypoint=["sh", "-c"],
        cmd=[
            _build_entrypoint_cmd(
                network_params.network,
                rpc_url,
                trueblocks_params.scrape.sleep_seconds,
                prefunded_accounts[0].address if prefunded_accounts else "",
            ),
        ],
        env_vars=trueblocks_params.env,
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
    # 0 is the "unset" sentinel — any other value overrides the network default.
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


def _resolve_image(trueblocks_params, docker_cache_params):
    # If the user pinned a prebuilt image, honor it (routed through the docker
    # cache like the other launchers). Otherwise build chifra from source —
    # ImageBuildSpec bypasses docker_cache_params by design, since the cache
    # is for pulling published tags, not for source builds.
    if trueblocks_params.image:
        return shared_utils.docker_cache_image_calc(
            docker_cache_params,
            trueblocks_params.image,
        )
    return ImageBuildSpec(
        image_name="{0}:{1}".format(
            IMAGE_NAME,
            _docker_tag_from_ref(trueblocks_params.version),
        ),
        build_context_dir=BUILD_CONTEXT_DIR,
        build_args={"TRUEBLOCKS_VERSION": trueblocks_params.version},
    )


def _build_entrypoint_cmd(chain, rpc_url, scrape_sleep, probe_addr):
    # Bootstrap chifra's expected layout before launching it:
    #
    #   1. Per-chain config dir at /root/.local/share/trueblocks/config/<chain>/
    #      — chifra panics on chains referenced from trueBlocks.toml when no
    #      such directory exists. Public networks (mainnet/sepolia/hoodi) come
    #      pre-shipped from the Dockerfile; devnets get a fresh dir here.
    #
    #   2. A valid allocs.csv. chifra's IsNodeArchive picks the largest prefund
    #      and compares its CSV balance to the RPC's balance at block 0;
    #      mismatch means "not archive" and chifra refuses to scrape. Public
    #      chains already have allocs from chifra's bundled per-chain data, so
    #      we only write one when it's missing. For devnets we use the
    #      ethereum-package's first prefunded account, query its actual block-0
    #      balance, and write a self-consistent row. (The zero address won't
    #      work: chifra's Address.Hex() short-circuits to "0x0", which fails
    #      its own IsValidAddress length check and gets filtered out.)
    #
    #   3. Copy the rendered trueBlocks.toml into chifra's XDG path. Mounting
    #      directly there would shadow chifra's other config subdirs.
    #
    # Then run scrape (in a retry loop — it exits if block 1 hasn't been mined
    # yet, which is the normal startup race on a fresh devnet) and exec daemon
    # in the foreground.
    #
    # No `set -e` — it's inherited by subshells and chifra scrape exits
    # non-zero on every transient startup error, which would kill the retry
    # loop after one iteration. Bootstrap steps use `&&` for fail-fast.
    chain_dir = shared_utils.path_join(TRUEBLOCKS_CHAIN_CONFIG_BASE, chain)
    quoted_rpc_url = _shell_quote(rpc_url)
    write_allocs = ""
    if probe_addr:
        # The probe poll accepts only a 0x-prefixed hex string; an "error"
        # response from the node or a JSON `null` would parse to an empty or
        # non-hex value and produce a CSV that fails IsNodeArchive.
        write_allocs = (
            "([ -f {dir}/allocs.csv ] || ("
            + "for i in $(seq 1 60); do "
            + "BAL=$(curl -fsS -X POST -H 'Content-Type: application/json' "
            + '-d \'{{"jsonrpc":"2.0","method":"eth_getBalance",'
            + '"params":["{addr}","0x0"],"id":1}}\' {url} '
            + '2>/dev/null | sed -n \'s/.*"result":"\\([^"]*\\)".*/\\1/p\'); '
            + "echo \"$BAL\" | grep -qE '^0x[0-9a-fA-F]+$' && break; "
            + "sleep 2; "
            + "done; "
            + "echo \"$BAL\" | grep -qE '^0x[0-9a-fA-F]+$' || exit 1; "
            + "printf 'address,balance\\n{addr},%s\\n' \"$BAL\" > {dir}/allocs.csv"
            + ")) && "
        ).format(addr=probe_addr.lower(), url=quoted_rpc_url, dir=chain_dir)
    return (
        "mkdir -p {0} && ".format(chain_dir)
        + "cp {0}/{1} {2} && ".format(
            TRUEBLOCKS_CONFIG_STAGING_DIRPATH,
            TRUEBLOCKS_CONFIG_FILENAME,
            TRUEBLOCKS_CONFIG_TARGET_PATH,
        )
        + write_allocs
        + "true || exit 1; "
        + "(while true; do chifra scrape --sleep {0} 2>&1; sleep 5; done) & ".format(
            scrape_sleep
        )
        + "exec chifra daemon --url :{0}".format(HTTP_PORT_NUMBER)
    )


def _shell_quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"


def _docker_tag_from_ref(ref):
    tag = ""
    for i in range(len(ref)):
        c = ref[i]
        if shared_utils.is_alphanumeric(c) or c == "." or c == "_" or c == "-":
            tag += c
        else:
            tag += "-"

    tag = shared_utils.ensure_alphanumeric_bounds(tag)
    if tag == "":
        fail("trueblocks version must contain at least one alphanumeric character")
    if len(tag) > 128:
        tag = tag[:128]
    return tag
