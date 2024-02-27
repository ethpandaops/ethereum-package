constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
validator_client_shared = import_module("./shared.star")


def get_config(
    el_cl_genesis_data,
    image,
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
    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            validator_client_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT,
            node_keystore_files.teku_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            validator_client_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT,
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
        "--validators-graffiti="
        + cl_client_context.client_name
        + "-"
        + el_client_context.client_name,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics-enabled=true",
        "--metrics-host-allowlist=*",
        "--metrics-interface=0.0.0.0",
        "--metrics-port={0}".format(
            validator_client_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM
        ),
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
            constants.VC_CLIENT_TYPE.teku,
            constants.CLIENT_TYPES.validator,
            image,
            cl_client_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )
