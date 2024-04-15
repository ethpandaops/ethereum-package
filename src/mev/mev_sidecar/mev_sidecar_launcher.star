redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")
postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")
constants = import_module("../../package_io/constants.star")

MEV_SIDECAR_ENDPOINT = "mev-sidecar-api"

MEV_SIDECAR_ENDPOINT_PORT = 9061

# The min/max CPU/memory that mev-sidecar can use
MEV_SIDECAR_MIN_CPU = 100
MEV_SIDECAR_MAX_CPU = 1000
MEV_SIDECAR_MIN_MEMORY = 128
MEV_SIDECAR_MAX_MEMORY = 1024

def launch_mev_sidecar(
    plan,
    mev_params,
    node_selectors,
):
    image = mev_params.mev_sidecar_image

    env_vars = {
        "RUST_LOG": "info",
    }

    api = plan.add_service(
        name=MEV_SIDECAR_ENDPOINT,
        config=ServiceConfig(
            image=image,
            cmd=[
                "/bolt-sidecar",
                "--port",
                str(MEV_SIDECAR_ENDPOINT_PORT),
            ],
            # + mev_params.mev_relay_api_extra_args,
            ports={
                "api": PortSpec(
                    number=MEV_SIDECAR_ENDPOINT_PORT, transport_protocol="TCP"
                )
            },
            env_vars=env_vars,
            min_cpu=MEV_SIDECAR_MIN_CPU,
            max_cpu=MEV_SIDECAR_MAX_CPU,
            min_memory=MEV_SIDECAR_MIN_MEMORY,
            max_memory=MEV_SIDECAR_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    return "http://{0}:{1}".format(
        api.ip_address, MEV_SIDECAR_ENDPOINT_PORT
    )
