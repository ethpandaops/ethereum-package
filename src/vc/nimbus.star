constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./shared.star")


def get_config(
    el_cl_genesis_data,
    image,
    keymanager_file,
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
):
    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            vc_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT,
            node_keystore_files.nimbus_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            vc_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT,
            node_keystore_files.raw_secrets_relative_dirpath,
        )

    cmd = [
        "--beacon-node=" + beacon_http_url,
        "--validators-dir=" + validator_keys_dirpath,
        "--secrets-dir=" + validator_secrets_dirpath,
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        "--keymanager",
        "--keymanager-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--keymanager-address=0.0.0.0",
        "--keymanager-allow-origin=*",
        "--keymanager-token-file=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        "--graffiti=" + full_name,
    ]

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    files = {
        vc_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT: node_keystore_files.files_artifact_uuid,
        constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS: keymanager_file,
    }

    return ServiceConfig(
        image=image,
        ports=vc_shared.VALIDATOR_CLIENT_USED_PORTS,
        cmd=cmd,
        env_vars=extra_env_vars,
        files=files,
        private_ip_address_placeholder=vc_shared.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=vc_min_cpu,
        max_cpu=vc_max_cpu,
        min_memory=vc_min_mem,
        max_memory=vc_max_mem,
        labels=shared_utils.label_maker(
            constants.VC_TYPE.nimbus,
            constants.CLIENT_TYPES.validator,
            image,
            cl_context.client_name,
            extra_labels,
        ),
        user=User(uid=0, gid=0),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )
