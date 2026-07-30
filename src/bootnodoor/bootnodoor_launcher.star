shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "bootnodoor"
HTTP_PORT_NUMBER = 8080
DISCOVERY_PORT_NUMBER = 9000


def launch_bootnodoor(
    plan,
    bootnodoor_params,
    el_cl_genesis_data,
    network_params,
    global_node_selectors,
    global_tolerations,
    docker_cache_params,
    port_publisher,
    additional_service_index,
    backend,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Generate random 32-byte (64 hex char) private keys
    private_key = None
    el_private_key = None
    cl_private_key = None
    if bootnodoor_params.separate_keys:
        el_private_key = generate_random_private_key(
            plan, "generate-bootnodoor-el-private-key"
        )
        cl_private_key = generate_random_private_key(
            plan, "generate-bootnodoor-cl-private-key"
        )
    else:
        private_key = generate_random_private_key(
            plan, "generate-bootnodoor-private-key"
        )

    # Get the genesis validators root from the genesis data
    genesis_validators_root = el_cl_genesis_data.genesis_validators_root

    # Get the EL genesis hash
    el_genesis_hash = get_el_genesis_hash(plan, network_params, el_cl_genesis_data)

    # Fetch external bootnodes for non-kurtosis networks
    # For kurtosis/shadowfork: bootnodoor is the primary bootnode, no external bootnodes needed
    # For ephemery/devnets: read bootstrap_nodes.txt (CL ENRs) and enodes.txt (EL) from genesis data
    external_cl_bootnodes = None
    external_el_bootnodes = None
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
        external_cl_bootnodes = shared_utils.get_devnet_enrs_list(
            plan, el_cl_genesis_data.files_artifact_uuid
        )
        external_el_bootnodes = shared_utils.get_devnet_enodes(
            plan, el_cl_genesis_data.files_artifact_uuid
        )

    config = get_config(
        bootnodoor_params,
        el_cl_genesis_data,
        private_key,
        el_private_key,
        cl_private_key,
        genesis_validators_root,
        el_genesis_hash,
        external_cl_bootnodes,
        external_el_bootnodes,
        global_node_selectors,
        tolerations,
        docker_cache_params,
        port_publisher,
        additional_service_index,
        backend,
    )

    plan.add_service(SERVICE_NAME, config)

    # Request ENR from the running bootnodoor service
    # /cl-enr strips the EL-only "eth" field, which some CL clients reject
    enr_recipe = GetHttpRequestRecipe(
        endpoint="/cl-enr",
        port_id=constants.HTTP_PORT_ID,
    )

    response = plan.request(
        recipe=enr_recipe,
        service_name=SERVICE_NAME,
    )

    bootnodoor_enr = response["body"]

    # Request ENODE from the running bootnodoor service for EL bootnode
    enode_recipe = GetHttpRequestRecipe(
        endpoint="/enode",
        port_id=constants.HTTP_PORT_ID,
    )

    enode_response = plan.request(
        recipe=enode_recipe,
        service_name=SERVICE_NAME,
    )

    bootnodoor_enode = enode_response["body"]

    # Request the EL ENR for discv5-only EL clients
    # /el-enr strips the CL-only "eth2" field, which some EL clients reject; with
    # separate_keys it is a different identity than the CL ENR altogether
    el_enr_recipe = GetHttpRequestRecipe(
        endpoint="/el-enr",
        port_id=constants.HTTP_PORT_ID,
    )

    el_enr_response = plan.request(
        recipe=el_enr_recipe,
        service_name=SERVICE_NAME,
    )

    bootnodoor_el_enr = el_enr_response["body"]

    return bootnodoor_enr, bootnodoor_enode, bootnodoor_el_enr


def get_config(
    bootnodoor_params,
    el_cl_genesis_data,
    private_key,
    el_private_key,
    cl_private_key,
    genesis_validators_root,
    el_genesis_hash,
    external_cl_bootnodes,
    external_el_bootnodes,
    node_selectors,
    tolerations,
    docker_cache_params,
    port_publisher,
    additional_service_index,
    backend,
):
    # Bind the published port number itself so the ENR (ip, port) is valid both
    # in-enclave (private IP) and externally (nat_exit_ip)
    discovery_port = DISCOVERY_PORT_NUMBER
    public_ports = {}
    if port_publisher.additional_services_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "additional_services", port_publisher, additional_service_index
        )
        discovery_port = public_ports_for_component[1]
        public_ports = shared_utils.get_port_specs(
            {
                constants.HTTP_PORT_ID: public_ports_for_component[0],
                constants.UDP_DISCOVERY_PORT_ID: discovery_port,
            }
        )

    used_ports = shared_utils.get_port_specs(
        {
            constants.HTTP_PORT_ID: HTTP_PORT_NUMBER,
            constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        }
    )

    cmd = [
        "--cl-config",
        "{0}/config.yaml".format(constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS),
        "--genesis-validators-root",
        genesis_validators_root,
        "--el-config",
        "{0}/genesis.json".format(constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS),
        "--el-genesis-hash",
        el_genesis_hash,
        "--bind-addr",
        "0.0.0.0",
        "--bind-port",
        str(discovery_port),
        # Without a pinned IP, bootnodoor rewrites its ENR to the WAN address learned from PONGs
        "--enr-ip",
        "${K8S_POD_IP}"
        if backend == "kubernetes"
        else port_publisher.additional_services_nat_exit_ip,
        "--web-ui",
        "--nodedb",
        "/nodes.db",
    ]

    if private_key != None:
        cmd.append("--private-key")
        cmd.append(private_key)
    if el_private_key != None:
        cmd.append("--el-private-key")
        cmd.append(el_private_key)
    if cl_private_key != None:
        cmd.append("--cl-private-key")
        cmd.append(cl_private_key)

    # Add external bootnodes for non-kurtosis networks (ephemery, devnets)
    if external_cl_bootnodes != None:
        cmd.append("--cl-bootnodes")
        cmd.append(external_cl_bootnodes)
    if external_el_bootnodes != None:
        cmd.append("--el-bootnodes")
        cmd.append(external_el_bootnodes)

    # Add any extra args from the params
    if len(bootnodoor_params.extra_args) > 0:
        cmd.extend(bootnodoor_params.extra_args)

    cmd_str = "exec /app/bootnodoor " + " ".join(cmd)

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            bootnodoor_params.image,
        ),
        ports=used_ports,
        public_ports=public_ports,
        files={
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        },
        entrypoint=["sh", "-c"],
        cmd=[cmd_str],
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=bootnodoor_params.min_cpu,
        max_cpu=bootnodoor_params.max_cpu,
        min_memory=bootnodoor_params.min_mem,
        max_memory=bootnodoor_params.max_mem,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )


