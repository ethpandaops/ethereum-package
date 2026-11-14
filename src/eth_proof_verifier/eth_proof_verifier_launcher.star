shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "eth-proof-verifier"

HTTP_PORT_NUMBER = 8025

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

MIN_CPU = 100
MAX_CPU = 2000
MIN_MEMORY = 64
MAX_MEMORY = 1024


def launch_eth_proof_verifier(
    plan,
    eth_proof_verifier_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    plan.add_service(
        SERVICE_NAME,
        ServiceConfig(
            image=shared_utils.docker_cache_image_calc(
                docker_cache_params,
                eth_proof_verifier_params.image,
            ),
            ports=USED_PORTS,
            public_ports=public_ports,
            # The binary listens on loopback by default.
            cmd=[
                "--listen-address",
                "0.0.0.0:{0}".format(HTTP_PORT_NUMBER),
            ]
            + eth_proof_verifier_params.extra_args,
            env_vars=eth_proof_verifier_params.env,
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=global_node_selectors,
            tolerations=tolerations,
        ),
    )
