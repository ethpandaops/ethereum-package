shared_utils = import_module("../shared_utils/shared_utils.star")
SERVICE_NAME = "spamoor"

# The min/max CPU/memory that spamoor can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 20
MAX_MEMORY = 300


def launch_spamoor(
    plan,
    prefunded_addresses,
    all_el_contexts,
    spamoor_params,
    global_node_selectors,
):
    config = get_config(
        prefunded_addresses,
        all_el_contexts,
        spamoor_params,
        global_node_selectors,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    prefunded_addresses,
    all_el_contexts,
    spamoor_params,
    node_selectors,
):
    cmd = [
        "{}".format(spamoor_params.scenario),
        "--privkey={}".format(prefunded_addresses[13].private_key),
        "--rpchost={}".format(
            ",".join([el_context.rpc_http_url for el_context in all_el_contexts])
        ),
    ]

    if spamoor_params.throughput != None:
        cmd.append("--throughput={}".format(spamoor_params.throughput))

    if spamoor_params.max_pending != None:
        cmd.append("--max-pending={}".format(spamoor_params.max_pending))

    if spamoor_params.max_wallets != None:
        cmd.append("--max-wallets={}".format(spamoor_params.max_wallets))

    if len(spamoor_params.spamoor_extra_args) > 0:
        cmd.extend([param for param in spamoor_params.spamoor_extra_args])

    return ServiceConfig(
        image=spamoor_params.image,
        cmd=cmd,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
