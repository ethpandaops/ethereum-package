IMAGE_NAME = "ethpandaops/tx-fuzz:master"
SERVICE_NAME = "blob-spammer"

ENTRYPOINT_ARGS = ["/bin/sh", "-c"]

# The min/max CPU/memory that blob-spammer can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 256
MAX_MEMORY = 512


def launch_blob_spammer(
    plan,
    prefunded_addresses,
    el_uri,
    cl_context,
    deneb_fork_epoch,
    seconds_per_slot,
    genesis_delay,
    global_node_selectors,
):
    config = get_config(
        prefunded_addresses,
        el_uri,
        cl_context,
        deneb_fork_epoch,
        seconds_per_slot,
        genesis_delay,
        global_node_selectors,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    prefunded_addresses,
    el_uri,
    cl_context,
    deneb_fork_epoch,
    seconds_per_slot,
    genesis_delay,
    node_selectors,
):
    dencunTime = (deneb_fork_epoch * 32 * seconds_per_slot) + genesis_delay
    return ServiceConfig(
        image=IMAGE_NAME,
        entrypoint=ENTRYPOINT_ARGS,
        cmd=[
            " && ".join(
                [
                    "apk update",
                    "apk add curl jq",
                    'current_epoch=$(curl -s {0}/eth/v2/beacon/blocks/head | jq -r ".version")'.format(
                        cl_context.beacon_http_url,
                    ),
                    "echo $current_epoch",
                    'while [ $current_epoch != "deneb" ]; do echo "waiting for deneb, current epoch is $current_epoch"; current_epoch=$(curl -s {0}/eth/v2/beacon/blocks/head | jq -r ".version"); sleep {1}; done'.format(
                        cl_context.beacon_http_url,
                        seconds_per_slot,
                    ),
                    'echo "sleep is over, starting to send blob transactions"',
                    "/tx-fuzz.bin blobs --rpc={} --sk={}".format(
                        el_uri,
                        prefunded_addresses[1].private_key,
                    ),
                ]
            )
        ],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
