shared_utils = import_module("../shared_utils/shared_utils.star")
input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
cl_context = import_module("../cl/cl_context.star")
vc_shared = import_module("./shared.star")

# Charon specific ports
CHARON_VALIDATOR_API_PORT = 3600
CHARON_P2P_TCP_PORT = 3610
CHARON_MONITORING_PORT = 3620
CHARON_METRICS_PORT = 8080

# Default Charon image
DEFAULT_CHARON_IMAGE = "obolnetwork/charon:latest"

# Verbosity levels mapping
VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "trace",
}

def launch(
    plan,
    participant,
    participant_index,
    cl_context,
    el_cl_genesis_data,
    node_keystore_files,
    global_node_selectors,
    docker_cache_params,
):
    """
    Launches a Charon distributed validator setup
    """
    image = shared_utils.get_client_image(
        participant.vc_type,
        participant.vc_image,
        DEFAULT_CHARON_IMAGE,
        docker_cache_params,
    )

    # Get the number of Charon nodes to create (default to 3)
    charon_node_count = 3
    if hasattr(participant, "charon_node_count") and participant.charon_node_count > 0:
        charon_node_count = participant.charon_node_count

    # Get the beacon node endpoints for each Charon node
    beacon_endpoints = []
    for i in range(charon_node_count):
        # Use the same beacon node for all Charon nodes if we don't have enough participants
        beacon_index = i % len(cl_context.all_beacon_http_urls)
        beacon_endpoints.append(cl_context.all_beacon_http_urls[beacon_index])

    # Get the genesis timestamp from the beacon node
    genesis_timestamp = plan.exec(
        service_name=cl_context.service_name,
        recipe=ExecRecipe(
            command=["curl", "-s", cl_context.beacon_http_url + "/eth/v1/beacon/genesis"],
        ),
    )
    genesis_time = plan.extract_from_json_result(genesis_timestamp, ".data.genesis_time")

    # Create a temporary directory for Charon cluster files
    charon_cluster_dir = plan.store_service_files(
        service_name=cl_context.service_name,
        files={},
    )

    # Create Charon cluster
    cluster_creation = plan.exec(
        service_name=cl_context.service_name,
        recipe=ExecRecipe(
            command=[
                "docker", "run", "--rm",
                "-v", charon_cluster_dir + ":/opt/charon",
                image,
                "create", "cluster",
                "--name=test",
                "--nodes=" + str(charon_node_count),
                "--fee-recipient-addresses=0x8943545177806ED17B9F23F0a21ee5948eCaa776",
                "--withdrawal-addresses=0xBc7c960C1097ef1Af0FD32407701465f3c03e407",
                "--split-existing-keys",
                "--split-keys-dir=/opt/charon/validator_keys",
                "--testnet-chain-id=3151908",
                "--testnet-fork-version=0x10000038",
                "--testnet-genesis-timestamp=" + str(genesis_time),
                "--testnet-name=kurtosis-testnet",
            ],
        ),
    )

    # Launch Charon nodes
    charon_services = []
    for i in range(charon_node_count):
        node_name = participant.name + "-charon-" + str(i)

        cmd = [
            "run",
            "--testnet-chain-id=3151908",
            "--testnet-fork-version=0x10000038",
            "--testnet-genesis-timestamp=" + str(genesis_time),
            "--testnet-name=testnet",
            "--testnet-capella-hard-fork=0x40000038",
        ]

        if len(participant.vc_extra_params) > 0:
            cmd.extend([param for param in participant.vc_extra_params])

        env_vars = {
            "CHARON_LOG_LEVEL": "debug",
            "CHARON_LOG_FORMAT": "console",
            "CHARON_P2P_RELAYS": "https://0.relay.obol.tech",
            "CHARON_BUILDER_API": "true",
            "CHARON_VALIDATOR_API_ADDRESS": "0.0.0.0:" + str(CHARON_VALIDATOR_API_PORT),
            "CHARON_P2P_TCP_ADDRESS": "0.0.0.0:" + str(CHARON_P2P_TCP_PORT),
            "CHARON_MONITORING_ADDRESS": "0.0.0.0:" + str(CHARON_MONITORING_PORT),
            "CHARON_PRIVATE_KEY_FILE": "/opt/charon/.charon/cluster/node" + str(i) + "/charon-enr-private-key",
            "CHARON_LOCK_FILE": "/opt/charon/.charon/cluster/node" + str(i) + "/cluster-lock.json",
            "CHARON_JAEGER_SERVICE": "node" + str(i),
            "CHARON_P2P_EXTERNAL_HOSTNAME": "node" + str(i),
            "CHARON_BEACON_NODE_ENDPOINTS": beacon_endpoints[i],
        }

        # Add any extra environment variables
        if hasattr(participant, "vc_extra_env_vars") and participant.vc_extra_env_vars:
            env_vars.update(participant.vc_extra_env_vars)

        ports = {
            "validator-api": shared_utils.new_port_spec(
                CHARON_VALIDATOR_API_PORT,
                shared_utils.TCP_PROTOCOL,
                shared_utils.HTTP_APPLICATION_PROTOCOL,
            ),
            "p2p-tcp": shared_utils.new_port_spec(
                CHARON_P2P_TCP_PORT,
                shared_utils.TCP_PROTOCOL,
                shared_utils.NOT_PROVIDED_APPLICATION_PROTOCOL,
            ),
            "monitoring": shared_utils.new_port_spec(
                CHARON_MONITORING_PORT,
                shared_utils.TCP_PROTOCOL,
                shared_utils.HTTP_APPLICATION_PROTOCOL,
            ),
        }

        files = {
            "/opt/charon/.charon": charon_cluster_dir,
        }

        charon_service = plan.add_service(
            name=node_name,
            config=ServiceConfig(
                image=image,
                ports=ports,
                cmd=cmd,
                env_vars=env_vars,
                files=files,
                labels=shared_utils.label_maker(
                    client=constants.VC_TYPE.charon,
                    client_type=constants.CLIENT_TYPES.validator,
                    image=image[-constants.MAX_LABEL_LENGTH:],
                    connected_client=cl_context.client_name,
                    extra_labels=participant.vc_extra_labels if hasattr(participant, "vc_extra_labels") else {},
                    supernode=participant.supernode if hasattr(participant, "supernode") else False,
                ),
                node_selectors=global_node_selectors,
            ),
        )
        charon_services.append(charon_service)

    # Now launch the validator clients that will connect to Charon nodes
    vc_services = []
    for i in range(charon_node_count):
        # Determine which validator client to use with Charon
        vc_type = "lighthouse"  # Default
        if hasattr(participant, "charon_validator_client"):
            vc_type = participant.charon_validator_client

        # Import the appropriate validator client module
        vc_module = import_module("../vc/" + vc_type + ".star")

        # Create a modified participant for the validator client
        vc_participant = struct(
            name=participant.name + "-vc-" + str(i),
            vc_type=vc_type,
            vc_image=participant.vc_image if hasattr(participant, "vc_image") else None,
            vc_extra_params=participant.vc_extra_params if hasattr(participant, "vc_extra_params") else [],
            vc_extra_env_vars=participant.vc_extra_env_vars if hasattr(participant, "vc_extra_env_vars") else {},
            vc_extra_labels=participant.vc_extra_labels if hasattr(participant, "vc_extra_labels") else {},
            supernode=participant.supernode if hasattr(participant, "supernode") else False,
        )

        # Create a modified CL context that points to the Charon node
        charon_cl_context = struct(
            service_name=charon_services[i].name,
            ip_addr=charon_services[i].ip_address,
            beacon_http_url="http://" + charon_services[i].ip_address + ":" + str(CHARON_VALIDATOR_API_PORT),
            client_name=cl_context.client_name,
            all_beacon_http_urls=cl_context.all_beacon_http_urls,
        )

        # Launch the validator client
        vc_service = vc_module.launch(
            plan=plan,
            participant=vc_participant,
            participant_index=i,
            cl_context=charon_cl_context,
            el_cl_genesis_data=el_cl_genesis_data,
            node_keystore_files=node_keystore_files,
            global_node_selectors=global_node_selectors,
            docker_cache_params=docker_cache_params,
        )
        vc_services.append(vc_service)

    # Return the first Charon service as the main service
    return charon_services[0]

