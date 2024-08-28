SERVICE_NAME = "goomy-blob-spammer"
IMAGE_NAME = "ethpandaops/goomy-blob:master"

ENTRYPOINT_ARGS = ["/bin/sh", "-c"]

# The min/max CPU/memory that goomy can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 20
MAX_MEMORY = 300


def launch_goomy_blob(
    plan,
    prefunded_addresses,
    el_contexts,
    cl_context,
    seconds_per_slot,
    goomy_blob_params,
    global_node_selectors,
):
    config = get_config(
        prefunded_addresses,
        el_contexts,
        cl_context,
        seconds_per_slot,
        goomy_blob_params.goomy_blob_args,
        global_node_selectors,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    prefunded_addresses,
    el_contexts,
    cl_context,
    seconds_per_slot,
    goomy_blob_args,
    node_selectors,
):
    goomy_cli_args = []
    for index, client in enumerate(el_contexts):
        goomy_cli_args.append(
            "-h http://{0}:{1}".format(
                client.ip_addr,
                client.rpc_port_num,
            )
        )

    goomy_args = " ".join(goomy_blob_args)
    if goomy_args == "":
        goomy_args = "combined -b 2 -t 2 --max-pending 3"
    goomy_cli_args.append(goomy_args)

    cmd = "./blob-spammer -p {0} {1}".format(
        prefunded_addresses[4].private_key, " ".join(goomy_cli_args)
    )

    return ServiceConfig(
        image=IMAGE_NAME,
        entrypoint=ENTRYPOINT_ARGS,
        cmd=[cmd],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
