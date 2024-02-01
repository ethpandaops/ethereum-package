shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
cl_client_context = import_module("../../cl/cl_client_context.star")
node_metrics = import_module("../../node_metrics_info.star")
cl_node_ready_conditions = import_module("../../cl/cl_node_ready_conditions.star")
constants = import_module("../../package_io/constants.star")
IMAGE_SEPARATOR_DELIMITER = ","
EXPECTED_NUM_IMAGES = 2

#  ---------------------------------- Beacon client -------------------------------------
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/prysm/beacon-data/"

# Port IDs
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
RPC_PORT_ID = "rpc"
BEACON_HTTP_PORT_ID = "http"
BEACON_MONITORING_PORT_ID = "monitoring"

# Port nums
DISCOVERY_TCP_PORT_NUM = 13000
DISCOVERY_UDP_PORT_NUM = 12000
RPC_PORT_NUM = 4000
HTTP_PORT_NUM = 3500
BEACON_MONITORING_PORT_NUM = 8080

# The min/max CPU/memory that the beacon node can use
BEACON_MIN_CPU = 100
BEACON_MIN_MEMORY = 256

#  ---------------------------------- Validator client -------------------------------------
VALIDATOR_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/prysm/validator-data/"
VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/validator-keys"
PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/prysm-password"

# Port IDs
VALIDATOR_MONITORING_PORT_NUM = 8081
VALIDATOR_MONITORING_PORT_ID = "monitoring"

METRICS_PATH = "/metrics"
VALIDATOR_SUFFIX_SERVICE_NAME = "validator"

# The min/max CPU/memory that the validator node can use
VALIDATOR_MIN_CPU = 50
VALIDATOR_MAX_CPU = 300
VALIDATOR_MIN_MEMORY = 64
VALIDATOR_MAX_MEMORY = 256


MIN_PEERS = 1

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

BEACON_NODE_USED_PORTS = {
    TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_TCP_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
        DISCOVERY_UDP_PORT_NUM, shared_utils.UDP_PROTOCOL
    ),
    RPC_PORT_ID: shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
    BEACON_HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
    BEACON_MONITORING_PORT_ID: shared_utils.new_port_spec(
        BEACON_MONITORING_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}

VALIDATOR_NODE_USED_PORTS = {
    VALIDATOR_MONITORING_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_MONITORING_PORT_NUM, shared_utils.TCP_PROTOCOL
    ),
}

VERBOSITY_LEVELS = {
    constants.GLOBAL_CLIENT_LOG_LEVEL.error: "error",
    constants.GLOBAL_CLIENT_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_CLIENT_LOG_LEVEL.info: "info",
    constants.GLOBAL_CLIENT_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_CLIENT_LOG_LEVEL.trace: "trace",
}


