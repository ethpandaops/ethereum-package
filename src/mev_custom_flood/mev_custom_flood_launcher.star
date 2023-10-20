PYTHON_IMAGE = "ethpandaops/python-web3"
CUSTOM_FLOOD_SERVICE_NAME = "mev-custom-flood"


def spam_in_background(plan, sender_key, receiver_key, el_uri, params):
    sender_script = plan.upload_files("./sender.py")

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
        ),
    )

    plan.exec(
        service_name=CUSTOM_FLOOD_SERVICE_NAME,
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
