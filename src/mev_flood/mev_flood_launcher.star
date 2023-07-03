MEV_FLOOD_IMAGE = "flashbots/mev-flood"


def launch_mev_flood(plan, el_uri):
    plan.add_service(
        name = "mev-flood",
        config = ServiceConfig(
            image = MEV_FLOOD_IMAGE,
            entrypoint = ["/bin/sh", "-c", "./run init -r {0} -s local.json -k=0xef5177cd0b6b21c87db5a0bf35d4084a8a57a9d6a064f86d51ac85f2b873a4e2 && ./run spam -r {0} -l local.json -k=0xef5177cd0b6b21c87db5a0bf35d4084a8a57a9d6a064f86d51ac85f2b873a4e2".format(el_uri)]
        )
    )
