constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
validator_client_shared = import_module("./shared.star")

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
        "validator",
        "--logLevel=" + log_level,
        "--paramsFile="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--beaconNodes=" + beacon_http_url,
        "--keystoresDir=" + validator_keys_dirpath,
        "--secretsDir=" + validator_secrets_dirpath,
        "--suggestedFeeRecipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics.address=0.0.0.0",
        "--metrics.port={0}".format(
            validator_client_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM
        ),
        # ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
        "--graffiti="
        + cl_client_context.client_name
        + "-"
        + el_client_context.client_name,
    ]

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
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
        private_ip_address_placeholder=validator_client_shared.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=v_min_cpu,
        max_cpu=v_max_cpu,
        min_memory=v_min_mem,
        max_memory=v_max_mem,
        labels=shared_utils.label_maker(
            constants.VC_CLIENT_TYPE.lodestar,
            constants.CLIENT_TYPES.validator,
            image,
            cl_client_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )
