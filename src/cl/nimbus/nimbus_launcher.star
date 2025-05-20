#  ---------------------------------- Library Imports ----------------------------------
shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
cl_shared = import_module("../cl_shared.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")
vc_shared = import_module("../../vc/shared.star")
#  ---------------------------------- Beacon client -------------------------------------
# Nimbus requires that its data directory already exists (because it expects you to bind-mount it), so we
#  have to to create it
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/nimbus/beacon-data"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_HTTP_PORT_NUM = 4000
BEACON_METRICS_PORT_NUM = 8008

# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 50
BEACON_MIN_MEMORY = 256

DEFAULT_BEACON_IMAGE_ENTRYPOINT = ["nimbus_beacon_node"]
BEACON_NODE_ENTRYPOINT = "/home/user/nimbus-eth2/build/nimbus_beacon_node"
BEACON_METRICS_PATH = "/metrics"

VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS = "/data/nimbus/validator-keys"
# ---------------------------------- Genesis Files ----------------------------------

# Nimbus needs write access to the validator keys/secrets directories, and b/c the module container runs as root
#  while the Nimbus container does not, we can't just point the Nimbus binary to the paths in the shared dir because
#  it won't be able to open them. To get around this, we copy the validator keys/secrets to a path inside the Nimbus
#  container that is owned by the container's user

# ---------------------------------- Metrics ----------------------------------

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
}

ENTRYPOINT_ARGS = ["sh", "-c"]


