constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./shared.star")


VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARNING",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
}


def get_config(
    participant,
    el_cl_genesis_data,
    image,
    global_log_level,
    beacon_http_url,
    cl_context,
    remote_signer_context,
    full_name,
    tolerations,
    node_selectors,
    port_publisher,
    vc_index,
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
        "--beacon-node-urls=" + beacon_http_url,
        "--fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        "--graffiti=" + full_name,
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

    public_ports = {}
    if port_publisher.vc_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "vc", port_publisher, vc_index
        )
        public_port_assignments = {
            constants.METRICS_PORT_ID: public_ports_for_component[0]
        }
        public_ports = shared_utils.get_port_specs(public_port_assignments)

    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "cmd": cmd,
        "files": files,
        "env_vars": participant.vc_extra_env_vars,
        "labels": shared_utils.label_maker(
            client=constants.VC_TYPE.vero,
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
