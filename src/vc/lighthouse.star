constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./vc_shared.star")

RUST_BACKTRACE_ENVVAR_NAME = "RUST_BACKTRACE"
RUST_FULL_BACKTRACE_KEYWORD = "full"


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
    distributed=False,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, vc_shared.VERBOSITY_LEVELS
    )

    validator_keys_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.raw_keys_relative_dirpath,
    )
    validator_secrets_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.raw_secrets_relative_dirpath,
    )

    cmd = [
        "lighthouse",
        "vc",
        "--debug-level=" + log_level,
        "--testnet-dir=" + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER,
        "--validators-dir=" + validator_keys_dirpath,
        # NOTE: When secrets-dir is specified, we can't add the --data-dir flag
        "--secrets-dir=" + validator_secrets_dirpath,
        # The node won't have a slashing protection database and will fail to start otherwise
        "--init-slashing-protection",
        "--beacon-nodes=" + ",".join(beacon_http_urls),
        # "--enable-doppelganger-protection", // Disabled to not have to wait 2 epochs before validator can start
        # burn address - If unset, the validator will scream in its logs
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-allow-origin=*",
        "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
    ]

    keymanager_api_cmd = [
        "--http",
        "--http-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--http-address=0.0.0.0",
        "--http-allow-origin=*",
        "--unencrypted-http-transport",
    ]

    if network_params.gas_limit > 0:
        cmd.append("--gas-limit={0}".format(network_params.gas_limit))
        cmd.append("--builder-proposals")

    if distributed:
        cmd.append("--distributed")
        if "--builder-proposals" not in cmd:
            cmd.append("--builder-proposals")
        cmd.append("--use-long-timeouts")

    telemetry_url = (
        otel_otlp_grpc_url if otel_otlp_grpc_url != None else tempo_otlp_grpc_url
    )
    if telemetry_url != None:
        cmd.append("--telemetry-collector-url={}".format(telemetry_url))
        cmd.append("--telemetry-service-name={}".format(service_name))

    if len(participant.vc_extra_params):
        cmd.extend([param for param in participant.vc_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
    }
    env = {RUST_BACKTRACE_ENVVAR_NAME: RUST_FULL_BACKTRACE_KEYWORD}
    env.update(
        shared_utils.with_otel_env_vars(
            participant.vc_extra_env_vars,
            otel_otlp_grpc_url,
            full_name,
        )
    )

    public_ports, public_keymanager_port_assignment = vc_shared.get_public_ports(
        port_publisher, vc_index
    )

    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    if keymanager_enabled:
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
        "env_vars": env,
        "labels": vc_shared.get_labels(
            constants.VC_TYPE.lighthouse, participant, image, cl_context, vc_index
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    vc_shared.apply_binary_override(
        config_args,
        cmd,
        vc_binary_artifact,
        "/usr/local/bin/lighthouse",
        "lighthouse",
    )

    vc_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)
