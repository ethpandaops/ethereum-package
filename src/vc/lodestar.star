constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./vc_shared.star")


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
        "validator",
        "--logLevel=" + log_level,
        "--paramsFile="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--beaconNodes=" + ",".join(beacon_http_urls),
        "--suggestedFeeRecipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics.address=0.0.0.0",
        "--metrics.port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
        "--useProduceBlockV3",
        "--disableKeystoresThreadPool",
    ]

    if remote_signer_context == None:
        cmd.extend(
            [
                "--keystoresDir=" + validator_keys_dirpath,
                "--secretsDir=" + validator_secrets_dirpath,
            ]
        )
    else:
        cmd.extend(
            [
                "--externalSigner.url={0}".format(remote_signer_context.http_url),
                "--externalSigner.fetch",
            ]
        )

    keymanager_api_cmd = [
        "--keymanager",
        "--keymanager.authEnabled=true",
        "--keymanager.port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--keymanager.address=0.0.0.0",
        "--keymanager.cors=*",
        "--keymanager.tokenFile=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
    ]

    if network_params.gas_limit > 0:
        cmd.append("--defaultGasLimit={0}".format(network_params.gas_limit))

    if len(participant.vc_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.vc_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
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

    env_vars = shared_utils.with_otel_env_vars(
        participant.vc_extra_env_vars,
        otel_otlp_grpc_url,
        full_name,
    )
    if network_params.preset == "minimal":
        env_vars["LODESTAR_PRESET"] = "minimal"

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.vc_enabled,
        "cmd": cmd,
        "files": files,
        "env_vars": env_vars,
        "labels": vc_shared.get_labels(
            constants.VC_TYPE.lodestar, participant, image, cl_context, vc_index
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    vc_shared.apply_binary_override(
        config_args,
        cmd,
        vc_binary_artifact,
        "/usr/app/packages/cli/bin/lodestar",
        "node /usr/app/packages/cli/bin/lodestar",
    )

    vc_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)
