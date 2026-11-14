constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./vc_shared.star")

ETHLAMBDA_BINARY_PATH = "/usr/local/bin/ethlambda"

# ethlambda reads its validators from a Lighthouse-style
# validator_definitions.yml rather than by scanning a keystore directory, so
# one is generated at container start into this writable directory, pointing
# at the keystores mounted from the keystore artifact. The keymanager API
# persists imported keys and its bearer token here too.
VALIDATORS_DIRPATH_ON_SERVICE_CONTAINER = "/data/ethlambda/validators"
VALIDATOR_DEFINITIONS_FILENAME = "validator_definitions.yml"
API_TOKEN_FILENAME = "api-token.txt"

# ethlambda filters its logs through RUST_LOG (tracing's EnvFilter).
LOG_LEVEL_ENV_VAR = "RUST_LOG"


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
        ETHLAMBDA_BINARY_PATH,
        "validator",
        "--beacon-nodes=" + ",".join(beacon_http_urls),
        "--validators-dir=" + VALIDATORS_DIRPATH_ON_SERVICE_CONTAINER,
        "--secrets-dir=" + validator_secrets_dirpath,
        "--http-address=0.0.0.0",
        "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        # burn address - If unset, the validator will scream in its logs
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
    ]

    keymanager_api_cmd = [
        "--enable-keymanager",
        "--keymanager-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
    ]

    if len(participant.vc_extra_params) > 0:
        cmd.extend([param for param in participant.vc_extra_params])

    files = {
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
    }

    public_ports, public_keymanager_port_assignment = vc_shared.get_public_ports(
        port_publisher, vc_index
    )

    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    # Shell commands run before the client starts. The definitions file is
    # only written when absent, so keys imported through the keymanager API
    # survive a restart.
    definitions_filepath = shared_utils.path_join(
        VALIDATORS_DIRPATH_ON_SERVICE_CONTAINER, VALIDATOR_DEFINITIONS_FILENAME
    )
    definition_entry = (
        'printf -- \'- enabled: true\\n  voting_public_key: "%s"\\n'
        + "  voting_keystore_path: {0}/%s/voting-keystore.json\\n"
        + "  voting_keystore_password_path: {1}/%s\\n'"
        + ' "$pubkey" "$pubkey" "$pubkey" >> {2}'
    ).format(validator_keys_dirpath, validator_secrets_dirpath, definitions_filepath)
    setup_cmds = [
        "mkdir -p " + VALIDATORS_DIRPATH_ON_SERVICE_CONTAINER,
        (
            "if [ ! -f {0} ]; then touch {0}; for dir in {1}/*; do "
            + 'pubkey=$(basename "$dir"); {2}; done; fi'
        ).format(definitions_filepath, validator_keys_dirpath, definition_entry),
    ]

    if keymanager_enabled:
        # Serve the package-wide keymanager token instead of a generated one,
        # matching the other validator clients.
        files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = keymanager_file
        setup_cmds.append(
            "cp {0} {1}".format(
                constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
                shared_utils.path_join(
                    VALIDATORS_DIRPATH_ON_SERVICE_CONTAINER, API_TOKEN_FILENAME
                ),
            )
        )
        cmd.extend(keymanager_api_cmd)
        ports.update(vc_shared.VALIDATOR_KEYMANAGER_USED_PORTS)
        public_ports.update(
            shared_utils.get_port_specs(public_keymanager_port_assignment)
        )

    vc_shared.apply_extra_mounts(plan, participant, extra_files_artifacts, files)

    # Binary injection - mount custom binary directory if provided
    if vc_binary_artifact != None:
        files["/opt/bin"] = vc_binary_artifact.artifact
        setup_cmds.append(
            "cp /opt/bin/{0} {1}".format(
                vc_binary_artifact.filename, ETHLAMBDA_BINARY_PATH
            )
        )

    env_vars = {LOG_LEVEL_ENV_VAR: log_level}
    env_vars.update(
        shared_utils.with_otel_env_vars(
            participant.vc_extra_env_vars,
            otel_otlp_grpc_url,
            full_name,
        )
    )

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.vc_enabled,
        "entrypoint": ["sh", "-c"],
        "cmd": [" && ".join(setup_cmds + ["exec " + " ".join(cmd)])],
        "files": files,
        "env_vars": env_vars,
        "labels": vc_shared.get_labels(
            constants.VC_TYPE.ethlambda, participant, image, cl_context, vc_index
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    vc_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)
