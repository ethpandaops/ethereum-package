geth = import_module("../el/geth/geth_launcher.star")
besu = import_module("../el/besu/besu_launcher.star")
erigon = import_module("../el/erigon/erigon_launcher.star")
nethermind = import_module("../el/nethermind/nethermind_launcher.star")
reth = import_module("../el/reth/reth_launcher.star")
nimbus_eth1 = import_module("../el/nimbus-eth1/nimbus_launcher.star")
ethrex = import_module("../el/ethrex/ethrex_launcher.star")
input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

SERVICE_NAME = "bootnode"

# Fixed identity for the devp2p bootnode (deterministic ENR across runs; devnet-only).
DEVP2P_NODEKEY = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
DEVP2P_DISCOVERY_PORT = 30303


# Launch a pure discv5 bootnode using go-ethereum's `devp2p discv5 listen` (no chain,
# RLPx, RPC or txpool — just discv5). Needs an alltools image (e.g.
# ethereum/client-go:alltools-latest) set as bootnode_params.image. It has no RPC to
# query, so its ENR/enode are COMPUTED in-container with `devp2p key to-enr/to-enode`
# from the fixed nodekey + the container's own IP. Returns (enode, enr).
def _launch_devp2p_bootnode(plan, bootnode_params, node_selectors, tolerations):
    config = ServiceConfig(
        image=bootnode_params.image,
        ports={
            constants.UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
                DEVP2P_DISCOVERY_PORT,
                shared_utils.UDP_PROTOCOL,
            ),
        },
        entrypoint=["devp2p"],
        cmd=[
            "discv5",
            "listen",
            "--nodekey",
            DEVP2P_NODEKEY,
            # Explicit empty bootnodes: suppress devp2p's DEFAULT (public mainnet)
            # bootnodes, so the table isn't polluted with public nodes.
            "--bootnodes",
            "",
            "--addr",
            "0.0.0.0:{0}".format(DEVP2P_DISCOVERY_PORT),
            "--extaddr",
            "{0}:{1}".format(
                constants.PRIVATE_IP_ADDRESS_PLACEHOLDER, DEVP2P_DISCOVERY_PORT
            ),
        ],
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )
    plan.add_service(SERVICE_NAME, config)

    enr = _devp2p_record(plan, "to-enr")
    enode = _devp2p_record(plan, "to-enode")
    plan.print("Bootnode (devp2p) ENR: {0}".format(enr))
    return enode, enr


def _devp2p_record(plan, subcmd):
    # Compute the running node's enode/ENR from the same nodekey + its own IP.
    result = plan.exec(
        service_name=SERVICE_NAME,
        recipe=ExecRecipe(
            command=[
                "sh",
                "-c",
                "echo -n {key} > /tmp/nk && devp2p key {sub} --ip $(hostname -i | cut -d' ' -f1) --udp {port} --tcp 0 /tmp/nk | tr -d '\\n'".format(
                    key=DEVP2P_NODEKEY, sub=subcmd, port=DEVP2P_DISCOVERY_PORT
                ),
            ],
        ),
    )
    return result["output"]


# Launch a standalone EL node whose ONLY job is to be the network's discv5 bootnode.
# It has no CL (nothing drives it past genesis) and no validators. With a discovery-only
# flag set (e.g. geth --maxpeers=0) it holds zero RLPx peers and is a pure rendezvous:
# it still bonds via discv5 and serves FINDNODE. Because discv5 is application-agnostic,
# this one node seeds BOTH overlays — its enode/ENR feed the EL clients and its ENR the
# CL clients via the same override plumbing bootnodoor uses. Returns (enode, enr).
#
# The bootnode backend is selectable via bootnode_params.backend (default geth). Note the
# discovery-only / disable-discv4 flags in extra_params are backend-specific.
def launch_bootnode(
    plan,
    bootnode_params,
    el_cl_genesis_data,
    jwt_file,
    network_id,
    network_params,
    global_log_level,
    persistent,
    port_publisher,
    global_node_selectors,
    global_tolerations,
):
    node_selectors = input_parser.get_client_node_selectors(
        {}, global_node_selectors
    )
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Pure discv5 bootnode via go-ethereum's devp2p tool (no chain/RLPx/RPC).
    if bootnode_params.backend == "devp2p":
        return _launch_devp2p_bootnode(
            plan, bootnode_params, node_selectors, tolerations
        )

    el_bootnode_launchers = {
        constants.EL_TYPE.geth: {
            "launcher": geth.new_geth_launcher(el_cl_genesis_data, jwt_file, network_id),
            "get_config": geth.get_config,
            "get_el_context": geth.get_el_context,
        },
        constants.EL_TYPE.nethermind: {
            "launcher": nethermind.new_nethermind_launcher(el_cl_genesis_data, jwt_file),
            "get_config": nethermind.get_config,
            "get_el_context": nethermind.get_el_context,
        },
        constants.EL_TYPE.reth: {
            "launcher": reth.new_reth_launcher(el_cl_genesis_data, jwt_file),
            "get_config": reth.get_config,
            "get_el_context": reth.get_el_context,
        },
        constants.EL_TYPE.erigon: {
            "launcher": erigon.new_erigon_launcher(
                el_cl_genesis_data, jwt_file, network_id
            ),
            "get_config": erigon.get_config,
            "get_el_context": erigon.get_el_context,
        },
        constants.EL_TYPE.ethrex: {
            "launcher": ethrex.new_ethrex_launcher(el_cl_genesis_data, jwt_file),
            "get_config": ethrex.get_config,
            "get_el_context": ethrex.get_el_context,
        },
        constants.EL_TYPE.besu: {
            "launcher": besu.new_besu_launcher(el_cl_genesis_data, jwt_file),
            "get_config": besu.get_config,
            "get_el_context": besu.get_el_context,
        },
        constants.EL_TYPE.nimbus: {
            "launcher": nimbus_eth1.new_nimbus_launcher(el_cl_genesis_data, jwt_file),
            "get_config": nimbus_eth1.get_config,
            "get_el_context": nimbus_eth1.get_el_context,
        },
    }

    backend = bootnode_params.backend
    if backend not in el_bootnode_launchers:
        fail(
            "Unsupported bootnode backend '{0}', need one of '{1}'".format(
                backend, ",".join(el_bootnode_launchers.keys())
            )
        )
    entry = el_bootnode_launchers[backend]

    # Synthetic single-EL-node config (reuses the client's tested launcher).
    p = input_parser.default_participant()
    p["el_type"] = backend
    p["el_image"] = bootnode_params.image
    p["el_extra_params"] = bootnode_params.extra_params
    p["validator_count"] = 0
    participant = struct(**p)

    node_selectors = input_parser.get_client_node_selectors(
        participant.node_selectors, global_node_selectors
    )
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    config = entry["get_config"](
        plan,
        entry["launcher"],
        participant,
        SERVICE_NAME,
        [],  # existing_el_clients: none -> this node is the bootstrap anchor
        "none",  # cl_client_name (label only)
        global_log_level,
        persistent,
        tolerations,
        node_selectors,
        port_publisher,
        0,  # participant_index (label/port slot; bootnode is not a participant)
        network_params,
        {},  # extra_files_artifacts
    )
    service = plan.add_service(SERVICE_NAME, config)

    el_context = entry["get_el_context"](plan, SERVICE_NAME, service, entry["launcher"])
    plan.print("Bootnode ({0}) ENODE: {1}".format(backend, el_context.enode))
    plan.print("Bootnode ({0}) ENR: {1}".format(backend, el_context.enr))
    return el_context.enode, el_context.enr
