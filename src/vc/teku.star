constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./shared.star")


def get_config(
    el_cl_genesis_data,
    keymanager_file,
    image,
    beacon_http_url,
    cl_context,
    el_context,
    full_name,
    node_keystore_files,
    vc_min_cpu,
    vc_max_cpu,
    vc_min_mem,
    vc_max_mem,
    extra_params,
    extra_env_vars,
    extra_labels,
    tolerations,
    node_selectors,
    keymanager_enabled,
    port_publisher,
    vc_index,
):
    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_secrets_relative_dirpath,
        )

    cmd = [
        "validator-client",
        "--network="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--beacon-node-api-endpoint=" + beacon_http_url,
        "--validator-keys={0}:{1}".format(
            validator_keys_dirpath,
            validator_secrets_dirpath,
        ),
        "--validators-proposer-default-fee-recipient="
        + constants.VALIDATING_REWARDS_ACCOUNT,
        "--validators-graffiti=" + full_name,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics-enabled=true",
        "--metrics-host-allowlist=*",
        "--metrics-interface=0.0.0.0",
        "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
    ]

    keymanager_api_cmd = [
        "--validator-api-enabled=true",
        "--validator-api-host-allowlist=*",
        "--validator-api-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--validator-api-interface=0.0.0.0",
        "--validator-api-bearer-file=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
        "--Xvalidator-api-ssl-enabled=false",
        "--Xvalidator-api-unsafe-hosts-enabled=true",
    ]

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
    }

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
        files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = keymanager_file
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
        "env_vars": extra_env_vars,
        "labels": shared_utils.label_maker(
            constants.CL_TYPE.teku,
            constants.CLIENT_TYPES.validator,
            image,
            cl_context.client_name,
            extra_labels,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if vc_min_cpu > 0:
        config_args["min_cpu"] = vc_min_cpu

    if vc_max_cpu > 0:
        config_args["max_cpu"] = vc_max_cpu

    if vc_min_mem > 0:
        config_args["min_memory"] = vc_min_mem

    if vc_max_mem > 0:
        config_args["max_memory"] = vc_max_mem

    return ServiceConfig(**config_args)
