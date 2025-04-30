constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./shared.star")

RUST_BACKTRACE_ENVVAR_NAME = "RUST_BACKTRACE"
RUST_FULL_BACKTRACE_KEYWORD = "full"

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "trace",
}


def get_config(
    participant,
    el_cl_genesis_data,
    image,
    global_log_level,
    beacon_http_url,
    cl_context,
    el_context,
    full_name,
    node_keystore_files,
    tolerations,
    node_selectors,
    keymanager_enabled,
    network_params,
    port_publisher,
    vc_index,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, VERBOSITY_LEVELS
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
        "--beacon-nodes=" + beacon_http_url,
        # "--enable-doppelganger-protection", // Disabled to not have to wait 2 epochs before validator can start
        # burn address - If unset, the validator will scream in its logs
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-allow-origin=*",
        "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
        "--graffiti=" + full_name,
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

    if len(participant.vc_extra_params):
        cmd.extend([param for param in participant.vc_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
    }
    env = {RUST_BACKTRACE_ENVVAR_NAME: RUST_FULL_BACKTRACE_KEYWORD}
    env.update(participant.vc_extra_env_vars)

    public_ports = {}
    public_keymanager_port_assignment = {}
    if port_publisher.vc_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "vc", port_publisher, vc_index
        )
        public_port_assignments = {
            constants.METRICS_PORT_ID: public_ports_for_component[0]
        }
        public_keymanager_port_assignment = {
            constants.VALIDATOR_HTTP_PORT_ID: public_ports_for_component[1]
        }
        public_ports = shared_utils.get_port_specs(public_port_assignments)

    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    if keymanager_enabled:
        cmd.extend(keymanager_api_cmd)
        ports.update(vc_shared.VALIDATOR_KEYMANAGER_USED_PORTS)
        public_ports.update(
            shared_utils.get_port_specs(public_keymanager_port_assignment)
        )

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "cmd": cmd,
        "files": files,
        "env_vars": env,
        "labels": shared_utils.label_maker(
            client=constants.VC_TYPE.lighthouse,
            client_type=constants.CLIENT_TYPES.validator,
            image=image[-constants.MAX_LABEL_LENGTH :],
            connected_client=cl_context.client_name,
            extra_labels=participant.vc_extra_labels,
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if participant.vc_min_cpu > 0:
        config_args["min_cpu"] = participant.vc_min_cpu
    if participant.vc_max_cpu > 0:
        config_args["max_cpu"] = participant.vc_max_cpu
    if participant.vc_min_mem > 0:
        config_args["min_memory"] = participant.vc_min_mem
    if participant.vc_max_mem > 0:
        config_args["max_memory"] = participant.vc_max_mem
    return ServiceConfig(**config_args)
