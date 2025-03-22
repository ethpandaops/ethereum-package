shared_utils = import_module("../shared_utils/shared_utils.star")
SERVICE_NAME = "tx-fuzz"

# The min/max CPU/memory that tx-fuzz can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 20
MAX_MEMORY = 300


def launch_tx_fuzz(
    plan,
    prefunded_addresses,
    el_uri,
    tx_fuzz_params,
    global_node_selectors,
):
    config = get_config(
        prefunded_addresses,
        el_uri,
        tx_fuzz_params,
        global_node_selectors,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    prefunded_addresses,
    el_uri,
    tx_fuzz_params,
    node_selectors,
):
    cmd = [
        "spam",
        "--rpc={}".format(el_uri),
        "--sk={0}".format(prefunded_addresses[3].private_key),
    ]

    if len(tx_fuzz_params.tx_fuzz_extra_args) > 0:
        cmd.extend([param for param in tx_fuzz_params.tx_fuzz_extra_args])

    return ServiceConfig(
        image=tx_fuzz_params.image,
        cmd=cmd,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
