shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

VALIDATOR_HTTP_PORT_NUM = 5056
VALIDATOR_CLIENT_METRICS_PORT_NUM = 8080
METRICS_PATH = "/metrics"

VALIDATOR_CLIENT_USED_PORTS = {
    constants.METRICS_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_CLIENT_METRICS_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

VALIDATOR_KEYMANAGER_USED_PORTS = {
    constants.VALIDATOR_HTTP_PORT_ID: shared_utils.new_port_spec(
        VALIDATOR_HTTP_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "trace",
}


# Returns (public_ports, public_keymanager_port_assignment) for the VC service.
# `with_keymanager` indicates whether the client exposes a keymanager port at
# all (vero does not); the assignment is only merged into the public ports by
# the client when the keymanager is actually enabled.
def get_public_ports(port_publisher, vc_index, with_keymanager=True):
    public_ports = {}
    public_keymanager_port_assignment = {}
    if port_publisher.vc_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "vc", port_publisher, vc_index
        )
        public_port_assignments = {
            constants.METRICS_PORT_ID: public_ports_for_component[0]
        }
        if with_keymanager:
            public_keymanager_port_assignment = {
                constants.VALIDATOR_HTTP_PORT_ID: public_ports_for_component[1]
            }
        public_ports = shared_utils.get_port_specs(public_port_assignments)
    return public_ports, public_keymanager_port_assignment


# Add extra mounts - automatically handle file uploads
def apply_extra_mounts(plan, participant, extra_files_artifacts, files):
    processed_mounts = shared_utils.process_extra_mounts(
        plan, participant.vc_extra_mounts, extra_files_artifacts
    )
    for mount_path, artifact in processed_mounts.items():
        files[mount_path] = artifact


# Binary injection - mount the custom binary directory and override the
# entrypoint/cmd so the injected binary is copied into place and executed.
def apply_binary_override(
    config_args, cmd, vc_binary_artifact, binary_dest, exec_command
):
    if vc_binary_artifact == None:
        return
    config_args["files"]["/opt/bin"] = vc_binary_artifact.artifact
    config_args["entrypoint"] = ["sh", "-c"]
    config_args["cmd"] = [
        "cp /opt/bin/{0} {1} && {2} ".format(
            vc_binary_artifact.filename, binary_dest, exec_command
        )
        + " ".join(cmd)
    ]


def apply_resource_limits(config_args, participant):
    if participant.vc_min_cpu > 0:
        config_args["min_cpu"] = participant.vc_min_cpu
    if participant.vc_max_cpu > 0:
        config_args["max_cpu"] = participant.vc_max_cpu
    if participant.vc_min_mem > 0:
        config_args["min_memory"] = participant.vc_min_mem
    if participant.vc_max_mem > 0:
        config_args["max_memory"] = participant.vc_max_mem
    if len(participant.vc_devices) > 0:
        config_args["devices"] = participant.vc_devices


def get_labels(client, participant, image, cl_context, vc_index):
    return shared_utils.label_maker(
        client=client,
        client_type=constants.CLIENT_TYPES.validator,
        image=image[-constants.MAX_LABEL_LENGTH :],
        connected_client=cl_context.client_name,
        extra_labels=participant.vc_extra_labels
        | {constants.NODE_INDEX_LABEL_KEY: str(vc_index + 1)},
        supernode=participant.supernode,
    )
