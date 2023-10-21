IMAGE_NAME = "ethpandaops/tx-fuzz:master"
SERVICE_NAME = "blob-spammer"

ENTRYPOINT_ARGS = ["/bin/sh", "-c"]


def launch_blob_spammer(
    plan,
    prefunded_addresses,
    el_client_context,
    cl_client_context,
    deneb_fork_epoch,
    seconds_per_slot,
    genesis_delay,
):
    config = get_config(
        prefunded_addresses,
        el_client_context,
        cl_client_context,
        deneb_fork_epoch,
        seconds_per_slot,
        genesis_delay,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    prefunded_addresses,
    el_client_context,
    cl_client_context,
    deneb_fork_epoch,
    seconds_per_slot,
    genesis_delay,
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
                    'current_epoch=$(curl -s http://{0}:{1}/eth/v2/beacon/blocks/head | jq -r ".version")'.format(
                        cl_client_context.ip_addr, cl_client_context.http_port_num
                    ),
                    "echo $current_epoch",
                    'while [ $current_epoch != "deneb" ]; do echo "waiting for deneb, current epoch is $current_epoch"; current_epoch=$(curl -s http://{0}:{1}/eth/v2/beacon/blocks/head | jq -r ".version"); sleep {2}; done'.format(
                        cl_client_context.ip_addr,
                        cl_client_context.http_port_num,
                        seconds_per_slot,
                    ),
                    'echo "sleep is over, starting to send blob transactions"',
                    "/tx-fuzz.bin blobs --rpc=http://{0}:{1} --sk={2}".format(
                        el_client_context.ip_addr,
                        el_client_context.rpc_port_num,
                        prefunded_addresses[1].private_key,
                    ),
                ]
            )
        ],
    )
