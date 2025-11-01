shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "bootnodoor"
HTTP_PORT_NUMBER = 8080
DISCOVERY_PORT_NUMBER = 9000

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    constants.UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_PORT_NUMBER,
        shared_utils.UDP_PROTOCOL,
    ),
}


def launch_bootnodoor(
    plan,
    bootnodoor_params,
    el_cl_genesis_data,
    network_params,
    global_node_selectors,
    global_tolerations,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Generate a random 32-byte (64 hex char) private key
    private_key = generate_random_private_key(plan)

    # Get the genesis validators root from the genesis data
    genesis_validators_root = el_cl_genesis_data.genesis_validators_root

    # Fetch external bootnodes for non-kurtosis networks
    # For kurtosis/shadowfork: bootnodoor is the primary bootnode, no external bootnodes needed
    # For ephemery/devnets: read bootstrap_nodes.txt from genesis data
    external_bootnodes = None
    if network_params.network == constants.NETWORK_NAME.ephemery or (
        network_params.network not in constants.PUBLIC_NETWORKS
        and network_params.network != constants.NETWORK_NAME.kurtosis
        and constants.NETWORK_NAME.shadowfork not in network_params.network
    ):
        plan.print(
            "Fetching external bootnodes for network: {0}".format(
                network_params.network
            )
        )
        external_bootnodes = shared_utils.get_devnet_enrs_list(
            plan, el_cl_genesis_data.files_artifact_uuid
        )

    config = get_config(
        bootnodoor_params,
        el_cl_genesis_data,
        private_key,
        genesis_validators_root,
        external_bootnodes,
        global_node_selectors,
        tolerations,
        docker_cache_params,
    )

    plan.add_service(SERVICE_NAME, config)

    # Request ENR from the running bootnodoor service
    # The /enr endpoint returns a plain string (not JSON)
    enr_recipe = GetHttpRequestRecipe(
        endpoint="/enr",
        port_id=constants.HTTP_PORT_ID,
    )

    response = plan.request(
        recipe=enr_recipe,
        service_name=SERVICE_NAME,
    )

    bootnodoor_enr = response["body"]

    return bootnodoor_enr


def get_config(
    bootnodoor_params,
    el_cl_genesis_data,
    private_key,
    genesis_validators_root,
    external_bootnodes,
    node_selectors,
    tolerations,
    docker_cache_params,
):
    cmd = [
        "--cl-config",
        "{0}/config.yaml".format(constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS),
        "--genesis-validators-root",
        genesis_validators_root,
        "--private-key",
        private_key,
        "--bind-addr",
        "0.0.0.0",
        "--web-ui",
        "--nodedb",
        "/nodes.db",
    ]

    # Add external bootnodes for non-kurtosis networks (ephemery, devnets)
    if external_bootnodes != None:
        cmd.append("--bootnodes")
        cmd.append(external_bootnodes)

    # Add any extra args from the params
    if len(bootnodoor_params.extra_args) > 0:
        cmd.extend(bootnodoor_params.extra_args)

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            bootnodoor_params.image,
        ),
        ports=USED_PORTS,
        files={
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        },
        cmd=cmd,
        min_cpu=bootnodoor_params.min_cpu,
        max_cpu=bootnodoor_params.max_cpu,
        min_memory=bootnodoor_params.min_mem,
        max_memory=bootnodoor_params.max_mem,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )


def generate_random_private_key(plan):
    # Generate a random 32-byte (64 hex char) private key using /dev/urandom
    result = plan.run_sh(
        name="generate-bootnodoor-private-key",
        description="Generating random private key for bootnodoor",
        run="head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \\n'",
        wait=None,
    )
    return result.output
