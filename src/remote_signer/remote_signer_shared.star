shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

REMOTE_SIGNER_KEYS_MOUNTPOINT = "/keystores"

REMOTE_SIGNER_HTTP_PORT_NUM = 9000
REMOTE_SIGNER_METRICS_PORT_NUM = 9001
METRICS_PATH = "/metrics"

REMOTE_SIGNER_USED_PORTS = {
    constants.REMOTE_SIGNER_HTTP_PORT_ID: shared_utils.new_port_spec(
        REMOTE_SIGNER_HTTP_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    constants.METRICS_PORT_ID: shared_utils.new_port_spec(
        REMOTE_SIGNER_METRICS_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

# Returns public_ports for the remote signer service.
def get_public_ports(port_publisher, remote_signer_index):
    public_ports = {}
    if port_publisher.remote_signer_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "remote-signer", port_publisher, remote_signer_index
        )
        public_port_assignments = {
            constants.REMOTE_SIGNER_HTTP_PORT_ID: public_ports_for_component[0],
            constants.METRICS_PORT_ID: public_ports_for_component[1],
        }
        public_ports = shared_utils.get_port_specs(public_port_assignments)
    return public_ports


def apply_resource_limits(config_args, participant):
    if participant.remote_signer_min_cpu > 0:
        config_args["min_cpu"] = participant.remote_signer_min_cpu
    if participant.remote_signer_max_cpu > 0:
        config_args["max_cpu"] = participant.remote_signer_max_cpu
    if participant.remote_signer_min_mem > 0:
        config_args["min_memory"] = participant.remote_signer_min_mem
    if participant.remote_signer_max_mem > 0:
        config_args["max_memory"] = participant.remote_signer_max_mem


def get_labels(client, participant, image, vc_type, remote_signer_index):
    return shared_utils.label_maker(
        client=client,
        client_type=constants.CLIENT_TYPES.remote_signer,
        image=image[-constants.MAX_LABEL_LENGTH :],
        connected_client=vc_type,
        extra_labels=participant.remote_signer_extra_labels
        | {constants.NODE_INDEX_LABEL_KEY: str(remote_signer_index + 1)},
        supernode=participant.supernode,
    )
