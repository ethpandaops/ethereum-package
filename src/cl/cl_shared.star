shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")


def get_general_cl_public_port_specs(public_ports_for_component):
    public_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: public_ports_for_component[0],
        constants.UDP_DISCOVERY_PORT_ID: public_ports_for_component[0],
        constants.HTTP_PORT_ID: public_ports_for_component[1],
        constants.METRICS_PORT_ID: public_ports_for_component[2],
    }
    public_ports = shared_utils.get_port_specs(public_port_assignments)
    return public_ports


# If snooper is enabled use the snooper engine context, otherwise use the
# execution client context. Returns None when there is no execution client.
def get_execution_engine_endpoint(participant, el_context, snooper_el_engine_context):
    if el_context == None:
        return None
    if participant.snooper_enabled:
        return "http://{0}:{1}".format(
            snooper_el_engine_context.ip_addr,
            snooper_el_engine_context.engine_rpc_port_num,
        )
    return "http://{0}:{1}".format(
        el_context.dns_name,
        el_context.engine_rpc_port_num,
    )


# Returns the Directory for the beacon node's persistent data volume.
# volume_size_key is the client key used to look up the default volume size in
# constants.VOLUME_SIZE. Note: caplin and consensoor intentionally pass the
# lighthouse key, as they have no entry of their own in constants.VOLUME_SIZE.
def get_beacon_data_directory(
    beacon_service_name, participant, network_params, volume_size_key
):
    network_volume_key = (
        "devnets" if "devnet" in network_params.network else network_params.network
    )
    return Directory(
        persistent_key="data-{0}".format(beacon_service_name),
        size=int(participant.cl_volume_size)
        if int(participant.cl_volume_size) > 0
        else constants.VOLUME_SIZE[network_volume_key][
            volume_size_key + "_volume_size"
        ],
    )


# Applies the participant's CL resource limits to the service config args.
def apply_resource_limits(config_args, participant):
    if int(participant.cl_min_cpu) > 0:
        config_args["min_cpu"] = int(participant.cl_min_cpu)
    if int(participant.cl_max_cpu) > 0:
        config_args["max_cpu"] = int(participant.cl_max_cpu)
    if int(participant.cl_min_mem) > 0:
        config_args["min_memory"] = int(participant.cl_min_mem)
    if int(participant.cl_max_mem) > 0:
        config_args["max_memory"] = int(participant.cl_max_mem)


def get_beacon_node_identity_recipe(multiaddr_index=0, headers=None):
    extract = {
        "enr": ".data.enr",
        "multiaddr": ".data.p2p_addresses[{0}]".format(multiaddr_index),
        "peer_id": ".data.peer_id",
    }
    if headers != None:
        return GetHttpRequestRecipe(
            endpoint="/eth/v1/node/identity",
            port_id=constants.HTTP_PORT_ID,
            extract=extract,
            headers=headers,
        )
    return GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=constants.HTTP_PORT_ID,
        extract=extract,
    )


# Queries the beacon node's identity endpoint and returns
# (enr, multiaddr, peer_id).
# Skips the HTTP request and returns empty strings if skip_start is enabled
# (the service won't be running) or if skip is set (the identity will be
# collected later via wait_beacon_node_identity).
def get_beacon_node_identity(
    plan, service_name, participant, multiaddr_index=0, headers=None, skip=False
):
    if participant.skip_start or skip:
        return "", "", ""

    response = plan.request(
        recipe=get_beacon_node_identity_recipe(multiaddr_index, headers),
        service_name=service_name,
    )
    return (
        response["extract.enr"],
        response["extract.multiaddr"],
        response["extract.peer_id"],
    )


# Waits for the beacon node's identity endpoint to become available and returns
# (enr, multiaddr, peer_id). Used to backfill identities of nodes launched with
# skip_identity=True, whose health checks were deferred.
def wait_beacon_node_identity(plan, service_name, client_name):
    multiaddr_index = -1 if client_name == "lodestar" else 0
    headers = {"Accept-Encoding": "identity"} if client_name == "prysm" else None

    response = plan.wait(
        recipe=get_beacon_node_identity_recipe(multiaddr_index, headers),
        service_name=service_name,
        field="code",
        assertion="IN",
        target_value=[200],
        interval="1s",
        timeout="5m",
    )
    return (
        response["extract.enr"],
        response["extract.multiaddr"],
        response["extract.peer_id"],
    )


# Resolves the bootnode argument (override, comma-joined ENRs of the bootnode
# contexts for kurtosis/shadowfork networks, or the devnet ENR list for
# ephemery/devnets) and appends it to cmd with the given flag when set.
def append_bootnode_arg(
    plan, cmd, flag, launcher, network_params, bootnode_contexts, bootnode_enr_override
):
    bootnode_arg = bootnode_enr_override

    if network_params.network not in constants.PUBLIC_NETWORKS:
        if (
            network_params.network == constants.NETWORK_NAME.kurtosis
            or constants.NETWORK_NAME.shadowfork in network_params.network
        ):
            if bootnode_arg == None and bootnode_contexts != None:
                bootnode_arg = ",".join(
                    [ctx.enr for ctx in bootnode_contexts[: constants.MAX_ENR_ENTRIES]]
                )
        elif bootnode_arg == None:  # Ephemery and devnets
            bootnode_arg = shared_utils.get_devnet_enrs_list(
                plan, launcher.el_cl_genesis_data.files_artifact_uuid
            )

    # Add bootnode argument if set
    if bootnode_arg != None:
        cmd.append(flag + bootnode_arg)


def get_blobber_config(
    plan,
    participant,
    beacon_service_name,
    beacon_http_url,
    node_keystore_files,
    node_selectors,
):
    blobber_config = None
    if participant.blobber_enabled:
        blobber_config = struct(
            service_name="{0}-{1}".format("blobber", beacon_service_name),
            beacon_http_url=beacon_http_url,
            node_keystore_files=node_keystore_files,
            node_selectors=node_selectors,
        )
    return blobber_config


# Shared stub for clients that don't support blobbers.
def get_blobber_config_none(
    plan,
    participant,
    beacon_service_name,
    beacon_http_url,
    node_keystore_files,
    node_selectors,
):
    return None
