shared_utils = import_module("../shared_utils/shared_utils.star")
input_parser = import_module("../package_io/input_parser.star")
SERVICE_NAME = "rakoon"

# The min/max CPU/memory that rakoon can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 100
MAX_MEMORY = 500

# Rakoon uses prefunded account index 14
PREFUNDED_ACCOUNT_INDEX = 14


def launch_rakoon(
    plan,
    prefunded_addresses,
    el_uri,
    rakoon_params,
    genesis_delay,
    global_node_selectors,
    global_tolerations,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    config = get_config(
        prefunded_addresses,
        el_uri,
        rakoon_params,
        genesis_delay,
        global_node_selectors,
        tolerations,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    prefunded_addresses,
    el_uri,
    rakoon_params,
    genesis_delay,
    node_selectors,
    tolerations,
):
    start_delay = genesis_delay + 10
    cmd = [
        "rakoon",
        "--key={0}".format(prefunded_addresses[PREFUNDED_ACCOUNT_INDEX].private_key),
        "--url={0}".format(el_uri),
        "--tx-type={0}".format(rakoon_params.tx_type),
        "--workers={0}".format(rakoon_params.workers),
        "--batch-size={0}".format(rakoon_params.batch_size),
        "--start-delay={0}".format(start_delay),
    ]

    # Add optional parameters if configured
    if rakoon_params.seed != "":
        cmd.append("--seed={0}".format(rakoon_params.seed))

    if rakoon_params.fuzzing:
        cmd.append("--fuzzing")

    if rakoon_params.poll_interval != "":
        cmd.append("--poll-interval={0}".format(rakoon_params.poll_interval))

    # Add any extra user-provided arguments
    if len(rakoon_params.extra_args) > 0:
        cmd.extend([param for param in rakoon_params.extra_args])

    return ServiceConfig(
        image=rakoon_params.image,
        cmd=cmd,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )
