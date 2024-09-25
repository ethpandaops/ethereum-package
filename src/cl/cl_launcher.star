lighthouse = import_module("./lighthouse/lighthouse_launcher.star")
lodestar = import_module("./lodestar/lodestar_launcher.star")
nimbus = import_module("./nimbus/nimbus_launcher.star")
prysm = import_module("./prysm/prysm_launcher.star")
teku = import_module("./teku/teku_launcher.star")
grandine = import_module("./grandine/grandine_launcher.star")

constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

engine_snooper = import_module("../snooper/snooper_engine_launcher.star")

cl_context_BOOTNODE = None


def launch(
    plan,
    network_params,
    el_cl_data,
    jwt_file,
    keymanager_file,
    participants,
    all_el_contexts,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
    num_participants,
    validator_data,
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
    checkpoint_sync_enabled,
    checkpoint_sync_url,
    port_publisher,
):
    plan.print("Launching CL network")

    cl_launchers = {
        constants.CL_TYPE.lighthouse: {
            "launcher": lighthouse.new_lighthouse_launcher(
                el_cl_data, jwt_file, network_params
            ),
            "launch_method": lighthouse.launch,
        },
        constants.CL_TYPE.lodestar: {
            "launcher": lodestar.new_lodestar_launcher(
                el_cl_data, jwt_file, network_params
            ),
            "launch_method": lodestar.launch,
        },
        constants.CL_TYPE.nimbus: {
            "launcher": nimbus.new_nimbus_launcher(
                el_cl_data,
                jwt_file,
                network_params,
                keymanager_file,
            ),
            "launch_method": nimbus.launch,
        },
        constants.CL_TYPE.prysm: {
            "launcher": prysm.new_prysm_launcher(
                el_cl_data,
                jwt_file,
                network_params,
                prysm_password_relative_filepath,
                prysm_password_artifact_uuid,
            ),
            "launch_method": prysm.launch,
        },
        constants.CL_TYPE.teku: {
            "launcher": teku.new_teku_launcher(
                el_cl_data,
                jwt_file,
                network_params,
                keymanager_file,
            ),
            "launch_method": teku.launch,
        },
        constants.CL_TYPE.grandine: {
            "launcher": grandine.new_grandine_launcher(
                el_cl_data,
                jwt_file,
                network_params,
            ),
            "launch_method": grandine.launch,
        },
    }

    all_snooper_engine_contexts = []
    all_cl_contexts = []
    preregistered_validator_keys_for_nodes = (
        validator_data.per_node_keystores
        if network_params.network == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in network_params.network
        else None
    )
    network_name = shared_utils.get_network_name(network_params.network)
    for index, participant in enumerate(participants):
        cl_type = participant.cl_type
        el_type = participant.el_type
        node_selectors = input_parser.get_client_node_selectors(
            participant.node_selectors,
            global_node_selectors,
        )

        tolerations = input_parser.get_client_tolerations(
            participant.cl_tolerations, participant.tolerations, global_tolerations
        )

        (
            cl_min_cpu,
            cl_max_cpu,
            cl_min_mem,
            cl_max_mem,
            cl_volume_size,
        ) = shared_utils.get_cpu_mem_resource_limits(
            participant.cl_min_cpu,
            participant.cl_max_cpu,
            participant.cl_min_mem,
            participant.cl_max_mem,
            participant.cl_volume_size,
            network_name,
            participant.cl_type,
        )

        if cl_type not in cl_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    cl_type, ",".join(cl_launchers.keys())
                )
            )

        cl_launcher, launch_method = (
            cl_launchers[cl_type]["launcher"],
            cl_launchers[cl_type]["launch_method"],
        )

        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        cl_service_name = "cl-{0}-{1}-{2}".format(index_str, cl_type, el_type)
        new_cl_node_validator_keystores = None
        if participant.validator_count != 0 and participant.vc_count != 0:
            new_cl_node_validator_keystores = preregistered_validator_keys_for_nodes[
                index
            ]

        el_context = all_el_contexts[index]

        cl_context = None
        snooper_engine_context = None
        if participant.snooper_enabled:
            snooper_service_name = "snooper-engine-{0}-{1}-{2}".format(
                index_str, cl_type, el_type
            )
            snooper_engine_context = engine_snooper.launch(
                plan,
                snooper_service_name,
                el_context,
                node_selectors,
            )
            plan.print(
                "Successfully added {0} snooper participants".format(
                    snooper_engine_context
                )
            )
        all_snooper_engine_contexts.append(snooper_engine_context)
        full_name = "{0}-{1}-{2}".format(index_str, el_type, cl_type)
        if index == 0:
            cl_context = launch_method(
                plan,
                cl_launcher,
                cl_service_name,
                participant.cl_image,
                participant.cl_log_level,
                global_log_level,
                cl_context_BOOTNODE,
                el_context,
                full_name,
                new_cl_node_validator_keystores,
                cl_min_cpu,
                cl_max_cpu,
                cl_min_mem,
                cl_max_mem,
                participant.snooper_enabled,
                snooper_engine_context,
                participant.blobber_enabled,
                participant.blobber_extra_params,
                participant.cl_extra_params,
                participant.cl_extra_env_vars,
                participant.cl_extra_labels,
                persistent,
                cl_volume_size,
                tolerations,
                node_selectors,
                participant.use_separate_vc,
                participant.keymanager_enabled,
                checkpoint_sync_enabled,
                checkpoint_sync_url,
                port_publisher,
                index,
            )
        else:
            boot_cl_client_ctx = all_cl_contexts
            cl_context = launch_method(
                plan,
                cl_launcher,
                cl_service_name,
                participant.cl_image,
                participant.cl_log_level,
                global_log_level,
                boot_cl_client_ctx,
                el_context,
                full_name,
                new_cl_node_validator_keystores,
                cl_min_cpu,
                cl_max_cpu,
                cl_min_mem,
                cl_max_mem,
                participant.snooper_enabled,
                snooper_engine_context,
                participant.blobber_enabled,
                participant.blobber_extra_params,
                participant.cl_extra_params,
                participant.cl_extra_env_vars,
                participant.cl_extra_labels,
                persistent,
                cl_volume_size,
                tolerations,
                node_selectors,
                participant.use_separate_vc,
                participant.keymanager_enabled,
                checkpoint_sync_enabled,
                checkpoint_sync_url,
                port_publisher,
                index,
            )

        # Add participant cl additional prometheus labels
        for metrics_info in cl_context.cl_nodes_metrics_info:
            if metrics_info != None:
                metrics_info["config"] = participant.prometheus_config

        all_cl_contexts.append(cl_context)
    return (
        all_cl_contexts,
        all_snooper_engine_contexts,
        preregistered_validator_keys_for_nodes,
    )
