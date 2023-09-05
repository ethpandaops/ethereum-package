PYTHON_IMAGE = "python:3.11-alpine
CUSTOM_FLOOD_SREVICE_NAME = "mev-custom-flood"
SENDER_SCRIPT_RELATIVE_PATH = "./sender.py"

def launch():
    sender_script  = plan.upload_files(SENDER_SCRIPT_RELATIVE_PATH)

    plan.add_service(
        name = CUSTOM_FLOOD_SREVICE_NAME,
        config = ServiceConfig(
            image = PYTHON_IMAGE,
            files = {
                "/tmp": sender_script
            },
            cmd = ["tail", "-f", "/dev/null"]
        )
    )

    plan.exec(
        service_name = CUSTOM_FLOOD_SREVICE_NAME,
        recipe = ExecRecipe(["pip", "install", "web3"])
    )

    plan.exec(
        service_name = CUSTOM_FLOOD_SREVICE_NAME,
        recipe = ExecRecipe(["/bin/sh", "-c", "nohup python /tmp/sender.py > /dev/null 2>&1 &"])
    )