def launch(
    plan,
    launcher,
    beacon_service_name,
    participant,
    global_log_level,
    bootnode_contexts,
    el_context,
    full_name,
    node_keystore_files,
    snooper_engine_context,
    persistent,
    tolerations,
    node_selectors,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    participant_index,
    network_params,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.cl_log_level, global_log_level, VERBOSITY_LEVELS
    )

    beacon_config = get_beacon_config(
        plan,
        launcher,
        beacon_service_name,
        participant,
        log_level,
        bootnode_contexts,
        el_context,
        full_name,
        node_keystore_files,
        snooper_engine_context,
        persistent,
        tolerations,
        node_selectors,
        checkpoint_sync_enabled,
        checkpoint_sync_url,
        port_publisher,
        participant_index,
        network_params,
    )

    beacon_service = plan.add_service(beacon_service_name, beacon_config)
    beacon_http_port = beacon_service.ports[constants.HTTP_PORT_ID]
    beacon_metrics_port = beacon_service.ports[constants.METRICS_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )
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
        recipe=beacon_node_identity_recipe, service_name=beacon_service_name
    )
    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    nimbus_node_metrics_info = node_metrics.new_node_metrics_info(
        beacon_service_name, BEACON_METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [nimbus_node_metrics_info]

    return cl_context.new_cl_context(
        client_name="nimbus",
        enr=beacon_node_enr,
        ip_addr=beacon_service.ip_address,
        http_port=beacon_http_port.number,
        beacon_http_url=beacon_http_url,
        cl_nodes_metrics_info=nodes_metrics_info,
        beacon_service_name=beacon_service_name,
        multiaddr=beacon_multiaddr,
        peer_id=beacon_peer_id,
        snooper_enabled=participant.snooper_enabled,
        snooper_engine_context=snooper_engine_context,
        validator_keystore_files_artifact_uuid=node_keystore_files.files_artifact_uuid
        if node_keystore_files
        else "",
        supernode=participant.supernode,
    )


def get_beacon_config(
    plan,
    launcher,
    beacon_service_name,
    participant,
    log_level,
    bootnode_contexts,
    el_context,
    full_name,
    node_keystore_files,
    snooper_engine_context,
    persistent,
    tolerations,
    node_selectors,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    participant_index,
    network_params,
):
    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS,
            node_keystore_files.nimbus_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS,
            node_keystore_files.raw_secrets_relative_dirpath,
        )
    # If snooper is enabled use the snooper engine context, otherwise use the execution client context
    if participant.snooper_enabled:
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
    validator_public_port_assignment = {}
    public_ports_for_component = None
    if port_publisher.cl_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "cl", port_publisher, participant_index
        )
        validator_public_port_assignment = {
            constants.VALIDATOR_HTTP_PORT_ID: public_ports_for_component[3]
        }
        public_ports = cl_shared.get_general_cl_public_port_specs(
            public_ports_for_component
        )

    discovery_port_tcp = (
        public_ports_for_component[0]
        if public_ports_for_component
        else BEACON_DISCOVERY_PORT_NUM
    )
    discovery_port_udp = (
        public_ports_for_component[0]
        if public_ports_for_component
        else BEACON_DISCOVERY_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port_tcp,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port_udp,
        constants.HTTP_PORT_ID: BEACON_HTTP_PORT_NUM,
        constants.METRICS_PORT_ID: BEACON_METRICS_PORT_NUM,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    nimbus_checkpoint_sync_subtask_str = "{0} trustedNodeSync --data-dir={1} --trusted-node-url={2} --network={3} --backfill=false".format(
        BEACON_NODE_ENTRYPOINT,
        BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        checkpoint_sync_url,
        network_params.network
        if network_params.network in constants.PUBLIC_NETWORKS
        else constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER,
    )

    cmd = [
        "{0}".format(BEACON_NODE_ENTRYPOINT),
        "--non-interactive=true",
        "--log-level=" + log_level,
        "--udp-port={0}".format(discovery_port_udp),
        "--tcp-port={0}".format(discovery_port_tcp),
        "--network={0}".format(
            network_params.network
            if network_params.network in constants.PUBLIC_NETWORKS
            else constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        ),
        "--data-dir=" + BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--web3-url=" + EXECUTION_ENGINE_ENDPOINT,
        "--nat=extip:" + port_publisher.nat_exit_ip,
        "--enr-auto-update=false",
        "--history={0}".format("archive" if constants.ARCHIVE_MODE else "prune"),
        "--rest",
        "--rest-address=0.0.0.0",
        "--rest-allow-origin=*",
        "--rest-port={0}".format(BEACON_HTTP_PORT_NUM),
        # There's a bug where if we don't set this flag, the Nimbus nodes won't work:
        # https://discord.com/channels/641364059387854899/674288681737256970/922890280120750170
        # https://github.com/status-im/nimbus-eth2/issues/2451
        "--doppelganger-detection=false",
        # Nimbus can handle a max of 256 threads, if the host has more then nimbus crashes. Setting it to 4 so it doesn't crash on build servers
        "--num-threads=4",
        "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        # Metrics
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-port={0}".format(BEACON_METRICS_PORT_NUM),
    ]

    validator_default_cmd = [
        "--validators-dir=" + validator_keys_dirpath,
        "--secrets-dir=" + validator_secrets_dirpath,
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        "--graffiti=" + full_name,
    ]

    keymanager_api_cmd = [
        "--keymanager",
        "--keymanager-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--keymanager-address=0.0.0.0",
        "--keymanager-allow-origin=*",
        "--keymanager-token-file=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
    ]

    supernode_cmd = [
        "--debug-peerdas-supernode=true",
    ]

    if network_params.perfect_peerdas_enabled and participant_index < 16:
        cmd.append(
            "--netkey-file="
            + constants.NODE_KEY_MOUNTPOINT_ON_CLIENTS
            + "/node-key-file-{0}.json".format(participant_index + 1)
        )
        cmd.append("--insecure-netkey-password=true")

    if participant.supernode:
        cmd.extend(supernode_cmd)

    if network_params.network not in constants.PUBLIC_NETWORKS:
        cmd.append(
            "--bootstrap-file="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/bootstrap_nodes.txt"
        )
        if (
            network_params.network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network_params.network
        ):
            if bootnode_contexts == None:
                cmd.append("--subscribe-all-subnets")
            else:
                for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]:
                    cmd.append("--bootstrap-node=" + ctx.enr)

    if len(participant.cl_extra_params) > 0:
        cmd.extend([param for param in participant.cl_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }

    if node_keystore_files != None and not participant.use_separate_vc:
        cmd.extend(validator_default_cmd)
        files[
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS
        ] = node_keystore_files.files_artifact_uuid
        files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = launcher.keymanager_file

        if participant.keymanager_enabled:
            cmd.extend(keymanager_api_cmd)
            used_ports.update(vc_shared.VALIDATOR_KEYMANAGER_USED_PORTS)
            public_ports.update(
                shared_utils.get_port_specs(validator_public_port_assignment)
            )

        if network_params.gas_limit > 0:
            cmd.append("--suggested-gas-limit={0}".format(network_params.gas_limit))

    if network_params.perfect_peerdas_enabled and participant_index < 16:
        files[constants.NODE_KEY_MOUNTPOINT_ON_CLIENTS] = Directory(
            artifact_names=["node-key-file-{0}".format(participant_index + 1)]
        )

    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(beacon_service_name),
            size=int(participant.cl_volume_size)
            if int(participant.cl_volume_size) > 0
            else constants.VOLUME_SIZE[network_params.network][
                constants.CL_TYPE.nimbus + "_volume_size"
            ],
        )

    cmd_str = " ".join(cmd)
    if checkpoint_sync_enabled:
        command_str = " && ".join([nimbus_checkpoint_sync_subtask_str, cmd_str])
    else:
        command_str = cmd_str

    config_args = {
        "image": participant.cl_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "cmd": [command_str],
        "files": files,
        "env_vars": participant.cl_extra_env_vars,
        "entrypoint": ENTRYPOINT_ARGS,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "ready_conditions": cl_node_ready_conditions.get_ready_conditions(
            constants.HTTP_PORT_ID
        ),
        "labels": shared_utils.label_maker(
            client=constants.CL_TYPE.nimbus,
            client_type=constants.CLIENT_TYPES.cl,
            image=participant.cl_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=el_context.client_name,
            extra_labels=participant.cl_extra_labels,
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
        "user": User(uid=0, gid=0),
    }

    if int(participant.cl_min_cpu) > 0:
        config_args["min_cpu"] = int(participant.cl_min_cpu)
    if int(participant.cl_max_cpu) > 0:
        config_args["max_cpu"] = int(participant.cl_max_cpu)
    if int(participant.cl_min_mem) > 0:
        config_args["min_memory"] = int(participant.cl_min_mem)
    if int(participant.cl_max_mem) > 0:
        config_args["max_memory"] = int(participant.cl_max_mem)
    return ServiceConfig(**config_args)


def new_nimbus_launcher(el_cl_genesis_data, jwt_file, keymanager_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        keymanager_file=keymanager_file,
    )
