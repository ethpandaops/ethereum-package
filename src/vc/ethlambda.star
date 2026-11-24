constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./vc_shared.star")

ETHLAMBDA_BINARY_PATH = "/usr/local/bin/ethlambda"

API_TOKEN_FILENAME = "api-token.txt"

REMOTE_SIGNER_VALIDATORS_DIRPATH = "/validator-definitions"
VALIDATOR_DEFINITIONS_FILENAME = "validator_definitions.yml"

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

    setup_cmds = []
    validators_dirpath = validator_keys_dirpath
    if remote_signer_context != None:
        validators_dirpath = REMOTE_SIGNER_VALIDATORS_DIRPATH
        definition_entry = " ".join(
            [
                "printf '%s\\n'",
                "'- enabled: true'",
                '"  voting_public_key: \\"${key##*/}\\""',
                "'  type: web3signer'",
                "'  url: \"{0}\"'".format(remote_signer_context.http_url),
            ]
        )
        setup_cmds.append(
            "mkdir -p {0} && for key in {1}/0x*; do {2}; done > {3}".format(
                validators_dirpath,
                validator_keys_dirpath,
                definition_entry,
                shared_utils.path_join(
                    validators_dirpath, VALIDATOR_DEFINITIONS_FILENAME
                ),
            )
        )

    cmd = [
        ETHLAMBDA_BINARY_PATH,
        "validator",
        "--beacon-nodes=" + ",".join(beacon_http_urls),
        "--validators-dir=" + validators_dirpath,
        "--secrets-dir=" + validator_secrets_dirpath,
        "--init-slashing-protection",
        "--http-address=0.0.0.0",
        "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        # burn address - If unset, the validator will scream in its logs
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
    ]

    if network_params.gas_limit > 0:
        cmd.append("--gas-limit={0}".format(network_params.gas_limit))

    if network_params.pq_fork_epoch != constants.FAR_FUTURE_EPOCH:
        if network_params.vrf_state_url != "":
            cmd.append("--vrf-state-url=" + network_params.vrf_state_url)
        if network_params.xmss_cache_url != "":
            cmd.append("--xmss-cache-url=" + network_params.xmss_cache_url)

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

    if keymanager_enabled:
        files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = keymanager_file
        setup_cmds.append(
            "cp {0} {1}".format(
                constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
                shared_utils.path_join(validators_dirpath, API_TOKEN_FILENAME),
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
