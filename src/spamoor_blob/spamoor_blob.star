shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "spamoor-blob"

# The min/max CPU/memory that spamoor can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 100
MAX_MEMORY = 1000


def launch_spamoor_blob(
    plan,
    prefunded_addresses,
    all_el_contexts,
    spamoor_params,
    global_node_selectors,
    network_params,
    osaka_time,
):
    config = get_config(
        prefunded_addresses,
        all_el_contexts,
        spamoor_params,
        global_node_selectors,
        network_params,
        osaka_time,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    prefunded_addresses,
    all_el_contexts,
    spamoor_params,
    node_selectors,
    network_params,
    osaka_time,
):
    cmd = [
        "{}".format(spamoor_params.scenario),
        "--privkey={}".format(prefunded_addresses[4].private_key),
        "--rpchost={}".format(
            ",".join([el_context.rpc_http_url for el_context in all_el_contexts])
        ),
    ]

    IMAGE_NAME = spamoor_params.image
    if spamoor_params.image == constants.DEFAULT_SPAMOOR_BLOB_IMAGE:
        if (
            "peerdas" in network_params.network
            or network_params.fulu_fork_epoch != constants.FAR_FUTURE_EPOCH
        ):
            IMAGE_NAME = "ethpandaops/spamoor:blob-v1"
            cmd.append("--fulu-activation={}".format(osaka_time))
            cmd.append("--blob-v1-percent=100")

    if spamoor_params.throughput != None:
        cmd.append("--throughput={}".format(spamoor_params.throughput))

    if spamoor_params.max_blobs != None:
        cmd.append("--sidecars={}".format(spamoor_params.max_blobs))

    if spamoor_params.max_pending != None:
        cmd.append("--max-pending={}".format(spamoor_params.max_pending))

    if spamoor_params.max_wallets != None:
        cmd.append("--max-wallets={}".format(spamoor_params.max_wallets))

    if len(spamoor_params.spamoor_extra_args) > 0:
        cmd.extend([param for param in spamoor_params.spamoor_extra_args])

    return ServiceConfig(
        image=IMAGE_NAME,
        cmd=cmd,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
