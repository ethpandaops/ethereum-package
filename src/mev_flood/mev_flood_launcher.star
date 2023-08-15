ADMIN_KEY = "0xef5177cd0b6b21c87db5a0bf35d4084a8a57a9d6a064f86d51ac85f2b873a4e2"
USER_KEY = "0x7988b3a148716ff800414935b305436493e1f25237a2a03e5eebc343735e2f31"

def launch_mev_flood(plan, image, el_uri):
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
            command = ["/bin/sh", "-c", "./run init -r {0} -k {1} -u {2} -s deployment.json".format(el_uri, ADMIN_KEY, USER_KEY)]
        )
    )

def spam_in_background(plan, el_uri, mev_flood_extra_args):
    command = ["/bin/sh", "-c", "nohup ./run spam -r {0} -k {1} -u {2} -l deployment.json  --secondsPerBundle 15 >main.log 2>&1 &".format(el_uri, ADMIN_KEY, USER_KEY)]
    if mev_flood_extra_args:
        joined_extra_args = " ".join(mev_flood_extra_args)
        command = ["/bin/sh", "-c", "nohup ./run spam -r {0} -k {1} -u {2} -l deployment.json  --secondsPerBundle 15 {3} >main.log 2>&1 &".format(el_uri, ADMIN_KEY, USER_KEY, joined_extra_args)]
    plan.exec(
        service_name = "mev-flood",
        recipe = ExecRecipe(
            command = command
        )
    )
