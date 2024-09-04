ADMIN_KEY_INDEX = 0
USER_KEY_INDEX = 2

# The min/max CPU/memory that mev-flood can use
MIN_CPU = 100
MAX_CPU = 2000
MIN_MEMORY = 128
MAX_MEMORY = 1024


def prefixed_address(address):
    return "0x" + address


def launch_mev_flood(
    plan,
    image,
    el_uri,
    contract_owner,
    normal_user,
    global_node_selectors,
):
    plan.add_service(
        name="mev-flood",
        config=ServiceConfig(
            image=image,
            entrypoint=["/bin/sh", "-c", "touch main.log && tail -F main.log"],
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=global_node_selectors,
        ),
    )

    plan.exec(
        service_name="mev-flood",
        description="Initializing mev flood",
        recipe=ExecRecipe(
            command=[
                "/bin/sh",
                "-c",
                "./run init -r {0} -k {1} -u {2} -s deployment.json".format(
                    el_uri,
                    prefixed_address(contract_owner),
                    prefixed_address(normal_user),
                ),
            ]
        ),
    )


def spam_in_background(
    plan, el_uri, mev_flood_extra_args, seconds_per_bundle, contract_owner, normal_user
):
    owner, user = prefixed_address(contract_owner), prefixed_address(normal_user)
    command = [
        "/bin/sh",
        "-c",
        "nohup ./run spam -r {0} -k {1} -u {2} -l deployment.json  --secondsPerBundle {3} >main.log 2>&1 &".format(
            el_uri, owner, user, seconds_per_bundle
        ),
    ]
    if mev_flood_extra_args:
        joined_extra_args = " ".join(mev_flood_extra_args)
        command = [
            "/bin/sh",
            "-c",
            "nohup ./run spam -r {0} -k {1} -u {2} -l deployment.json  --secondsPerBundle {3} {4} >main.log 2>&1 &".format(
                el_uri, owner, user, seconds_per_bundle, joined_extra_args
            ),
        ]
    plan.exec(
        service_name="mev-flood",
        description="Sending spam transactions",
        recipe=ExecRecipe(command=command),
    )
