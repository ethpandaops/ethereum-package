MEV_FLOOD_IMAGE = "flashbots/mev-flood"


def launch_mev_flood(el_uri):
    plan.add_service(
        name = "mev-flood",
        config = ServiceConfig(
            entrypoint = ["/bin/sh", "-c", "./run init -r {0} -s local.json && ./run spam -r {0} -l local.json".format(el_uri)]
        )
    )
