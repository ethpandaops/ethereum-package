shared_utils = import_module("../../../shared_utils/shared_utils.star")
input_parser = import_module("../../../package_io/input_parser.star")

PRIVATE_KEY=0xbcdf20249abf0ed6d944c0288fad489e33f66b3960d9e6229c1cd214ed3bbe31
AVS_DIRECTORY=0x7E2E7DD2Aead92e2e6d05707F21D4C36004f8A2B
SLASHER=0x86A0679C7987B5BA9600affA994B78D0660088ff
TAIKO_L1=0x086f77C5686dfe3F2f8FE487C5f8d357952C8556
TAIKO_TOKEN=0x422A3492e218383753D8006C7Bfa97815B44373F
BEACON_BLOCK_ROOT_CONTRACT=0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02

def deploy(
    plan,
    network_params,
    el_uri,
    beacon_genesis_timestamp,
):
    avs = plan.run_sh(
        name="deploy-avs-contract",
        description="Deploying avs contract",
        run="scripts/deployment/deploy_avs.sh",
        image=network_params.preconf_params.avs_deploy_image,
        env_vars = {
            "PRIVATE_KEY": PRIVATE_KEY,
            "FORK_URL": el_uri,
            "BEACON_GENESIS_TIMESTAMP": beacon_genesis_timestamp,
            "BEACON_BLOCK_ROOT_CONTRACT": BEACON_BLOCK_ROOT_CONTRACT,
            "SLASHER": SLASHER,
            "AVS_DIRECTORY": AVS_DIRECTORY,
            "TAIKO_L1": TAIKO_L1,
            "TAIKO_TOKEN": TAIKO_TOKEN,
        },
        wait=None,
    )

    plan.print(avs.output)
