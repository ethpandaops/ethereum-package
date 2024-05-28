constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./shared.star")

PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER = "/prysm-password"
PRYSM_BEACON_RPC_PORT = 4000
VALIDATOR_GRPC_PORT_NUM = 7500
VALDIATOR_GRPC_PORT_ID = "grpc"

EXTRA_PORTS = {
    VALDIATOR_GRPC_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_GRPC_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


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
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
    tolerations,
    node_selectors,
    keymanager_enabled,
):
    validator_keys_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
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
        "--wallet-dir=" + validator_keys_dirpath,
        "--wallet-password-file=" + validator_secrets_dirpath,
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--disable-monitoring=false",
        "--monitoring-host=0.0.0.0",
        "--monitoring-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ METRICS CONFIG ^^^^^^^^^^^^^^^^^^^^^
        "--graffiti=" + full_name,
    ]

    keymanager_api_cmd = [
        "--rpc",
        "--rpc-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--rpc-host=0.0.0.0",
        "--grpc-gateway-port={0}".format(VALIDATOR_GRPC_PORT_NUM),
        "--grpc-gateway-host=0.0.0.0",
        "--keymanager-token-file=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
    ]

    if cl_context.client_name != constants.CL_TYPE.prysm:
        cmd.append("--beacon-rpc-provider=" + beacon_http_url)
        cmd.append("--beacon-rest-api-provider=" + beacon_http_url)
        cmd.append("--enable-beacon-rest-api")
    else:  # we are using Prysm CL
        cmd.append("--beacon-rpc-provider=" + cl_context.beacon_grpc_url)
        cmd.append("--beacon-rest-api-provider=" + cl_context.beacon_grpc_url)

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
        PRYSM_PASSWORD_MOUNT_DIRPATH_ON_SERVICE_CONTAINER: prysm_password_artifact_uuid,
    }

    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    if keymanager_enabled:
        files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = keymanager_file
        cmd.extend(keymanager_api_cmd)
        ports.update(vc_shared.VALIDATOR_KEYMANAGER_USED_PORTS)
        ports.update(EXTRA_PORTS)

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        env_vars=extra_env_vars,
        files=files,
        min_cpu=vc_min_cpu,
        max_cpu=vc_max_cpu,
        min_memory=vc_min_mem,
        max_memory=vc_max_mem,
        labels=shared_utils.label_maker(
            constants.VC_TYPE.prysm,
            constants.CLIENT_TYPES.validator,
            image,
            cl_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )
