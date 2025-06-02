constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
el_context_l = import_module("./el_context.star")
el_admin_node_info = import_module("./el_admin_node_info.star")
node_metrics = import_module("../node_metrics_info.star")

geth = import_module("./geth/geth_launcher.star")
besu = import_module("./besu/besu_launcher.star")
erigon = import_module("./erigon/erigon_launcher.star")
nethermind = import_module("./nethermind/nethermind_launcher.star")
reth = import_module("./reth/reth_launcher.star")
ethereumjs = import_module("./ethereumjs/ethereumjs_launcher.star")
nimbus_eth1 = import_module("./nimbus-eth1/nimbus_launcher.star")

def launch(
    plan,
    network_params,
    el_cl_data,
    jwt_file,
    participants,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
    network_id,
    num_participants,
    port_publisher,
    mev_builder_type,
    mev_params,
):
    el_launchers = {
        constants.EL_TYPE.geth: {
            "launcher": geth.new_geth_launcher(
                el_cl_data,
                jwt_file,
                network_id,
                el_cl_data.prague_time,
            ),
            "launch_method": geth.launch,
            "get_config": geth.get_config,
            "metrics_path": geth.METRICS_PATH,
            "verbosity_levels": geth.VERBOSITY_LEVELS,
        },
        constants.EL_TYPE.besu: {
            "launcher": besu.new_besu_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": besu.launch,
            "get_config": besu.get_config,
            "metrics_path": besu.METRICS_PATH,
            "verbosity_levels": besu.VERBOSITY_LEVELS,
        },
        constants.EL_TYPE.erigon: {
            "launcher": erigon.new_erigon_launcher(
                el_cl_data,
                jwt_file,
                network_id,
                el_cl_data.prague_time,
            ),
            "launch_method": erigon.launch,
            "get_config": erigon.get_config,
            "metrics_path": erigon.METRICS_PATH,
            "verbosity_levels": erigon.VERBOSITY_LEVELS,
        },
        constants.EL_TYPE.nethermind: {
            "launcher": nethermind.new_nethermind_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": nethermind.launch,
            "get_config": nethermind.get_config,
            "metrics_path": nethermind.METRICS_PATH,
            "verbosity_levels": nethermind.VERBOSITY_LEVELS,
        },
        constants.EL_TYPE.reth: {
            "launcher": reth.new_reth_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": reth.launch,
            "get_config": reth.get_config,
            "metrics_path": reth.METRICS_PATH,
            "verbosity_levels": reth.VERBOSITY_LEVELS,
        },
        constants.EL_TYPE.reth_builder: {
            "launcher": reth.new_reth_launcher(
                el_cl_data,
                jwt_file,
                builder_type=mev_builder_type,
                mev_params=mev_params,
            ),
            "launch_method": reth.launch,
            "get_config": reth.get_config,
            "metrics_path": reth.METRICS_PATH,
            "verbosity_levels": reth.VERBOSITY_LEVELS,
        },
        constants.EL_TYPE.ethereumjs: {
            "launcher": ethereumjs.new_ethereumjs_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": ethereumjs.launch,
            "get_config": ethereumjs.get_config,
            "metrics_path": ethereumjs.METRICS_PATH,
            "verbosity_levels": ethereumjs.VERBOSITY_LEVELS,
        },
        constants.EL_TYPE.nimbus: {
            "launcher": nimbus_eth1.new_nimbus_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": nimbus_eth1.launch,
            "get_config": nimbus_eth1.get_config,
            "metrics_path": nimbus_eth1.METRICS_PATH,
            "verbosity_levels": nimbus_eth1.VERBOSITY_LEVELS,
        },
    }

    all_el_contexts = []
    network_name = shared_utils.get_network_name(network_params.network)
    el_service_configs = {}
    el_participant_info = {}

    for index, participant in enumerate(participants):
        cl_type = participant.cl_type
        el_type = participant.el_type
        node_selectors = input_parser.get_client_node_selectors(
            participant.node_selectors,
            global_node_selectors,
        )
        tolerations = input_parser.get_client_tolerations(
            participant.el_tolerations, participant.tolerations, global_tolerations
        )

        if el_type not in el_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    el_type, ",".join(el_launchers.keys())
                )
            )

        el_launcher, launch_method, get_config, metrics_path, verbosity_levels = (
            el_launchers[el_type]["launcher"],
            el_launchers[el_type]["launch_method"],
            el_launchers[el_type]["get_config"],
            el_launchers[el_type]["metrics_path"],
            el_launchers[el_type]["verbosity_levels"],
        )

        # Zero-pad the index using the calculated zfill value
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        el_service_name = "el-{0}-{1}-{2}".format(index_str, el_type, cl_type)

        el_service_configs[el_service_name] = get_config(
            plan,
            el_launcher,
            participant,
            el_service_name,
            all_el_contexts,
            cl_type,
            input_parser.get_client_log_level_or_default(
                participant.el_log_level, global_log_level, verbosity_levels
            ),
            persistent,
            tolerations,
            node_selectors,
            port_publisher,
            index,
            network_params,
        )

        el_participant_info[el_service_name] = {
            "client_name": el_type,
            "supernode": participant.supernode,
            "metrics_path": metrics_path,
        }

    # Start all EL services in parallel
    el_services = {}
    if len(el_service_configs) > 0:
        el_services = plan.add_services(el_service_configs)

    # Create contexts for each service
    for el_service_name, el_service in el_services.items():
        if el_participant_info[el_service_name]["client_name"] == constants.EL_TYPE.erigon:
            enode, enr = el_admin_node_info.get_enode_enr_for_node(
                plan, el_service_name, constants.WS_RPC_PORT_ID
            )
        else:
            enode, enr = el_admin_node_info.get_enode_enr_for_node(
                plan, el_service_name, constants.RPC_PORT_ID
            )

        metrics_port = el_service.ports[constants.METRICS_PORT_ID]
        metrics_url = "{0}:{1}".format(el_service.ip_address, metrics_port.number)
        el_metrics_info = node_metrics.new_node_metrics_info(
            el_service_name, el_participant_info[el_service_name]["metrics_path"], metrics_url
        )

        if constants.RPC_PORT_ID in el_service.ports:
            rpc_port = el_service.ports[constants.RPC_PORT_ID]
        else:
            rpc_port = None

        if constants.WS_PORT_ID in el_service.ports:
            ws_port = el_service.ports[constants.WS_PORT_ID]
        else:
            ws_port = None

        if constants.ENGINE_RPC_PORT_ID in el_service.ports:
            engine_rpc_port = el_service.ports[constants.ENGINE_RPC_PORT_ID]
        else:
            engine_rpc_port = None

        http_url = "http://{0}:{1}".format(el_service.ip_address, rpc_port.number) if rpc_port else None
        ws_url = "ws://{0}:{1}".format(el_service.ip_address, ws_port.number) if ws_port else None

        el_context = el_context_l.new_el_context(
            client_name=el_participant_info[el_service_name]["client_name"],
            enode=enode,
            ip_addr=el_service.ip_address,
            rpc_port_num=rpc_port.number if rpc_port else None,
            ws_port_num=ws_port.number if ws_port else None,
            engine_rpc_port_num=engine_rpc_port.number if engine_rpc_port else None,
            rpc_http_url=http_url,
            ws_url=ws_url,
            enr=enr,
            service_name=el_service_name,
            el_metrics_info=[el_metrics_info],
        )

        # Add participant el additional prometheus metrics
        for metrics_info in el_context.el_metrics_info:
            if metrics_info != None:
                metrics_info["config"] = participant.prometheus_config

        all_el_contexts.append(el_context)

    plan.print("Successfully added {0} EL participants".format(num_participants))
    return all_el_contexts
