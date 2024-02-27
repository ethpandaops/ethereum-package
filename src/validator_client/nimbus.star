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
            node_keystore_files.nimbus_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            validator_client_shared.VALIDATOR_CLIENT_KEYS_MOUNTPOINT,
            node_keystore_files.raw_secrets_relative_dirpath,
        )

    cmd = [
        "--beacon-node=" + beacon_http_url,
        "--validators-dir=" + validator_keys_dirpath,
        "--secrets-dir=" + validator_secrets_dirpath,
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-port={0}".format(
            validator_client_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM
        ),
        "--graffiti="
        + cl_client_context.client_name
        + "-"
        + el_client_context.client_name,
    ]

    if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in extra_params])

    files = {
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
            constants.VC_CLIENT_TYPE.nimbus,
            constants.CLIENT_TYPES.validator,
            image,
            cl_client_context.client_name,
            extra_labels,
        ),
        user=User(uid=0, gid=0),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )
