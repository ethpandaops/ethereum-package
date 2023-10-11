PYTHON_IMAGE = "python:3.11-alpine"
EIP4788_DEPLOYMENT_SERVICE_NAME = "eip4788-contract-deployment"


def deploy_eip4788_contract_in_background(plan, sender_key, receiver_key, el_uri):
    sender_script = plan.upload_files("./sender.py")

    plan.add_service(
        name=EIP4788_DEPLOYMENT_SERVICE_NAME,
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
        service_name=EIP4788_DEPLOYMENT_SERVICE_NAME,
        recipe=ExecRecipe(
            ["/bin/sh", "-c", "pip install web3 && /tmp/sender.py"]
        ),
    )
