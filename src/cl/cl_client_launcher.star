lighthouse = import_module("./lighthouse/lighthouse_launcher.star")
lodestar = import_module("./lodestar/lodestar_launcher.star")
nimbus = import_module("./nimbus/nimbus_launcher.star")
prysm = import_module("./prysm/prysm_launcher.star")
teku = import_module("./teku/teku_launcher.star")


snooper = import_module("../snooper/snooper_engine_launcher.star")


def launch(
    plan,
    network_params,
    el_cl_data,
    jwt_file,
    participants,
    node_selectors,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
    network_id,
    num_participants,
    validator_data,
):
    plan.print("Launching CL network")
    prysm_password_relative_filepath = (
        validator_data.prysm_password_relative_filepath
        if network_params.network == constants.NETWORK_NAME.kurtosis
        else None
    )
    prysm_password_artifact_uuid = (
        validator_data.prysm_password_artifact_uuid
        if network_params.network == constants.NETWORK_NAME.kurtosis
        else None
    )
    cl_launchers = {
        constants.CL_CLIENT_TYPE.lighthouse: {
            "launcher": lighthouse.new_lighthouse_launcher(
                el_cl_data, jwt_file, network_params.network
            ),
            "launch_method": lighthouse.launch,
        },
        constants.CL_CLIENT_TYPE.lodestar: {
            "launcher": lodestar.new_lodestar_launcher(
                el_cl_data, jwt_file, network_params.network
            ),
            "launch_method": lodestar.launch,
        },
        constants.CL_CLIENT_TYPE.nimbus: {
            "launcher": nimbus.new_nimbus_launcher(
                el_cl_data, jwt_file, network_params.network
            ),
            "launch_method": nimbus.launch,
        },
        constants.CL_CLIENT_TYPE.prysm: {
            "launcher": prysm.new_prysm_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
                prysm_password_relative_filepath,
                prysm_password_artifact_uuid,
            ),
            "launch_method": prysm.launch,
        },
        constants.CL_CLIENT_TYPE.teku: {
            "launcher": teku.new_teku_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": teku.launch,
        },
    }

    all_snooper_engine_contexts = []
    all_cl_client_contexts = []
    all_xatu_sentry_contexts = []
    preregistered_validator_keys_for_nodes = (
        validator_data.per_node_keystores
        if network_params.network == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in network_params.network
        else None
    )

    for index, participant in enumerate(participants):
        cl_client_type = participant.cl_client_type
        el_client_type = participant.el_client_type
        node_selectors = input_parser.get_client_node_selectors(
            participant.node_selectors,
            global_node_selectors,
        )

        if cl_client_type not in cl_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    cl_client_type, ",".join([cl.name for cl in cl_launchers.keys()])
                )
            )

        cl_launcher, launch_method = (
            cl_launchers[cl_client_type]["launcher"],
            cl_launchers[cl_client_type]["launch_method"],
        )

        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        cl_service_name = "cl-{0}-{1}-{2}".format(
            index_str, cl_client_type, el_client_type
        )
        new_cl_node_validator_keystores = None
        if participant.validator_count != 0:
            new_cl_node_validator_keystores = preregistered_validator_keys_for_nodes[
                index
            ]

        el_client_context = all_el_client_contexts[index]

        cl_client_context = None
        snooper_engine_context = None
        if participant.snooper_enabled:
            snooper_service_name = "snooper-{0}-{1}-{2}".format(
                index_str, cl_client_type, el_client_type
            )
            snooper_engine_context = snooper.launch(
                plan,
                snooper_service_name,
                el_client_context,
                node_selectors,
            )
            plan.print(
                "Successfully added {0} snooper participants".format(
                    snooper_engine_context
                )
            )
        all_snooper_engine_contexts.append(snooper_engine_context)

        if index == 0:
            cl_client_context = launch_method(
                plan,
                cl_launcher,
                cl_service_name,
                participant.cl_client_image,
                participant.cl_client_log_level,
                global_log_level,
                CL_CLIENT_CONTEXT_BOOTNODE,
                el_client_context,
                new_cl_node_validator_keystores,
                participant.bn_min_cpu,
                participant.bn_max_cpu,
                participant.bn_min_mem,
                participant.bn_max_mem,
                participant.snooper_enabled,
                snooper_engine_context,
                participant.blobber_enabled,
                participant.blobber_extra_params,
                participant.beacon_extra_params,
                participant.beacon_extra_labels,
                persistent,
                participant.cl_client_volume_size,
                participant.cl_tolerations,
                participant.tolerations,
                global_tolerations,
                node_selectors,
                participant.use_separate_validator_client,
            )
        else:
            boot_cl_client_ctx = all_cl_client_contexts
            cl_client_context = launch_method(
                plan,
                cl_launcher,
                cl_service_name,
                participant.cl_client_image,
                participant.cl_client_log_level,
                global_log_level,
                boot_cl_client_ctx,
                el_client_context,
                new_cl_node_validator_keystores,
                participant.bn_min_cpu,
                participant.bn_max_cpu,
                participant.bn_min_mem,
                participant.bn_max_mem,
                participant.snooper_enabled,
                snooper_engine_context,
                participant.blobber_enabled,
                participant.blobber_extra_params,
                participant.beacon_extra_params,
                participant.beacon_extra_labels,
                persistent,
                participant.cl_client_volume_size,
                participant.cl_tolerations,
                participant.tolerations,
                global_tolerations,
                node_selectors,
                participant.use_separate_validator_client,
            )

        # Add participant cl additional prometheus labels
        for metrics_info in cl_client_context.cl_nodes_metrics_info:
            if metrics_info != None:
                metrics_info["config"] = participant.prometheus_config

        all_cl_client_contexts.append(cl_client_context)
    return all_cl_client_contexts
