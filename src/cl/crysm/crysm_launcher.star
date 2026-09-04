node_metrics = import_module("../../node_metrics_info.star")
shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_context = import_module("../../cl/cl_context.star")
cl_shared = import_module("../cl_shared.star")
cl_node_ready_conditions = import_module("../cl_node_ready_conditions.star")
constants = import_module("../../package_io/constants.star")

BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER = "/data/crysm"

BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_QUIC_PORT_NUM = 9001
BEACON_HTTP_PORT_NUM = 4000
BEACON_METRICS_PORT_NUM = 5054
METRICS_PATH = "/metrics"

# crysm speaks QUIC only, so there is no TCP discovery port to declare.
VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "debug",
}


# The client takes a host and a port, not a URL.
def host_port(url):
    return url.replace("http://", "").replace("https://", "").rstrip("/")


def get_beacon_config(
    plan,
    launcher,
    beacon_service_name,
    participant,
    global_log_level,
    bootnode_contexts,
    el_context,
    full_name,
    node_keystore_files,
    snooper_el_engine_context,
    persistent,
    tolerations,
    node_selectors,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
    participant_index,
    network_params,
    extra_files_artifacts,
    backend,
    tempo_otlp_grpc_url,
    otel_otlp_grpc_url=None,
    bootnode_enr_override=None,
    cl_binary_artifact=None,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.cl_log_level, global_log_level, VERBOSITY_LEVELS
    )

    EXECUTION_ENGINE_ENDPOINT = cl_shared.get_execution_engine_endpoint(
        participant, el_context, snooper_el_engine_context
    )

    public_ports = {}
    public_ports_for_component = None
    if port_publisher.cl_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "cl",
            port_publisher,
            participant_index,
        )
        # The four this client actually listens on.
        public_ports = shared_utils.get_port_specs(
            {
                constants.UDP_DISCOVERY_PORT_ID: public_ports_for_component[0],
                constants.HTTP_PORT_ID: public_ports_for_component[1],
                constants.METRICS_PORT_ID: public_ports_for_component[2],
                constants.QUIC_DISCOVERY_PORT_ID: public_ports_for_component[3],
            }
        )

    discovery_port = (
        public_ports_for_component[0]
        if public_ports_for_component
        else BEACON_DISCOVERY_PORT_NUM
    )
    discovery_port_quic = (
        public_ports_for_component[3]
        if public_ports_for_component
        else BEACON_QUIC_PORT_NUM
    )

    used_port_assignments = {
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.QUIC_DISCOVERY_PORT_ID: discovery_port_quic,
        constants.HTTP_PORT_ID: BEACON_HTTP_PORT_NUM,
        constants.METRICS_PORT_ID: BEACON_METRICS_PORT_NUM,
    }

    if participant.skip_start:
        used_ports = shared_utils.get_port_specs(used_port_assignments, wait=None)
    else:
        used_ports = shared_utils.get_port_specs(used_port_assignments)

    cmd = [
        "crysm",
        "--config",
        constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/config.yaml",
        "--datadir",
        BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER,
        "--discovery-port",
        "{0}".format(discovery_port),
        "--quic-port",
        "{0}".format(discovery_port_quic),
        # A container cannot work out its own reachable address, so it is told.
        "--advertised-ip",
        constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--http",
        "--http-address",
        "0.0.0.0",
        "--http-port",
        "{0}".format(BEACON_HTTP_PORT_NUM),
        "--metrics",
        "--metrics-address",
        "0.0.0.0",
        "--metrics-port",
        "{0}".format(BEACON_METRICS_PORT_NUM),
        # A supernode custodies every column; anyone else keeps the requirement.
        "--cgc",
        "128" if participant.supernode else "4",
        # Not confined to the built-in validator: a separate client drives proposals through this
        # node too, and what it does not name a recipient for is paid to whatever this node holds.
        "--suggested-fee-recipient",
        constants.VALIDATING_REWARDS_ACCOUNT,
        "--log-level",
        log_level,
        # A container's stdout is a pipe, so the client would otherwise decide not to colour. Kurtosis
        # passes the escapes through to whoever is reading the logs.
        "--log-color",
        "always",
    ]

    # Either anchor, never both: GLOAS at genesis is the only way this client can start from slot 0,
    # since it has no pre-Gloas containers.
    if checkpoint_sync_enabled and checkpoint_sync_url:
        cmd.append("--checkpoint")
        cmd.append(host_port(checkpoint_sync_url))
        cmd.append("--state-id")
        cmd.append("finalized")
    else:
        cmd.append("--genesis")
        cmd.append(constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.ssz")

    if network_params.gas_limit > 0:
        cmd.append("--target-gas-limit")
        cmd.append("{0}".format(network_params.gas_limit))

    if el_context != None:
        cmd.append("--engine")
        cmd.append(host_port(EXECUTION_ENGINE_ENDPOINT))
        cmd.append("--jwt")
        cmd.append(constants.JWT_MOUNT_PATH_ON_CONTAINER)

    bootnode_arg = bootnode_enr_override
    if network_params.network not in constants.PUBLIC_NETWORKS:
        if (
            network_params.network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network_params.network
        ):
            # No multiaddr fallback, unlike the clients either side of this one: --bootnode takes a
            # record and --peer takes host:port/peer-id, and a libp2p multiaddr is neither.
            if bootnode_arg == None and bootnode_contexts != None:
                for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]:
                    if ctx.enr:
                        cmd.append("--bootnode")
                        cmd.append(ctx.enr)
        elif bootnode_arg == None:
            bootnode_arg = shared_utils.get_devnet_enrs_list(
                plan, launcher.el_cl_genesis_data.files_artifact_uuid
            )

    # The flag is repeatable and takes one record, so the comma-joined list the devnet branch
    # produces has to be handed over an entry at a time rather than whole.
    if bootnode_arg != None:
        for enr in bootnode_arg.split(","):
            if enr:
                cmd.append("--bootnode")
                cmd.append(enr)

    # `use_separate_vc: false` for this client means the beacon node runs the validator, not that
    # nothing does: they are one binary talking to itself over the Beacon API on loopback.
    mount_validator_keys = (
        node_keystore_files != None and not participant.use_separate_vc
    )
    if mount_validator_keys:
        # The raw layout, which is lighthouse's and eth2-val-tools': keys/<0xpubkey>/
        # voting-keystore.json beside secrets/<0xpubkey>.
        cmd.append("--keystores-dir")
        cmd.append(
            shared_utils.path_join(
                constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
                node_keystore_files.raw_keys_relative_dirpath,
            )
        )
        cmd.append("--secrets-dir")
        cmd.append(
            shared_utils.path_join(
                constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
                node_keystore_files.raw_secrets_relative_dirpath,
            )
        )

    if len(participant.cl_extra_params) > 0:
        cmd.extend([param for param in participant.cl_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
    }
    if el_context != None:
        files[constants.JWT_MOUNTPOINT_ON_CLIENTS] = launcher.jwt_file

    if mount_validator_keys:
        files[
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER
        ] = node_keystore_files.files_artifact_uuid

    if persistent:
        # crysm has no volume-size entry of its own, so it reuses the lighthouse key, as consensoor
        # does.
        files[
            BEACON_DATA_DIRPATH_ON_BEACON_SERVICE_CONTAINER
        ] = cl_shared.get_beacon_data_directory(
            beacon_service_name,
            participant,
            network_params,
            constants.CL_TYPE.lighthouse,
        )

    processed_mounts = shared_utils.process_extra_mounts(
        plan, participant.cl_extra_mounts, extra_files_artifacts
    )
    for mount_path, artifact in processed_mounts.items():
        files[mount_path] = artifact

    if cl_binary_artifact != None:
        files["/opt/bin"] = cl_binary_artifact.artifact

    env_vars = shared_utils.with_otel_env_vars(
        participant.cl_extra_env_vars,
        otel_otlp_grpc_url,
        beacon_service_name,
    )

    # exec, so the client is pid 1's process and gets the SIGTERM Kurtosis sends.
    cmd_str = "exec " + " ".join(cmd)
    if cl_binary_artifact != None:
        cmd_str = (
            "cp /opt/bin/{0} /usr/local/bin/crysm && ".format(
                cl_binary_artifact.filename
            )
            + cmd_str
        )

    config_args = {
        "image": participant.cl_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "entrypoint": ["sh", "-c"],
        "cmd": [cmd_str],
        "files": files,
        "env_vars": env_vars,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "labels": shared_utils.label_maker(
            client=constants.CL_TYPE.crysm,
            client_type=constants.CLIENT_TYPES.cl,
            image=participant.cl_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=el_context.client_name if el_context != None else "none",
            extra_labels=participant.cl_extra_labels
            | {constants.NODE_INDEX_LABEL_KEY: str(participant_index + 1)},
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if not participant.skip_start:
        config_args["ready_conditions"] = cl_node_ready_conditions.get_ready_conditions(
            constants.HTTP_PORT_ID
        )

    cl_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)


def get_cl_context(
    plan,
    service_name,
    service,
    participant,
    snooper_el_engine_context,
    node_keystore_files,
    node_selectors,
):
    beacon_http_port = service.ports[constants.HTTP_PORT_ID]
    beacon_metrics_port = service.ports[constants.METRICS_PORT_ID]
    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name,
        METRICS_PATH,
        "{0}:{1}".format(service.name, beacon_metrics_port.number),
    )

    (
        beacon_node_enr,
        beacon_multiaddr,
        beacon_peer_id,
    ) = cl_shared.get_beacon_node_identity(plan, service_name, participant)

    return cl_context.new_cl_context(
        client_name="crysm",
        enr=beacon_node_enr,
        ip_addr=service.name,
        ip_address=service.ip_address,
        http_port=beacon_http_port.number,
        beacon_http_url="http://{0}:{1}".format(service.name, beacon_http_port.number),
        cl_nodes_metrics_info=[beacon_node_metrics_info],
        beacon_service_name=service_name,
        multiaddr=beacon_multiaddr,
        peer_id=beacon_peer_id,
        snooper_enabled=participant.snooper_enabled,
        snooper_el_engine_context=snooper_el_engine_context,
        validator_keystore_files_artifact_uuid=node_keystore_files.files_artifact_uuid
        if node_keystore_files
        else "",
        supernode=participant.supernode,
    )


def new_crysm_launcher(el_cl_genesis_data, jwt_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
    )
