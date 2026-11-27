constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
remote_signer_shared = import_module("./remote_signer_shared.star")


def get_config(
    plan,
    participant,
    el_cl_genesis_data,
    image,
    service_name,
    remote_signer_context,
    vc_type,
    full_name,
    node_keystore_files,
    tolerations,
    node_selectors,
    port_publisher,
    remote_signer_index,
    tempo_otlp_grpc_url=None,
    otel_otlp_grpc_url=None,
):
    validator_keys_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            remote_signer_shared.REMOTE_SIGNER_KEYS_MOUNTPOINT,
            node_keystore_files.teku_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            remote_signer_shared.REMOTE_SIGNER_KEYS_MOUNTPOINT,
            node_keystore_files.teku_secrets_relative_dirpath,
        )

    cmd = [
        "--network=custom",
        "--network-custom-config-path="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--host=0.0.0.0",
        "--port={0}".format(remote_signer_shared.REMOTE_SIGNER_HTTP_PORT_NUM),
        "--metrics-host=0.0.0.0",
        "--metrics-port={0}".format(remote_signer_shared.REMOTE_SIGNER_METRICS_PORT_NUM),
        "--keystores-path=" + validator_keys_dirpath,
        "--keystores-passwords-path=" + validator_secrets_dirpath,
    ]

    if len(participant.remote_signer_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.remote_signer_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        remote_signer_shared.REMOTE_SIGNER_KEYS_MOUNTPOINT: node_keystore_files.files_artifact_uuid,
    }

    public_ports = remote_signer_shared.get_public_ports(port_publisher, remote_signer_index)

    ports = {}
    ports.update(remote_signer_shared.REMOTE_SIGNER_USED_PORTS)

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.remote_signer_enabled,
        "cmd": cmd,
        "files": files,
        "env_vars": shared_utils.with_otel_env_vars(
            participant.remote_signer_extra_env_vars,
            otel_otlp_grpc_url,
            full_name,
        ),
        "labels": remote_signer_shared.get_labels(
            constants.REMOTE_SIGNER_TYPE.py3signer, participant, image, vc_type, remote_signer_index
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    remote_signer_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)