def get_el_genesis_hash(plan, network_params, el_cl_genesis_data):
    # For mainnet and sepolia, use static genesis hashes
    if network_params.network == "mainnet":
        return "0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3"
    elif network_params.network == "sepolia":
        return "0x25a5cc106eea7138acab33231d7160d69cb777ee0c2c553fcddf5138993e6dd9"

    # For other networks, extract from deposit_contract_block_hash.txt
    result = plan.run_sh(
        name="read-el-genesis-hash",
        description="Reading EL genesis hash from deposit_contract_block_hash.txt",
        run="cat /network-configs/deposit_contract_block_hash.txt",
        files={
            "/network-configs": el_cl_genesis_data.files_artifact_uuid,
        },
        wait=None,
    )
    return result.output


def generate_random_private_key(plan, name):
    # Generate a random 32-byte (64 hex char) private key using /dev/urandom
    result = plan.run_sh(
        name=name,
        description="Generating random private key for bootnodoor",
        run="head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \\n'",
        wait=None,
    )
    return result.output


def get_metrics_job():
    return {
        "Name": SERVICE_NAME,
        "Endpoint": "{0}:{1}".format(SERVICE_NAME, HTTP_PORT_NUMBER),
        "MetricsPath": "/metrics",
        "Labels": {
            "service": SERVICE_NAME,
        },
        "ScrapeInterval": "15s",
    }
