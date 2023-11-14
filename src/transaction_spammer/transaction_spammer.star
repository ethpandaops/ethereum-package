IMAGE_NAME = "ethpandaops/tx-fuzz:master"
SERVICE_NAME = "transaction-spammer"


def launch_transaction_spammer(plan, prefunded_addresses, el_uri, tx_spammer_params):
    config = get_config(
        prefunded_addresses, el_uri, tx_spammer_params.tx_spammer_extra_args
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(prefunded_addresses, el_uri, tx_spammer_extra_args):
    return ServiceConfig(
        image=IMAGE_NAME,
        cmd=[
            "spam",
            "--rpc={}".format(el_uri),
            "--sk={0}".format(prefunded_addresses[3].private_key),
            "{0}".format(" ".join(tx_spammer_extra_args)),
        ],
    )
