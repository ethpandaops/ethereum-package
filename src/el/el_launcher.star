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
ethrex = import_module("./ethrex/ethrex_launcher.star")


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
    extra_files_artifacts={},
):
    el_launchers = {
        constants.EL_TYPE.geth: {
            "launcher": geth.new_geth_launcher(
                el_cl_data,
                jwt_file,
                network_id,
            ),
            "launch_method": geth.launch,
            "get_config": geth.get_config,
            "get_el_context": geth.get_el_context,
        },
        constants.EL_TYPE.besu: {
            "launcher": besu.new_besu_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": besu.launch,
            "get_config": besu.get_config,
            "get_el_context": besu.get_el_context,
        },
        constants.EL_TYPE.erigon: {
            "launcher": erigon.new_erigon_launcher(
                el_cl_data,
                jwt_file,
                network_id,
            ),
            "launch_method": erigon.launch,
            "get_config": erigon.get_config,
            "get_el_context": erigon.get_el_context,
        },
        constants.EL_TYPE.nethermind: {
            "launcher": nethermind.new_nethermind_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": nethermind.launch,
            "get_config": nethermind.get_config,
            "get_el_context": nethermind.get_el_context,
        },
        constants.EL_TYPE.reth: {
            "launcher": reth.new_reth_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": reth.launch,
            "get_config": reth.get_config,
            "get_el_context": reth.get_el_context,
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
            "get_el_context": reth.get_el_context,
        },
        constants.EL_TYPE.ethereumjs: {
            "launcher": ethereumjs.new_ethereumjs_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": ethereumjs.launch,
            "get_config": ethereumjs.get_config,
            "get_el_context": ethereumjs.get_el_context,
        },
        constants.EL_TYPE.nimbus: {
            "launcher": nimbus_eth1.new_nimbus_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": nimbus_eth1.launch,
            "get_config": nimbus_eth1.get_config,
            "get_el_context": nimbus_eth1.get_el_context,
        },
        constants.EL_TYPE.ethrex: {
            "launcher": ethrex.new_ethrex_launcher(
                el_cl_data,
                jwt_file,
            ),
            "get_config": ethrex.get_config,
            "get_el_context": ethrex.get_el_context,
            "launch_method": ethrex.launch,
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
        tolerations = shared_utils.get_tolerations(
            specific_container_tolerations=participant.el_tolerations,
            participant_tolerations=participant.tolerations,
            global_tolerations=global_tolerations,
        )

        if el_type not in el_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    el_type, ",".join(el_launchers.keys())
                )
            )

        el_launcher, launch_method, get_config = (
            el_launchers[el_type]["launcher"],
            el_launchers[el_type]["launch_method"],
            el_launchers[el_type]["get_config"],
        )

        # Zero-pad the index using the calculated zfill value
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        el_service_name = "el-{0}-{1}-{2}".format(index_str, el_type, cl_type)

        if index == 0:
            el_context = launch_method(
                plan,
                el_launcher,
                el_service_name,
                participant,
                global_log_level,
                all_el_contexts,
                persistent,
                tolerations,
                node_selectors,
                port_publisher,
                index,
                network_params,
                extra_files_artifacts,
            )

            # Add participant el additional prometheus metrics
            for metrics_info in el_context.el_metrics_info:
                if metrics_info != None:
                    metrics_info["config"] = participant.prometheus_config

            all_el_contexts.append(el_context)
        else:
            el_service_configs[el_service_name] = get_config(
                plan,
                el_launcher,
                participant,
                el_service_name,
                all_el_contexts,
                cl_type,
                global_log_level,
                persistent,
                tolerations,
                node_selectors,
                port_publisher,
                index,
                network_params,
                extra_files_artifacts,
            )

            el_participant_info[el_service_name] = {
                "client_name": el_type,
                "supernode": participant.supernode,
                "participant_index": index,
                "participant": participant,
            }

    # add remainder of el's in parallel to speed package execution
    el_services = {}
    if len(el_service_configs) > 0:
        el_services = plan.add_services(el_service_configs)

    # Create contexts ordered by participant index
    el_contexts_temp = {}
    for el_service_name, el_service in el_services.items():
        el_type = el_participant_info[el_service_name]["client_name"]
        participant_index = el_participant_info[el_service_name]["participant_index"]
        participant = el_participant_info[el_service_name]["participant"]
        get_el_context = el_launchers[el_type]["get_el_context"]

        el_context = get_el_context(
            plan,
            el_service_name,
            el_service,
            el_launchers[el_type]["launcher"],
        )

        # Add participant el additional prometheus metrics
        for metrics_info in el_context.el_metrics_info:
            if metrics_info != None:
                metrics_info["config"] = participant.prometheus_config

        el_contexts_temp[participant_index] = el_context

    # Add remaining EL contexts in participant order (skipping index 0 which was added earlier)
    for i in range(1, len(participants)):
        if i in el_contexts_temp:
            all_el_contexts.append(el_contexts_temp[i])

    plan.print("Successfully added {0} EL participants".format(num_participants))
    return all_el_contexts
