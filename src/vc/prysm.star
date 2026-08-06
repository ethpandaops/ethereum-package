constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./vc_shared.star")

PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/prysm-password"
PRYSM_BEACON_RPC_PORT = 4000

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "trace",
}


def get_config(
    plan,
    participant,
    el_cl_genesis_data,
    keymanager_file,
    image,
    service_name,
    global_log_level,
    beacon_http_urls,
    cl_context,
    remote_signer_context,
    full_name,
    node_keystore_files,
    tolerations,
    node_selectors,
    keymanager_enabled,
    network_params,
    port_publisher,
    vc_index,
    extra_files_artifacts,
    prysm_password_relative_filepath=None,
    prysm_password_artifact_uuid=None,
    tempo_otlp_grpc_url=None,
    otel_otlp_grpc_url=None,
    vc_binary_artifact=None,
):
    validator_keys_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.prysm_relative_dirpath,
    )
    validator_secrets_dirpath = shared_utils.path_join(
        PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        prysm_password_relative_filepath,
    )

    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, VERBOSITY_LEVELS
    )

    cmd = [
        "--accept-terms-of-use=true",  # it's mandatory in order to run the node
        "--verbosity=" + log_level,
        "--chain-config-file="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    # Setting --beacon-rest-api-provider implicitly enables the REST API (prysm#17159),
    # so the two providers are mutually exclusive. gRPC is only usable when the VC talks
    # straight to its own Prysm BN: blobber and snooper proxy the REST API only, and
    # --beacon-rpc-provider takes a single endpoint so it cannot express multiple BNs.
    use_beacon_api = (
        cl_context.client_name != constants.CL_TYPE.prysm
        or participant.blobber_enabled
        or beacon_http_urls != [cl_context.beacon_http_url]
    )

    if use_beacon_api:
        cmd.append("--beacon-rest-api-provider=" + ",".join(beacon_http_urls))
        cmd.append("--enable-beacon-rest-api")
    else:
        cmd.append("--beacon-rpc-provider=" + cl_context.beacon_grpc_url)

    if remote_signer_context == None:
        cmd.extend(
            [
                "--wallet-dir=" + validator_keys_dirpath,
                "--wallet-password-file=" + validator_secrets_dirpath,
            ]
        )
    else:
        cmd.extend(
            [
                "--remote-signer-url={0}".format(remote_signer_context.http_url),
                "--remote-signer-keys={0}/api/v1/eth2/publicKeys".format(
                    remote_signer_context.http_url
                ),
            ]
        )

    if network_params.gas_limit > 0:
        cmd.append("--suggested-gas-limit={0}".format(network_params.gas_limit))

    keymanager_api_cmd = [
        "--rpc",
        "--http-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--http-host=0.0.0.0",
        "--keymanager-token-file=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
    ]

    if len(participant.vc_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.vc_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
        PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: prysm_password_artifact_uuid,
    }

    public_ports, public_keymanager_port_assignment = vc_shared.get_public_ports(
        port_publisher, vc_index
    )

    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    if keymanager_enabled:
        files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = keymanager_file
        cmd.extend(keymanager_api_cmd)
        ports.update(vc_shared.VALIDATOR_KEYMANAGER_USED_PORTS)
        public_ports.update(
            shared_utils.get_port_specs(public_keymanager_port_assignment)
        )

    vc_shared.apply_extra_mounts(plan, participant, extra_files_artifacts, files)

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.vc_enabled,
        "cmd": cmd,
        "files": files,
        "env_vars": shared_utils.with_otel_env_vars(
            participant.vc_extra_env_vars,
            otel_otlp_grpc_url,
            full_name,
        ),
        "labels": vc_shared.get_labels(
            constants.VC_TYPE.prysm, participant, image, cl_context, vc_index
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
        "tty_enabled": True,
    }

    vc_shared.apply_binary_override(
        config_args,
        cmd,
        vc_binary_artifact,
        "/app/cmd/validator/validator",
        "/app/cmd/validator/validator",
    )

    vc_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)