def get_config(
    participant,
    el_cl_genesis_data,
    image,
    global_log_level,
    beacon_http_url,
    cl_context,
    el_context,
    full_name,
    node_keystore_files,
    tolerations,
    node_selectors,
    keymanager_enabled,
    network_params,
    port_publisher,
    vc_index,
):
    """
    Get the configuration for a Charon distributed validator client
    """
    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, VERBOSITY_LEVELS
    )

    # We need to get the genesis timestamp from the beacon node
    # This will be done when the service is started, so we'll use a script to get it
    # and pass it to the Charon command

    # Get the number of Charon nodes to create (default to 4)
    charon_node_count = 4
    if hasattr(participant, "charon_node_count") and participant.charon_node_count > 0:
        charon_node_count = participant.charon_node_count

    # Get the validator keys directory path
    validator_keys_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.raw_keys_relative_dirpath,
    )

    # Get the validator secrets directory path
    validator_secrets_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.raw_secrets_relative_dirpath,
    )

    # Determine the validator client to use with Charon
    validator_client = "lighthouse"  # Default
    if hasattr(participant, "charon_validator_client"):
        validator_client = participant.charon_validator_client

    # Create a startup script that will get the genesis timestamp from the beacon node and pass it to Charon
    startup_script = """#!/bin/sh
# Get the genesis timestamp from the beacon node
GENESIS_TIME=$(curl -s %s/eth/v1/beacon/genesis | grep -o '"genesis_time":[0-9]*' | cut -d':' -f2)

# Run Charon with the genesis timestamp
exec charon run \\
  --beacon-node-endpoints=%s \\
  --validator-api-address=0.0.0.0:%d \\
  --p2p-tcp-address=0.0.0.0:%d \\
  --monitoring-address=0.0.0.0:%d \\
  --log-level=%s \\
  --log-format=console \\
  --builder-api=true \\
  --feature-set=alpha \\
  --testnet-genesis-timestamp=$GENESIS_TIME \\
""" % (
        beacon_http_url,
        beacon_http_url,
        CHARON_VALIDATOR_API_PORT,
        CHARON_P2P_TCP_PORT,
        CHARON_MONITORING_PORT,
        log_level,
    )

    # Add network-specific parameters to the startup script
    if network_params.network == constants.NETWORK_NAME.kurtosis:
        startup_script += """  --testnet-chain-id=3151908 \\
  --testnet-fork-version=0x10000038 \\
  --testnet-name=kurtosis-testnet \\
"""
    elif network_params.network in constants.PUBLIC_NETWORKS:
        startup_script += """  --network=%s \\
""" % network_params.network
    else:
        # For other networks, use the kurtosis defaults
        startup_script += """  --testnet-chain-id=3151908 \\
  --testnet-fork-version=0x10000038 \\
  --testnet-name=kurtosis-testnet \\
"""

    # Add any extra parameters to the startup script
    if hasattr(participant, "vc_extra_params") and len(participant.vc_extra_params) > 0:
        for param in participant.vc_extra_params:
            startup_script += "  %s \\\n" % param

    # Remove the trailing backslash and newline
    startup_script = startup_script.rstrip("\\\n")

    # Basic command for Charon - just run the startup script
    cmd = [
        "/bin/sh",
        "/opt/charon/startup.sh",
    ]



    # Environment variables
    env_vars = {
        "CHARON_DISTRIBUTED_VALIDATOR_ENABLED": "true",
        "CHARON_VALIDATOR_CLIENT": validator_client,
        "CHARON_VALIDATOR_API_ADDRESS": "0.0.0.0:" + str(CHARON_VALIDATOR_API_PORT),
        "CHARON_P2P_TCP_ADDRESS": "0.0.0.0:" + str(CHARON_P2P_TCP_PORT),
        "CHARON_MONITORING_ADDRESS": "0.0.0.0:" + str(CHARON_MONITORING_PORT),
        "CHARON_LOG_LEVEL": log_level,
        "CHARON_LOG_FORMAT": "console",
        "CHARON_VALIDATOR_KEYS_DIR": validator_keys_dirpath,
        "CHARON_VALIDATOR_SECRETS_DIR": validator_secrets_dirpath,
        "CHARON_BEACON_NODE_ENDPOINTS": beacon_http_url,
        "CHARON_JAEGER_SERVICE": full_name,
        "CHARON_CLUSTER_ID": full_name,
        "CHARON_NODE_COUNT": str(charon_node_count),
        "CHARON_FEE_RECIPIENT_ADDRESS": constants.VALIDATING_REWARDS_ACCOUNT,
    }

    # Add any extra environment variables
    if hasattr(participant, "vc_extra_env_vars") and participant.vc_extra_env_vars:
        env_vars.update(participant.vc_extra_env_vars)

    # Store the startup script
    # startup_script_artifact = plan.store_service_files(
    #     service_name=cl_context.service_name,
    #     files={
    #         "startup.sh": startup_script,
    #     },
    # )

    # Files to mount
    # files = {
    #     constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
    #     constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
    #     "/opt/charon": startup_script_artifact,
    # }

    # Ports configuration
    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    # Add Charon-specific ports
    ports.update({
        "validator-api": shared_utils.new_port_spec(
            CHARON_VALIDATOR_API_PORT,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
        "p2p-tcp": shared_utils.new_port_spec(
            CHARON_P2P_TCP_PORT,
            shared_utils.TCP_PROTOCOL,
            shared_utils.NOT_PROVIDED_APPLICATION_PROTOCOL,
        ),
        "monitoring": shared_utils.new_port_spec(
            CHARON_MONITORING_PORT,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    })

    # Public ports
    public_ports = {}

    # Add public port assignments if port publisher is enabled
    if port_publisher != None and port_publisher.enabled:
        public_validator_api_port_assignment = port_publisher.get_port_assignment(
            "validator-api", vc_index
        )
        public_p2p_tcp_port_assignment = port_publisher.get_port_assignment(
            "p2p-tcp", vc_index
        )
        public_monitoring_port_assignment = port_publisher.get_port_assignment(
            "monitoring", vc_index
        )

        public_ports.update(
            shared_utils.get_port_specs(public_validator_api_port_assignment)
        )
        public_ports.update(
            shared_utils.get_port_specs(public_p2p_tcp_port_assignment)
        )
        public_ports.update(
            shared_utils.get_port_specs(public_monitoring_port_assignment)
        )

    # Return the configuration
    return {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "cmd": cmd,
        "files": files,
        "env_vars": env_vars,
        "labels": shared_utils.label_maker(
            client=constants.VC_TYPE.charon,
            client_type=constants.CLIENT_TYPES.validator,
            image=image[-constants.MAX_LABEL_LENGTH:],
            connected_client=cl_context.client_name,
            extra_labels=participant.vc_extra_labels if hasattr(participant, "vc_extra_labels") else {},
            supernode=participant.supernode if hasattr(participant, "supernode") else False,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }
