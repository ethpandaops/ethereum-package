ADMIN_KEY_INDEX = 0
USER_KEY_INDEX = 2

def prefixed_address(address):
    return "0x" + address

def launch_mev_flood(plan, image, el_uri, genesis_accounts):
    plan.add_service(
        name = "mev-flood",
        config = ServiceConfig(
            image = image,
            entrypoint = ["/bin/sh", "-c", "touch main.log && tail -F main.log"]
        )
    )

    plan.exec(
        service_name = "mev-flood",
        recipe = ExecRecipe(
            command = ["/bin/sh", "-c", "./run init -r {0} -k {1} -u {2} -s deployment.json".format(el_uri, prefixed_address(genesis_accounts[0].private_key), prefixed_address(genesis_accounts[2].private_key))]
        )
    )

def spam_in_background(plan, el_uri, mev_flood_extra_args, seconds_per_bundle, genesis_accounts):
    admin_key, user_key = prefixed_address(genesis_accounts[0].private_key), prefixed_address(genesis_accounts[2].private_key)
    command = ["/bin/sh", "-c", "nohup ./run spam -r {0} -k {1} -u {2} -l deployment.json  --secondsPerBundle {3} >main.log 2>&1 &".format(el_uri, admin_key, user_key, seconds_per_bundle)]
    if mev_flood_extra_args:
        joined_extra_args = " ".join(mev_flood_extra_args)
        command = ["/bin/sh", "-c", "nohup ./run spam -r {0} -k {1} -u {2} -l deployment.json  --secondsPerBundle {3} {4} >main.log 2>&1 &".format(el_uri, admin_key, user_key, seconds_per_bundle, joined_extra_args)]
    plan.exec(
        service_name = "mev-flood",
        recipe = ExecRecipe(
            command = command
        )
    )
