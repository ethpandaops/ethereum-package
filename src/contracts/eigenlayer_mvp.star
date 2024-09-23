shared_utils = import_module("../../../shared_utils/shared_utils.star")
input_parser = import_module("../../../package_io/input_parser.star")

PRIVATE_KEY=0xbcdf20249abf0ed6d944c0288fad489e33f66b3960d9e6229c1cd214ed3bbe31

def deploy(
    plan,
    network_params,
    el_uri,
):
    eigenlayer_mvp = plan.run_sh(
        name="deploy-eigenlayer-contract",
        description="Deploying eigenlayer mvp contract",
        run="scripts/deployment/deploy_eigenlayer_mvp.sh",
        image=network_params.preconf_params.avs_deploy_image,
        env_vars = {
            "PRIVATE_KEY": PRIVATE_KEY,
            "FORK_URL": el_uri,
        },
        wait=None,
    )

    plan.print(eigenlayer_mvp.output)
