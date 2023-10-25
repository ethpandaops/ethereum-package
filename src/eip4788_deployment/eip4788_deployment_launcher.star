PYTHON_IMAGE = "ethpandaops/python-web3"
EIP4788_DEPLOYMENT_SERVICE_NAME = "eip4788-contract-deployment"


def deploy_eip4788_contract_in_background(plan, sender_key, el_uri):
    sender_script = plan.upload_files(
        src="./sender.py", name="eip4788-deployment-sender"
    )

    plan.add_service(
        name=EIP4788_DEPLOYMENT_SERVICE_NAME,
        config=ServiceConfig(
            image=PYTHON_IMAGE,
            files={"/tmp": sender_script},
            cmd=["/bin/sh", "-c", "touch /tmp/sender.log && tail -f /tmp/sender.log"],
            env_vars={
                "SENDER_PRIVATE_KEY": sender_key,
                "EL_RPC_URI": el_uri,
            },
        ),
    )

    plan.exec(
        service_name=EIP4788_DEPLOYMENT_SERVICE_NAME,
        recipe=ExecRecipe(
            ["/bin/sh", "-c", "nohup python /tmp/sender.py > /dev/null 2>&1 &"]
        ),
    )
