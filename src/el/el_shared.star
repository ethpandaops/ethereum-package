shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")


def get_general_el_public_port_specs(public_ports_for_component):
    public_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: public_ports_for_component[0],
        constants.UDP_DISCOVERY_PORT_ID: public_ports_for_component[0],
        constants.ENGINE_RPC_PORT_ID: public_ports_for_component[1],
        constants.METRICS_PORT_ID: public_ports_for_component[2],
    }
    public_ports = shared_utils.get_port_specs(public_port_assignments)
    return public_ports


# Returns the (tcp, udp) discovery ports: the first public port for the
# component when port publishing is enabled, otherwise the client's default.
def get_discovery_ports(public_ports_for_component, discovery_port_num):
    discovery_port = (
        public_ports_for_component[0]
        if public_ports_for_component
        else discovery_port_num
    )
    return discovery_port, discovery_port


# Returns the EL data volume size: the participant's override when set,
# otherwise the network-dependent default for the given EL type.
def get_volume_size(participant, network, el_type):
    volume_size_key = "devnets" if "devnet" in network else network
    return (
        int(participant.el_volume_size)
        if int(participant.el_volume_size) > 0
        else constants.VOLUME_SIZE[volume_size_key][el_type + "_volume_size"]
    )


# Returns the persistent Directory for the EL execution data dir.
def get_persistent_data_directory(participant, service_name, network, el_type):
    return Directory(
        persistent_key="data-{0}".format(service_name),
        size=get_volume_size(participant, network, el_type),
    )


# Resolves the ENR bootnode cmd argument for a discv5 EL client, parameterized
# by the client's bootnode flag (e.g. "--bootnodes="). Returns None when no
# bootnode argument should be added.
def get_bootnode_arg(
    plan, launcher, network, existing_el_clients, bootnodoor_el_enr, flag
):
    if bootnodoor_el_enr != None:
        return flag + bootnodoor_el_enr
    elif (
        network == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in network
    ):
        el_bootnode_enrs = [
            ctx.enr
            for ctx in existing_el_clients[: constants.MAX_ENODE_ENTRIES]
            if ctx.enr
        ]
        if len(el_bootnode_enrs) > 0:
            return flag + ",".join(el_bootnode_enrs)
    elif (
        network not in constants.PUBLIC_NETWORKS
        and constants.NETWORK_NAME.shadowfork not in network
    ):
        return flag + shared_utils.get_devnet_el_enrs(
            plan, launcher.el_cl_genesis_data.files_artifact_uuid
        )
    return None


# Enode variant of get_bootnode_arg for discv4-only clients (ethereumjs).
def get_bootnode_enode_arg(
    plan, launcher, network, existing_el_clients, bootnodoor_enode, flag
):
    if bootnodoor_enode != None:
        return flag + bootnodoor_enode
    elif (
        network == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in network
    ):
        if len(existing_el_clients) > 0:
            return flag + ",".join(
                [
                    ctx.enode
                    for ctx in existing_el_clients[: constants.MAX_ENODE_ENTRIES]
                ]
            )
    elif (
        network not in constants.PUBLIC_NETWORKS
        and constants.NETWORK_NAME.shadowfork not in network
    ):
        return flag + shared_utils.get_devnet_enodes(
            plan, launcher.el_cl_genesis_data.files_artifact_uuid
        )
    return None


# Binary injection - mount custom binary directory if provided
def mount_el_binary_artifact(files, el_binary_artifact):
    if el_binary_artifact != None:
        files["/opt/bin"] = el_binary_artifact.artifact


# Binary injection - override entrypoint and cmd only when binary is provided.
# Copies the injected binary over dest_path, then runs binary_invocation with
# the original cmd args.
def apply_el_binary_override(
    config_args, el_binary_artifact, dest_path, binary_invocation, cmd
):
    if el_binary_artifact != None:
        config_args["entrypoint"] = ["sh", "-c"]
        config_args["cmd"] = [
            "cp /opt/bin/{0} {1} && {2} ".format(
                el_binary_artifact.filename, dest_path, binary_invocation
            )
            + " ".join(cmd)
        ]


# Applies the participant's EL resource limits/devices to config_args in place.
def apply_resource_limits(config_args, participant):
    if participant.el_min_cpu > 0:
        config_args["min_cpu"] = participant.el_min_cpu
    if participant.el_max_cpu > 0:
        config_args["max_cpu"] = participant.el_max_cpu
    if participant.el_min_mem > 0:
        config_args["min_memory"] = participant.el_min_mem
    if participant.el_max_mem > 0:
        config_args["max_memory"] = participant.el_max_mem
    if len(participant.el_devices) > 0:
        config_args["devices"] = participant.el_devices
