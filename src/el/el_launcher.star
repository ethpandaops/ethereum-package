constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

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
):
    el_launchers = {
        constants.EL_TYPE.geth: {
            "launcher": geth.new_geth_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
                network_id,
                el_cl_data.prague_time,
            ),
            "launch_method": geth.launch,
        },
        constants.EL_TYPE.besu: {
            "launcher": besu.new_besu_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": besu.launch,
        },
        constants.EL_TYPE.erigon: {
            "launcher": erigon.new_erigon_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
                network_id,
                el_cl_data.prague_time,
            ),
            "launch_method": erigon.launch,
        },
        constants.EL_TYPE.nethermind: {
            "launcher": nethermind.new_nethermind_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": nethermind.launch,
        },
        constants.EL_TYPE.reth: {
            "launcher": reth.new_reth_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": reth.launch,
        },
        constants.EL_TYPE.reth_builder: {
            "launcher": reth.new_reth_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
                builder=True,
            ),
            "launch_method": reth.launch,
        },
        constants.EL_TYPE.ethereumjs: {
            "launcher": ethereumjs.new_ethereumjs_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": ethereumjs.launch,
        },
        constants.EL_TYPE.nimbus: {
            "launcher": nimbus_eth1.new_nimbus_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": nimbus_eth1.launch,
        },
    }

    all_el_contexts = []
    network_name = shared_utils.get_network_name(network_params.network)
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

        (
            el_min_cpu,
            el_max_cpu,
            el_min_mem,
            el_max_mem,
            el_volume_size,
        ) = shared_utils.get_cpu_mem_resource_limits(
            participant.el_min_cpu,
            participant.el_max_cpu,
            participant.el_min_mem,
            participant.el_max_mem,
            participant.el_volume_size,
            network_name,
            participant.el_type,
        )

        if el_type not in el_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    el_type, ",".join(el_launchers.keys())
                )
            )

        el_launcher, launch_method = (
            el_launchers[el_type]["launcher"],
            el_launchers[el_type]["launch_method"],
        )

        # Zero-pad the index using the calculated zfill value
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        el_service_name = "el-{0}-{1}-{2}".format(index_str, el_type, cl_type)

        el_context = launch_method(
            plan,
            el_launcher,
            el_service_name,
            participant.el_image,
            participant.el_log_level,
            global_log_level,
            all_el_contexts,
            el_min_cpu,
            el_max_cpu,
            el_min_mem,
            el_max_mem,
            participant.el_extra_params,
            participant.el_extra_env_vars,
            participant.el_extra_labels,
            persistent,
            el_volume_size,
            tolerations,
            node_selectors,
            port_publisher,
            index,
        )
        # Add participant el additional prometheus metrics
        for metrics_info in el_context.el_metrics_info:
            if metrics_info != None:
                metrics_info["config"] = participant.prometheus_config

        all_el_contexts.append(el_context)

    plan.print("Successfully added {0} EL participants".format(num_participants))
    return all_el_contexts
