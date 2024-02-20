constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
validator_client_shared = import_module("./shared.star")

PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/prysm-password"
PRYSM_BEACON_RPC_PORT = 4000


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
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
    tolerations,
    node_selectors,
):
    validator_keys_dirpath = shared_utils.path_join(
        validator_client_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT,
        node_keystore_files.prysm_relative_dirpath,
    )
    validator_secrets_dirpath = shared_utils.path_join(
        PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER,
        prysm_password_relative_filepath,
    )

    cmd = [
        "--accept-terms-of-use=true",  # it's mandatory in order to run the node
        "--chain-config-file="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--beacon-rpc-provider="
        + "{}:{}".format(
            cl_client_context.ip_addr,
            PRYSM_BEACON_RPC_PORT,
        ),
        "--beacon-rest-api-provider=" + beacon_http_url,
        "--wallet-dir=" + validator_keys_dirpath,
        "--wallet-password-file=" + validator_secrets_dirpath,
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(
            validator_client_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM
        ),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
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
        PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: prysm_password_artifact_uuid,
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
            constants.VC_CLIENT_TYPE.prysm,
            constants.CLIENT_TYPES.validator,
            image,
            cl_client_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )
