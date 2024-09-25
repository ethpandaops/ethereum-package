shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")
vc_shared = import_module("../../vc/shared.star")

#  ---------------------------------- Beacon client -------------------------------------
TEKU_BINARY_FILEPATH_IN_IMAGE = "/opt/teku/bin/teku"

# The Docker container runs as the "teku" user so we can't write to root
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/teku/teku-beacon-data"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_HTTP_PORT_NUM = 4000
BEACON_METRICS_PORT_NUM = 8008

BEACON_METRICS_PATH = "/metrics"

MIN_PEERS = 1

ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
}


def launch(
    plan,
    launcher,
    service_name,
    image,
    participant_log_level,
    global_log_level,
    bootnode_context,
    el_context,
    full_name,
    node_keystore_files,
    cl_min_cpu,
    cl_max_cpu,
    cl_min_mem,
    cl_max_mem,
    snooper_enabled,
    snooper_engine_context,
    blobber_enabled,
    blobber_extra_params,
    extra_params,
    extra_env_vars,
    extra_labels,
    persistent,
    cl_volume_size,
    tolerations,
    node_selectors,
    use_separate_vc,
    keymanager_enabled,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    participant_index,
):
    beacon_service_name = "{0}".format(service_name)
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )

    extra_params = [param for param in extra_params]

    config = get_beacon_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        keymanager_enabled,
        launcher.keymanager_file,
        launcher.network,
        image,
        beacon_service_name,
        bootnode_context,
        el_context,
        full_name,
        log_level,
        node_keystore_files,
        cl_min_cpu,
        cl_max_cpu,
        cl_min_mem,
        cl_max_mem,
        snooper_enabled,
        snooper_engine_context,
        extra_params,
        extra_env_vars,
        extra_labels,
        use_separate_vc,
        persistent,
        cl_volume_size,
        tolerations,
        node_selectors,
        checkpoint_sync_enabled,
        checkpoint_sync_url,
        port_publisher,
        participant_index,
    )

    beacon_service = plan.add_service(service_name, config)

    beacon_http_port = beacon_service.ports[constants.HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )

    beacon_metrics_port = beacon_service.ports[constants.METRICS_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(
        beacon_service.ip_address, beacon_metrics_port.number
    )

    beacon_node_identity_recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=constants.HTTP_PORT_ID,
        extract={
            "enr": ".data.enr",
            "multiaddr": ".data.p2p_addresses[0]",
            "peer_id": ".data.peer_id",
        },
    )
    response = plan.request(
        recipe=beacon_node_identity_recipe, service_name=service_name
    )
    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, BEACON_METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    return cl_context.new_cl_context(
        client_name="teku",
        enr=beacon_node_enr,
        ip_addr=beacon_service.ip_address,
        http_port=beacon_http_port.number,
        beacon_http_url=beacon_http_url,
        cl_nodes_metrics_info=nodes_metrics_info,
        beacon_service_name=beacon_service_name,
        multiaddr=beacon_multiaddr,
        peer_id=beacon_peer_id,
        snooper_enabled=snooper_enabled,
        snooper_engine_context=snooper_engine_context,
        validator_keystore_files_artifact_uuid=node_keystore_files.files_artifact_uuid
        if node_keystore_files
        else "",
    )


def get_beacon_config(
    plan,
    el_cl_genesis_data,
    jwt_file,
    keymanager_enabled,
    keymanager_file,
    network,
    image,
    service_name,
    bootnode_contexts,
    el_context,
    full_name,
    log_level,
    node_keystore_files,
    cl_min_cpu,
    cl_max_cpu,
    cl_min_mem,
    cl_max_mem,
    snooper_enabled,
    snooper_engine_context,
    extra_params,
    extra_env_vars,
    extra_labels,
    use_separate_vc,
    persistent,
    cl_volume_size,
    tolerations,
    node_selectors,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    participant_index,
):
    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files:
        validator_keys_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_secrets_relative_dirpath,
        )
    # If snooper is enabled use the snooper engine context, otherwise use the execution client context
    if snooper_enabled:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            snooper_engine_context.ip_addr,
            snooper_engine_context.engine_rpc_port_num,
        )
    else:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            el_context.ip_addr,
            el_context.engine_rpc_port_num,
        )

    public_ports = {}
    discovery_port = BEACON_DISCOVERY_PORT_NUM
    validator_public_port_assignment = {}
    if port_publisher.cl_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "cl", port_publisher, participant_index
        )
        validator_public_port_assignment = {
            constants.VALIDATOR_HTTP_PORT_ID: public_ports_for_component[3]
        }
        public_ports, discovery_port = cl_shared.get_general_cl_public_port_specs(
            public_ports_for_component
        )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.HTTP_PORT_ID: BEACON_HTTP_PORT_NUM,
        constants.METRICS_PORT_ID: BEACON_METRICS_PORT_NUM,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "--logging=" + log_level,
        "--log-destination=CONSOLE",
        "--network={0}".format(
            network
            if network in constants.PUBLIC_NETWORKS
            else constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/config.yaml"
        ),
        "--data-path=" + BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--data-storage-mode={0}".format(
            "ARCHIVE" if constants.ARCHIVE_MODE else "PRUNE"
        ),
        "--p2p-enabled=true",
        "--p2p-peer-lower-bound={0}".format(MIN_PEERS),
        "--p2p-advertised-ip=" + port_publisher.nat_exit_ip,
        "--p2p-discovery-site-local-addresses-enabled=true",
        "--p2p-port={0}".format(discovery_port),
        "--rest-api-enabled=true",
        "--rest-api-docs-enabled=true",
        "--rest-api-interface=0.0.0.0",
        "--rest-api-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--rest-api-host-allowlist=*",
        "--data-storage-non-canonical-blocks-enabled=true",
        "--ee-jwt-secret-file=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--ee-endpoint=" + EXECUTION_ENGINE_ENDPOINT,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics-enabled",
        "--metrics-interface=0.0.0.0",
        "--metrics-host-allowlist=*",
        "--metrics-categories=BEACON,PROCESS,LIBP2P,JVM,NETWORK,PROCESS",
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
        # To enable syncing other networks too without checkpoint syncing
        "--ignore-weak-subjectivity-period-enabled=true",
    ]
    validator_default_cmd = [
        "--validator-keys={0}:{1}".format(
            validator_keys_dirpath,
            validator_secrets_dirpath,
        ),
        "--validators-proposer-default-fee-recipient="
        + constants.VALIDATING_REWARDS_ACCOUNT,
        "--validators-graffiti=" + full_name,
    ]

    keymanager_api_cmd = [
        "--validator-api-enabled=true",
        "--validator-api-host-allowlist=*",
        "--validator-api-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--validator-api-interface=0.0.0.0",
        "--validator-api-bearer-file=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
        "--Xvalidator-api-ssl-enabled=false",
        "--Xvalidator-api-unsafe-hosts-enabled=true",
    ]

    # If checkpoint sync is enabled, add the checkpoint sync url
    if checkpoint_sync_enabled:
        if checkpoint_sync_url:
            cmd.append("--checkpoint-sync-url=" + checkpoint_sync_url)
        else:
            if (
                network in constants.PUBLIC_NETWORKS
                or network == constants.NETWORK_NAME.ephemery
            ):
                cmd.append(
                    "--checkpoint-sync-url=" + constants.CHECKPOINT_SYNC_URL[network]
                )
            else:
                fail(
                    "Checkpoint sync URL is required if you enabled checkpoint_sync for custom networks. Please provide a valid URL."
                )

    if network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--initial-state="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis.ssz"
        )
        if (
            network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network
        ):
            if bootnode_contexts != None:
                cmd.append(
                    "--p2p-discovery-bootnodes="
                    + ",".join(
                        [
                            ctx.enr
                            for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]
                        ]
                    )
                )
        elif network == constants.NETWORK_NAME.ephemery:
            cmd.append(
                "--p2p-discovery-bootnodes="
                + shared_utils.get_devnet_enrs_list(
                    plan, el_cl_genesis_data.files_artifact_uuid
                )
            )
        elif constants.NETWORK_NAME.shadowfork in network:
            cmd.append(
                "--p2p-discovery-bootnodes="
                + shared_utils.get_devnet_enrs_list(
                    plan, el_cl_genesis_data.files_artifact_uuid
                )
            )
        else:  # Devnets
            cmd.append(
                "--p2p-discovery-bootnodes="
                + shared_utils.get_devnet_enrs_list(
                    plan, el_cl_genesis_data.files_artifact_uuid
                )
            )

    if len(extra_params) > 0:
        # we do the list comprehension as the default extra_params is a proto repeated string
        cmd.extend([param for param in extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    if node_keystore_files != None and not use_separate_vc:
        cmd.extend(validator_default_cmd)
        files[
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER
        ] = node_keystore_files.files_artifact_uuid

        if keymanager_enabled:
            files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = keymanager_file
            cmd.extend(keymanager_api_cmd)
            used_ports.update(vc_shared.VALIDATOR_KEYMANAGER_USED_PORTS)
            public_ports.update(
                shared_utils.get_port_specs(validator_public_port_assignment)
            )

    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=cl_volume_size,
        )

    config_args = {
        "image": image,
        "ports": used_ports,
        "public_ports": public_ports,
        "cmd": cmd,
        "files": files,
        "env_vars": extra_env_vars,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "ready_conditions": cl_node_ready_conditions.get_ready_conditions(
            constants.HTTP_PORT_ID
        ),
        "labels": shared_utils.label_maker(
            constants.CL_TYPE.teku,
            constants.CLIENT_TYPES.cl,
            image,
            el_context.client_name,
            extra_labels,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
        "user": User(uid=0, gid=0),
    }

    if cl_min_cpu > 0:
        config_args["min_cpu"] = cl_min_cpu

    if cl_max_cpu > 0:
        config_args["max_cpu"] = cl_max_cpu

    if cl_min_mem > 0:
        config_args["min_memory"] = cl_min_mem

    if cl_max_mem > 0:
        config_args["max_memory"] = cl_max_mem

    return ServiceConfig(**config_args)


def new_teku_launcher(el_cl_genesis_data, jwt_file, network_params, keymanager_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network_params.network,
        keymanager_file=keymanager_file,
    )
