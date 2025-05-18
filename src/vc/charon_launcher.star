shared_utils = import_module("../shared_utils/shared_utils.star")
input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
cl_context = import_module("../cl/cl_context.star")
vc_shared = import_module("./shared.star")
vc_context = import_module("./vc_context.star")
node_metrics = import_module("../node_metrics_info.star")

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
}

def launch(
    plan,
    launcher,
    keymanager_file,
    service_name,
    image,
    global_log_level,
    cl_context,
    el_context,
    full_name,
    node_keystore_files,
    participant,
    global_tolerations,
    node_selectors,
    network_params,
    port_publisher,
    vc_index,
    genesis_timestamp,
):
    """
    Launch a Charon distributed validator client
    """
    VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS = "/validator-keys"

    if node_keystore_files == None:
        return None

    tolerations = input_parser.get_client_tolerations(
        participant.vc_tolerations, participant.tolerations, global_tolerations
    )

    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, VERBOSITY_LEVELS
    )

    # Get the number of Charon nodes to create (default to 4)
    charon_node_count = 4
    if hasattr(participant, "charon_node_count") and participant.charon_node_count > 0:
        charon_node_count = participant.charon_node_count

    # Get the beacon node endpoints for each Charon node
    beacon_endpoints = []
    for i in range(charon_node_count):
        # Just use the same beacon node for all Charon nodes
        beacon_endpoints.append(cl_context.beacon_http_url)

    # Use the genesis timestamp passed from the participant_network
    genesis_time = genesis_timestamp

    # Create a temporary directory for Charon cluster files
    # charon_cluster_dir = plan.store_service_files(
    #     service_name=service_name + "-charon-cluster-files",
    #     files={},
    # )

    validator_keys_dirpath = ""
    if node_keystore_files:
         validator_keys_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.raw_keys_secrets_relative_dirpath,
        )   
    # join the validator keys directory path with the validator keys dirpath on the service container
    # validator_keys_dirpath = shared_utils.path_

    # Create a temporary service to run the Charon cluster creation
    temp_service = plan.add_service(
        name=service_name + "-temp",
        config=ServiceConfig(
            image=image,
            cmd=[
                "create", "cluster",
                "--name=test",
                "--nodes=" + str(charon_node_count),
                "--fee-recipient-addresses=0x8943545177806ED17B9F23F0a21ee5948eCaa776",
                "--withdrawal-addresses=0xBc7c960C1097ef1Af0FD32407701465f3c03e407",
                "--split-existing-keys",
                "--split-keys-dir=" + validator_keys_dirpath,
                "--testnet-chain-id=3151908",
                "--testnet-fork-version=0x10000038",
                "--testnet-genesis-timestamp=" + str(genesis_time),
                "--testnet-name=kurtosis-testnet",
            ],
            files={
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
                constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
            },
        ),
    )

    # Create a directory for Charon cluster files
    # plan.exec(
    #     service_name=temp_service.name,
    #     recipe=ExecRecipe(
    #         command=["mkdir", "-p", "/opt/charon/validator_keys"],
    #     ),
    # )

    # Copy validator keys to the Charon cluster directory
    # plan.exec(
    #     service_name=temp_service.name,
    #     recipe=ExecRecipe(
    #         command=[
    #             "cp",
    #             "-r",
    #             constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER + "/*",
    #             "/opt/charon/validator_keys/",
    #         ],
    #     ),
    # )

    # Create Charon cluster
    # plan.exec(
    #     service_name=temp_service.name,
    #     recipe=ExecRecipe(
    #         command=[
    #             "charon", "create", "cluster",
    #             "--name=test",
    #             "--nodes=" + str(charon_node_count),
    #             "--fee-recipient-addresses=0x8943545177806ED17B9F23F0a21ee5948eCaa776",
    #             "--withdrawal-addresses=0xBc7c960C1097ef1Af0FD32407701465f3c03e407",
    #             "--split-existing-keys",
    #             "--split-keys-dir=" + constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
    #             "--testnet-chain-id=3151908",
    #             "--testnet-fork-version=0x10000038",
    #             "--testnet-genesis-timestamp=" + str(genesis_time),
    #             "--testnet-name=kurtosis-testnet",
    #         ],
    #     ),
    # )

    # Store the Charon cluster files
    # charon_cluster_files = plan.store_service_files(
    #     service_name=temp_service.name,
    #     files={
    #         ".charon": "/opt/charon/.charon",
    #     },
    # )

    # We'll create the validator keys directory and copy the keys in the Charon service itself
    # For now, we'll just create an empty directory structure

    # We'll create a temporary service to run the Charon cluster creation
    # For now, we'll skip this step and just create the Charon services directly

    # Launch Charon nodes
    charon_services = []
    for i in range(charon_node_count):
        node_name = service_name + "-charon-" + str(i)

        cmd = [
            "run",
            "--testnet-chain-id=3151908",
            "--testnet-fork-version=0x10000038",
            "--testnet-genesis-timestamp=" + str(genesis_time),
            "--testnet-name=testnet",
            "--testnet-capella-hard-fork=0x40000038",
            "--split-keys-dir=" + constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
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

        # Files to mount
        files = {
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
        }

        # Ports configuration
        ports = {
            "validator-api": PortSpec(
                number=CHARON_VALIDATOR_API_PORT,
                transport_protocol="TCP",
                application_protocol="http",
            ),
            "p2p-tcp": PortSpec(
                number=CHARON_P2P_TCP_PORT,
                transport_protocol="TCP",
            ),
            "monitoring": PortSpec(
                number=CHARON_MONITORING_PORT,
                transport_protocol="TCP",
                application_protocol="http",
            ),
            constants.METRICS_PORT_ID: PortSpec(
                number=CHARON_METRICS_PORT,
                transport_protocol="TCP",
                application_protocol="http",
            ),
        }

        # Add the service
        charon_service = plan.add_service(
            name=node_name,
            config=ServiceConfig(
                image=image,
                ports=ports,
                cmd=cmd,
                env_vars=env_vars,
                labels=shared_utils.label_maker(
                    client=constants.VC_TYPE.charon,
                    client_type=constants.CLIENT_TYPES.validator,
                    image=image[-constants.MAX_LABEL_LENGTH:],
                    connected_client=cl_context.client_name,
                    extra_labels=participant.vc_extra_labels,
                    supernode=participant.supernode,
                ),
                tolerations=tolerations,
                node_selectors=node_selectors,
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

        # For now, we'll skip launching the validator clients
        # In a real implementation, we would need to launch validator clients that connect to the Charon nodes

    # Return the first Charon service as the main service
    validator_metrics_port = charon_services[0].ports[constants.METRICS_PORT_ID]
    validator_metrics_url = "{0}:{1}".format(
        charon_services[0].ip_address, validator_metrics_port.number
    )
    validator_node_metrics_info = node_metrics.new_node_metrics_info(
        charon_services[0].name, vc_shared.METRICS_PATH, validator_metrics_url
    )

    return vc_context.new_vc_context(
        client_name=constants.VC_TYPE.charon,
        service_name=charon_services[0].name,
        metrics_info=validator_node_metrics_info,
    )

def new_charon_launcher(el_cl_genesis_data, jwt_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
    )
