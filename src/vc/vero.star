constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./vc_shared.star")


VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARNING",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
}


def get_config(
    plan,
    participant,
    el_cl_genesis_data,
    keymanager_file,
    image,
    service_name,
    global_log_level,
    beacon_http_urls,
    cl_context,
    remote_signer_context,
    full_name,
    node_keystore_files,
    tolerations,
    node_selectors,
    keymanager_enabled,
    network_params,
    port_publisher,
    vc_index,
    extra_files_artifacts,
    prysm_password_relative_filepath=None,
    prysm_password_artifact_uuid=None,
    tempo_otlp_grpc_url=None,
    otel_otlp_grpc_url=None,
    vc_binary_artifact=None,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, VERBOSITY_LEVELS
    )

    cmd = [
        "--network=custom",
        "--network-custom-config-path="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--remote-signer-url={0}".format(remote_signer_context.http_url),
        "--beacon-node-urls=" + ",".join(beacon_http_urls),
        "--fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        "--metrics-address=0.0.0.0",
        "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        "--log-level=" + log_level,
    ]

    if len(participant.vc_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.vc_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
    }

    public_ports, _ = vc_shared.get_public_ports(
        port_publisher, vc_index, with_keymanager=False
    )

    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    vc_shared.apply_extra_mounts(plan, participant, extra_files_artifacts, files)

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.vc_enabled,
        "cmd": cmd,
        "files": files,
        "env_vars": shared_utils.with_otel_env_vars(
            participant.vc_extra_env_vars,
            otel_otlp_grpc_url,
            full_name,
        ),
        "labels": vc_shared.get_labels(
            constants.VC_TYPE.vero, participant, image, cl_context, vc_index
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    vc_shared.apply_binary_override(
        config_args,
        cmd,
        vc_binary_artifact,
        "/usr/local/bin/vero",
        "vero",
    )

    vc_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)
