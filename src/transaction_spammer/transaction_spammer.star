shared_utils = import_module("../shared_utils/shared_utils.star")
SERVICE_NAME = "transaction-spammer"


def launch_transaction_spammer(
    plan, prefunded_addresses, el_uri, tx_spammer_params, electra_fork_epoch
):
    config = get_config(
        prefunded_addresses,
        el_uri,
        tx_spammer_params.tx_spammer_extra_args,
        electra_fork_epoch,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(prefunded_addresses, el_uri, tx_spammer_extra_args, electra_fork_epoch):
    # Temp hack to use the old tx-fuzz image until we can get the new one working
    if electra_fork_epoch != None:
        tx_spammer_image = "ethpandaops/tx-fuzz:kaustinen-281adbc"
    else:
        tx_spammer_image = "ethpandaops/tx-fuzz:master"
    return ServiceConfig(
        image=tx_spammer_image,
        cmd=[
            "spam",
            "--rpc={}".format(el_uri),
            "--sk={0}".format(prefunded_addresses[3].private_key),
            "{0}".format(" ".join(tx_spammer_extra_args)),
        ],
    )
