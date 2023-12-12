PYTHON_IMAGE = "ethpandaops/python-web3"
EIP4788_DEPLOYMENT_SERVICE_NAME = "eip4788-contract-deployment"

# The min/max CPU/memory that deployer can use
MIN_CPU = 10
MAX_CPU = 100
MIN_MEMORY = 10
MAX_MEMORY = 300


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
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
        ),
    )

    plan.exec(
        service_name=EIP4788_DEPLOYMENT_SERVICE_NAME,
        recipe=ExecRecipe(
            ["/bin/sh", "-c", "nohup python /tmp/sender.py > /dev/null 2>&1 &"]
        ),
    )