def launch(
    plan,
    launcher,
    service_name,
    images,
    participant_log_level,
    global_log_level,
    bootnode_contexts,
    el_client_context,
    node_keystore_files,
    bn_min_cpu,
    bn_max_cpu,
    bn_min_mem,
    bn_max_mem,
    v_min_cpu,
    v_max_cpu,
    v_min_mem,
    v_max_mem,
    snooper_enabled,
    snooper_engine_context,
    blobber_enabled,
    blobber_extra_params,
    extra_beacon_params,
    extra_validator_params,
    extra_beacon_labels,
    extra_validator_labels,
    persistent,
    cl_volume_size,
    cl_tolerations,
    validator_tolerations,
    participant_tolerations,
    global_tolerations,
    split_mode_enabled=False,
):
    split_images = images.split(IMAGE_SEPARATOR_DELIMITER)
    if len(split_images) != EXPECTED_NUM_IMAGES:
        fail(
            "Expected {0} images but got {1}".format(
                EXPECTED_NUM_IMAGES, len(split_images)
            )
        )
    beacon_image, validator_image = split_images

    if beacon_image.strip() == "":
        fail("An empty beacon image was provided")

    if validator_image.strip() == "":
        fail("An empty validator image was provided")

    beacon_service_name = "{0}".format(service_name)
    validator_service_name = "{0}-{1}".format(
        service_name, VALIDATOR_SUFFIX_SERVICE_NAME
    )
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )

    tolerations = input_parser.get_client_tolerations(
        cl_tolerations, participant_tolerations, global_tolerations
    )

    network_name = (
        "devnets"
        if launcher.network != "kurtosis"
        and launcher.network != "ephemery"
        and launcher.network not in constants.PUBLIC_NETWORKS
        else launcher.network
    )

    bn_min_cpu = int(bn_min_cpu) if int(bn_min_cpu) > 0 else BEACON_MIN_CPU
    bn_max_cpu = (
        int(bn_max_cpu)
        if int(bn_max_cpu) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["prysm_max_cpu"]
    )
    bn_min_mem = int(bn_min_mem) if int(bn_min_mem) > 0 else BEACON_MIN_MEMORY
    bn_max_mem = (
        int(bn_max_mem)
        if int(bn_max_mem) > 0
        else constants.RAM_CPU_OVERRIDES[network_name]["prysm_max_mem"]
    )

    cl_volume_size = (
        int(cl_volume_size)
        if int(cl_volume_size) > 0
        else constants.VOLUME_SIZE[network_name]["prysm_volume_size"]
    )

    beacon_config = get_beacon_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        launcher.network,
        beacon_image,
        beacon_service_name,
        bootnode_contexts,
        el_client_context,
        log_level,
        bn_min_cpu,
        bn_max_cpu,
        bn_min_mem,
        bn_max_mem,
        snooper_enabled,
        snooper_engine_context,
        extra_beacon_params,
        extra_beacon_labels,
        persistent,
        cl_volume_size,
        tolerations,
    )

    beacon_service = plan.add_service(beacon_service_name, beacon_config)

    beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]

    beacon_http_endpoint = "{0}:{1}".format(beacon_service.ip_address, HTTP_PORT_NUM)
    beacon_rpc_endpoint = "{0}:{1}".format(beacon_service.ip_address, RPC_PORT_NUM)

    # Launch validator node if we have a keystore file
    validator_service = None
    if node_keystore_files != None:
        v_min_cpu = int(v_min_cpu) if int(v_min_cpu) > 0 else VALIDATOR_MIN_CPU
        v_max_cpu = int(v_max_cpu) if int(v_max_cpu) > 0 else VALIDATOR_MAX_CPU
        v_min_mem = int(v_min_mem) if int(v_min_mem) > 0 else VALIDATOR_MIN_MEMORY
        v_max_mem = int(v_max_mem) if int(v_max_mem) > 0 else VALIDATOR_MAX_MEMORY
        tolerations = input_parser.get_client_tolerations(
            validator_tolerations, participant_tolerations, global_tolerations
        )
        validator_config = get_validator_config(
            launcher.el_cl_genesis_data,
            validator_image,
            validator_service_name,
            log_level,
            beacon_rpc_endpoint,
            beacon_http_endpoint,
            el_client_context,
            node_keystore_files,
            v_min_cpu,
            v_max_cpu,
            v_min_mem,
            v_max_mem,
            extra_validator_params,
            extra_validator_labels,
            launcher.prysm_password_relative_filepath,
            launcher.prysm_password_artifact_uuid,
            persistent,
            tolerations,
        )

        validator_service = plan.add_service(validator_service_name, validator_config)

    # TODO(old) add validator availability using the validator API: https://ethereum.github.io/beacon-APIs/?urls.primaryName=v1#/ValidatorRequiredApi | from eth2-merge-kurtosis-module
    beacon_node_identity_recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=BEACON_HTTP_PORT_ID,
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

    beacon_metrics_port = beacon_service.ports[BEACON_MONITORING_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(
        beacon_service.ip_address, beacon_metrics_port.number
    )
    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        beacon_service_name, METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    if validator_service:
        validator_metrics_port = validator_service.ports[VALIDATOR_MONITORING_PORT_ID]
        validator_metrics_url = "{0}:{1}".format(
            validator_service.ip_address, validator_metrics_port.number
        )
        validator_node_metrics_info = node_metrics.new_node_metrics_info(
            validator_service_name, METRICS_PATH, validator_metrics_url
        )
        nodes_metrics_info.append(validator_node_metrics_info)

    return cl_client_context.new_cl_client_context(
        "prysm",
        beacon_node_enr,
        beacon_service.ip_address,
        HTTP_PORT_NUM,
        nodes_metrics_info,
        beacon_service_name,
        validator_service_name,
        beacon_multiaddr,
        beacon_peer_id,
        snooper_enabled,
        snooper_engine_context,
        validator_keystore_files_artifact_uuid=node_keystore_files.files_artifact_uuid
        if node_keystore_files
        else "",
    )


def get_beacon_config(
    plan,
    el_cl_genesis_data,
    jwt_file,
    network,
    beacon_image,
    service_name,
    bootnode_contexts,
    el_client_context,
    log_level,
    bn_min_cpu,
    bn_max_cpu,
    bn_min_mem,
    bn_max_mem,
    snooper_enabled,
    snooper_engine_context,
    extra_params,
    extra_labels,
    persistent,
    cl_volume_size,
    tolerations,
):
    # If snooper is enabled use the snooper engine context, otherwise use the execution client context
    if snooper_enabled:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            snooper_engine_context.ip_addr,
            snooper_engine_context.engine_rpc_port_num,
        )
    else:
        EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
            el_client_context.ip_addr,
            el_client_context.engine_rpc_port_num,
        )

    cmd = [
        "--accept-terms-of-use=true",  # it's mandatory in order to run the node
        "--datadir=" + BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--execution-endpoint=" + EXECUTION_ENGINE_ENDPOINT,
        "--rpc-host=0.0.0.0",
        "--rpc-port={0}".format(RPC_PORT_NUM),
        "--grpc-gateway-host=0.0.0.0",
        "--grpc-gateway-corsdomain=*",
        "--grpc-gateway-port={0}".format(HTTP_PORT_NUM),
        "--p2p-host-ip=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--p2p-tcp-port={0}".format(DISCOVERY_TCP_PORT_NUM),
        "--p2p-udp-port={0}".format(DISCOVERY_UDP_PORT_NUM),
        "--min-sync-peers={0}".format(MIN_PEERS),
        "--verbosity=" + log_level,
        "--slots-per-archive-point={0}".format(32 if constants.ARCHIVE_MODE else 8192),
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # Set per Pari's recommendation to reduce noise
        "--subscribe-all-subnets=true",
        "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--enable-debug-rpc-endpoints=true",
        # vvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(BEACON_MONITORING_PORT_NUM)
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    if network not in constants.PUBLIC_NETWORKS:
        cmd.append("--p2p-static-id=true")
        cmd.append(
            "--chain-config-file="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/config.yaml"
        )
        cmd.append(
            "--genesis-state="
            + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis.ssz",
        )
        if network == constants.NETWORK_NAME.kurtosis:
            if bootnode_contexts != None:
                for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]:
                    cmd.append("--peer=" + ctx.multiaddr)
                    cmd.append("--bootstrap-node=" + ctx.enr)
        elif network == constants.NETWORK_NAME.ephemery:
            cmd.append(
                "--genesis-beacon-api-url=" + constants.CHECKPOINT_SYNC_URL[network]
            )
            cmd.append(
                "--checkpoint-sync-url=" + constants.CHECKPOINT_SYNC_URL[network]
            )
            cmd.append(
                "--bootstrap-node="
                + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
                + "/boot_enr.yaml"
            )
        else:  # Devnets
            # TODO Remove once checkpoint sync is working for verkle
            if constants.NETWORK_NAME.verkle not in network:
                cmd.append(
                    "--genesis-beacon-api-url=https://checkpoint-sync.{0}.ethpandaops.io".format(
                        network
                    )
                )
                cmd.append(
                    "--checkpoint-sync-url=https://checkpoint-sync.{0}.ethpandaops.io".format(
                        network
                    )
                )
            cmd.append(
                "--bootstrap-node="
                + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
                + "/boot_enr.yaml"
            )
    else:  # Public network
        cmd.append("--{}".format(network))
        cmd.append("--genesis-beacon-api-url=" + constants.CHECKPOINT_SYNC_URL[network])
        cmd.append("--checkpoint-sync-url=" + constants.CHECKPOINT_SYNC_URL[network])

    if len(extra_params) > 0:
        # we do the for loop as otherwise its a proto repeated array
        cmd.extend([param for param in extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=cl_volume_size,
        )

    return ServiceConfig(
        image=beacon_image,
        ports=BEACON_NODE_USED_PORTS,
        cmd=cmd,
        files=files,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ready_conditions=cl_node_ready_conditions.get_ready_conditions(
            BEACON_HTTP_PORT_ID
        ),
        min_cpu=bn_min_cpu,
        max_cpu=bn_max_cpu,
        min_memory=bn_min_mem,
        max_memory=bn_max_mem,
        labels=shared_utils.label_maker(
            constants.CL_CLIENT_TYPE.prysm,
            constants.CLIENT_TYPES.cl,
            beacon_image,
            el_client_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
    )


def get_validator_config(
    el_cl_genesis_data,
    validator_image,
    service_name,
    log_level,
    beacon_rpc_endpoint,
    beacon_http_endpoint,
    el_client_context,
    node_keystore_files,
    v_min_cpu,
    v_max_cpu,
    v_min_mem,
    v_max_mem,
    extra_params,
    extra_labels,
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
    persistent,
    tolerations,
):
    validator_keys_dirpath = shared_utils.path_join(
        VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.prysm_relative_dirpath,
    )
    validator_secrets_dirpath = shared_utils.path_join(
        PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        prysm_password_relative_filepath,
    )

    cmd = [
        "--accept-terms-of-use=true",  # it's mandatory in order to run the node
        "--chain-config-file="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--beacon-rpc-gateway-provider=" + beacon_http_endpoint,
        "--beacon-rpc-provider=" + beacon_rpc_endpoint,
        "--wallet-dir=" + validator_keys_dirpath,
        "--wallet-password-file=" + validator_secrets_dirpath,
        # "--datadir=" + VALIDATOR_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--monitoring-port={0}".format(VALIDATOR_MONITORING_PORT_NUM),
        "--verbosity=" + log_level,
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(VALIDATOR_MONITORING_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
        "--graffiti="
        + constants.CL_CLIENT_TYPE.prysm
        + "-"
        + el_client_context.client_name,
    ]

    if len(extra_params) > 0:
        # we do the for loop as otherwise its a proto repeated array
        cmd.extend([param for param in extra_params])
    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        VALIDATOR_KEYS_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
        PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: prysm_password_artifact_uuid,
    }
    if persistent:
        files[VALIDATOR_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name)
        )

    return ServiceConfig(
        image=validator_image,
        ports=VALIDATOR_NODE_USED_PORTS,
        cmd=cmd,
        files=files,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=v_min_cpu,
        max_cpu=v_max_cpu,
        min_memory=v_min_mem,
        max_memory=v_max_mem,
        labels=shared_utils.label_maker(
            constants.CL_CLIENT_TYPE.prysm,
            constants.CLIENT_TYPES.validator,
            validator_image,
            el_client_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
    )


def new_prysm_launcher(
    el_cl_genesis_data,
    jwt_file,
    network,
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
        prysm_password_artifact_uuid=prysm_password_artifact_uuid,
        prysm_password_relative_filepath=prysm_password_relative_filepath,
    )
