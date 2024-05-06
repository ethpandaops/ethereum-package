PYTHON_IMAGE = "ethpandaops/python-web3"
CUSTOM_FLOOD_SERVICE_NAME = "mev-custom-flood"

# The min/max CPU/memory that mev-custom-flood can use
MIN_CPU = 10
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 1024


def spam_in_background(
    plan,
    sender_key,
    receiver_key,
    el_uri,
    params,
    global_node_selectors,
):
    sender_script = plan.upload_files(src="./sender.py", name="mev-custom-flood-sender")

    plan.add_service(
        name=CUSTOM_FLOOD_SERVICE_NAME,
        config=ServiceConfig(
            image=PYTHON_IMAGE,
            files={"/tmp": sender_script},
            cmd=["/bin/sh", "-c", "touch /tmp/sender.log && tail -f /tmp/sender.log"],
            env_vars={
                "SENDER_PRIVATE_KEY": sender_key,
                "RECEIVER_PUBLIC_KEY": receiver_key,
                "EL_RPC_URI": el_uri,
            },
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=global_node_selectors,
        ),
    )

    plan.exec(
        service_name=CUSTOM_FLOOD_SERVICE_NAME,
        description="Sending transactions",
        recipe=ExecRecipe(
            [
                "/bin/sh",
                "-c",
                "nohup python /tmp/sender.py  --interval_between_transactions {} > /dev/null 2>&1 &".format(
                    params.interval_between_transactions
                ),
            ]
        ),
    )
