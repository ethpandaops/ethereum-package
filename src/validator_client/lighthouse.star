constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
validator_client_shared = import_module("./shared.star")

RUST_BACKTRACE_ENVVAR_NAME = "RUST_BACKTRACE"
RUST_FULL_BACKTRACE_KEYWORD = "full"

VERBOSITY_LEVELS = {
    constants.GLOBAL_CLIENT_LOG_LEVEL.error: "error",
    constants.GLOBAL_CLIENT_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_CLIENT_LOG_LEVEL.info: "info",
    constants.GLOBAL_CLIENT_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_CLIENT_LOG_LEVEL.trace: "trace",
}


def get_config(
    el_cl_genesis_data,
    image,
    participant_log_level,
    global_log_level,
    beacon_http_url,
    cl_client_context,
    el_client_context,
    node_keystore_files,
    v_min_cpu,
    v_max_cpu,
    v_min_mem,
    v_max_mem,
    extra_params,
    extra_labels,
    tolerations,
    node_selectors,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )

    validator_keys_dirpath = shared_utils.path_join(
        validator_client_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT,
        node_keystore_files.raw_keys_relative_dirpath,
    )
    validator_secrets_dirpath = shared_utils.path_join(
        validator_client_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT,
        node_keystore_files.raw_secrets_relative_dirpath,
    )

    cmd = [
        "lighthouse",
        "validator_client",
        "--debug-level=" + log_level,
        "--testnet-dir=" + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER,
        "--validators-dir=" + validator_keys_dirpath,
        # NOTE: When secrets-dir is specified, we can't add the --data-dir flag
        "--secrets-dir=" + validator_secrets_dirpath,
        # The node won't have a slashing protection database and will fail to start otherwise
        "--init-slashing-protection",
        "--beacon-nodes=" + beacon_http_url,
        # "--enable-doppelganger-protection", // Disabled to not have to wait 2 epochs before validator can start
        # burn address - If unset, the validator will scream in its logs
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-allow-origin=*",
        "--metrics-port={0}".format(
            validator_client_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM
        ),
        # ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
        "--graffiti="
        + cl_client_context.client_name
        + "-"
        + el_client_context.client_name,
    ]

    if len(extra_params):
        cmd.extend([param for param in extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        validator_client_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT: node_keystore_files.files_artifact_uuid,
    }

    return ServiceConfig(
        image=image,
        ports=validator_client_shared.VALIDATOR_CLIENT_USED_PORTS,
        cmd=cmd,
        files=files,
        env_vars={RUST_BACKTRACE_ENVVAR_NAME: RUST_FULL_BACKTRACE_KEYWORD},
        min_cpu=v_min_cpu,
        max_cpu=v_max_cpu,
        min_memory=v_min_mem,
        max_memory=v_max_mem,
        labels=shared_utils.label_maker(
            constants.VC_CLIENT_TYPE.lighthouse,
            constants.CLIENT_TYPES.validator,
            image,
            cl_client_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )
