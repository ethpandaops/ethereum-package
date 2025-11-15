node_metrics = import_module("../node_metrics_info.star")
cl_context_l = import_module("./cl_context.star")
lighthouse = import_module("./lighthouse/lighthouse_launcher.star")
lodestar = import_module("./lodestar/lodestar_launcher.star")
nimbus = import_module("./nimbus/nimbus_launcher.star")
prysm = import_module("./prysm/prysm_launcher.star")
teku = import_module("./teku/teku_launcher.star")
grandine = import_module("./grandine/grandine_launcher.star")

constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

snooper_el_launcher = import_module("../snooper/snooper_el_launcher.star")

cl_context_BOOTNODE = None


def launch(
    plan,
    network_params,
    el_cl_data,
    jwt_file,
    keymanager_file,
    args_with_right_defaults,
    all_el_contexts,
    global_node_selectors,
    global_tolerations,
    persistent,
    tempo_otlp_grpc_url,
    num_participants,
    validator_data,
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
    global_other_index,
    extra_files_artifacts,
    backend,
):
    plan.print("Launching CL network")

    cl_launchers = {
        constants.CL_TYPE.lighthouse: {
            "launcher": lighthouse.new_lighthouse_launcher(el_cl_data, jwt_file),
            "launch_method": lighthouse.launch,
            "get_beacon_config": lighthouse.get_beacon_config,
            "get_cl_context": lighthouse.get_cl_context,
            "get_blobber_config": lighthouse.get_blobber_config,
        },
        constants.CL_TYPE.lodestar: {
            "launcher": lodestar.new_lodestar_launcher(el_cl_data, jwt_file),
            "launch_method": lodestar.launch,
            "get_beacon_config": lodestar.get_beacon_config,
            "get_cl_context": lodestar.get_cl_context,
            "get_blobber_config": lodestar.get_blobber_config,
        },
        constants.CL_TYPE.nimbus: {
            "launcher": nimbus.new_nimbus_launcher(
                el_cl_data,
                jwt_file,
                keymanager_file,
            ),
            "launch_method": nimbus.launch,
            "get_beacon_config": nimbus.get_beacon_config,
            "get_cl_context": nimbus.get_cl_context,
            "get_blobber_config": nimbus.get_blobber_config,
        },
        constants.CL_TYPE.prysm: {
            "launcher": prysm.new_prysm_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": prysm.launch,
            "get_beacon_config": prysm.get_beacon_config,
            "get_cl_context": prysm.get_cl_context,
            "get_blobber_config": prysm.get_blobber_config,
        },
        constants.CL_TYPE.teku: {
            "launcher": teku.new_teku_launcher(
                el_cl_data,
                jwt_file,
                keymanager_file,
            ),
            "launch_method": teku.launch,
            "get_beacon_config": teku.get_beacon_config,
            "get_cl_context": teku.get_cl_context,
            "get_blobber_config": teku.get_blobber_config,
        },
        constants.CL_TYPE.grandine: {
            "launcher": grandine.new_grandine_launcher(
                el_cl_data,
                jwt_file,
            ),
            "launch_method": grandine.launch,
            "get_beacon_config": grandine.get_beacon_config,
            "get_cl_context": grandine.get_cl_context,
            "get_blobber_config": grandine.get_blobber_config,
        },
    }

    all_snooper_el_engine_contexts = []
    all_cl_contexts = []
    blobber_configs_with_contexts = []
    preregistered_validator_keys_for_nodes = (
        validator_data.per_node_keystores
        if network_params.network == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in network_params.network
        else None
    )
    network_name = shared_utils.get_network_name(network_params.network)

    cl_service_configs = {}
    cl_participant_info = {}
    for index, participant in enumerate(args_with_right_defaults.participants):
        cl_type = participant.cl_type
        el_type = participant.el_type
        node_selectors = input_parser.get_client_node_selectors(
            participant.node_selectors,
            global_node_selectors,
        )

        tolerations = shared_utils.get_tolerations(
            specific_container_tolerations=participant.cl_tolerations,
            participant_tolerations=participant.tolerations,
            global_tolerations=global_tolerations,
        )

        if cl_type not in cl_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    cl_type, ",".join(cl_launchers.keys())
                )
            )

        (
            cl_launcher,
            launch_method,
            get_beacon_config,
            get_cl_context,
            get_blobber_config,
        ) = (
            cl_launchers[cl_type]["launcher"],
            cl_launchers[cl_type]["launch_method"],
            cl_launchers[cl_type]["get_beacon_config"],
            cl_launchers[cl_type]["get_cl_context"],
            cl_launchers[cl_type]["get_blobber_config"],
        )

        index_str = shared_utils.zfill_custom(
            index + 1, len(str(len(args_with_right_defaults.participants)))
        )

        cl_service_name = "cl-{0}-{1}-{2}".format(index_str, cl_type, el_type)
        new_cl_node_validator_keystores = None
        if participant.validator_count != 0:
            new_cl_node_validator_keystores = preregistered_validator_keys_for_nodes[
                index
            ]

        el_context = all_el_contexts[index]

        cl_context = None
        snooper_el_engine_context = None
        if participant.snooper_enabled:
            snooper_service_name = "snooper-engine-{0}-{1}-{2}".format(
                index_str, cl_type, el_type
            )
            snooper_el_engine_context = snooper_el_launcher.launch_snooper(
                plan,
                snooper_service_name,
                el_context,
                node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                global_other_index,
                args_with_right_defaults.docker_cache_params,
            )
            global_other_index += 1
            plan.print(
                "Successfully added {0} snooper participants".format(
                    snooper_el_engine_context
                )
            )
        checkpoint_sync_url = args_with_right_defaults.checkpoint_sync_url
        # Use participant-level checkpoint_sync_enabled if set, otherwise use global
        checkpoint_sync_enabled = args_with_right_defaults.checkpoint_sync_enabled
        if participant.checkpoint_sync_enabled != None:
            checkpoint_sync_enabled = participant.checkpoint_sync_enabled
        if checkpoint_sync_enabled:
            if args_with_right_defaults.checkpoint_sync_url == "":
                if (
                    network_params.network in constants.PUBLIC_NETWORKS
                    or network_params.network == constants.NETWORK_NAME.ephemery
                ):
                    checkpoint_sync_url = constants.CHECKPOINT_SYNC_URL[
                        network_params.network
                    ]
                elif "devnet" in network_params.network:
                    checkpoint_sync_url = (
                        "https://checkpoint-sync.{0}.ethpandaops.io/".format(
                            network_params.network
                        )
                    )
                else:
                    fail(
                        "Checkpoint sync URL is required if you enabled checkpoint_sync for custom networks. Please provide a valid URL."
                    )

        all_snooper_el_engine_contexts.append(snooper_el_engine_context)
        full_name = "{0}-{1}-{2}".format(index_str, el_type, cl_type)
        if index == 0:
            cl_context = launch_method(
                plan,
                cl_launcher,
                cl_service_name,
                participant,
                args_with_right_defaults.global_log_level,
                cl_context_BOOTNODE,
                el_context,
                full_name,
                new_cl_node_validator_keystores,
                snooper_el_engine_context,
                persistent,
                tolerations,
                node_selectors,
                checkpoint_sync_enabled,
                checkpoint_sync_url,
                args_with_right_defaults.port_publisher,
                index,
                network_params,
                extra_files_artifacts,
                backend,
                tempo_otlp_grpc_url,
            )

            blobber_config = get_blobber_config(
                plan,
                participant,
                cl_service_name,
                cl_context.beacon_http_url,
                new_cl_node_validator_keystores,
                node_selectors,
            )
            if blobber_config != None:
                blobber_configs_with_contexts.append(
                    struct(
                        cl_context=cl_context,
                        blobber_config=blobber_config,
                        participant=participant,
                    )
                )

            # Add participant cl additional prometheus labels
            for metrics_info in cl_context.cl_nodes_metrics_info:
                if metrics_info != None:
                    metrics_info["config"] = participant.prometheus_config

            all_cl_contexts.append(cl_context)
        else:
            boot_cl_client_ctx = all_cl_contexts

            cl_service_configs[cl_service_name] = get_beacon_config(
                plan,
                cl_launcher,
                cl_service_name,
                participant,
                args_with_right_defaults.global_log_level,
                boot_cl_client_ctx,
                el_context,
                full_name,
                new_cl_node_validator_keystores,
                snooper_el_engine_context,
                persistent,
                tolerations,
                node_selectors,
                checkpoint_sync_enabled,
                checkpoint_sync_url,
                args_with_right_defaults.port_publisher,
                index,
                network_params,
                extra_files_artifacts,
                backend,
                tempo_otlp_grpc_url,
            )

            cl_participant_info[cl_service_name] = {
                "snooper_el_engine_context": snooper_el_engine_context,
                "new_cl_node_validator_keystores": new_cl_node_validator_keystores,
                "participant": participant,
                "node_selectors": node_selectors,
                "get_cl_context": get_cl_context,
                "get_blobber_config": get_blobber_config,
                "participant_index": index,
            }

    # add rest of cl's in parallel to speed package execution
    cl_services = {}
    if len(cl_service_configs) > 0:
        cl_services = plan.add_services(cl_service_configs)

    # Create CL contexts ordered by participant index
    cl_contexts_temp = {}
    blobber_configs_temp = {}
    for beacon_service_name, beacon_service in cl_services.items():
        info = cl_participant_info[beacon_service_name]
        get_cl_context = info["get_cl_context"]
        get_blobber_config = info["get_blobber_config"]
        participant = info["participant"]
        participant_index = info["participant_index"]

        cl_context = get_cl_context(
            plan,
            beacon_service_name,
            beacon_service,
            participant,
            info["snooper_el_engine_context"],
            info["new_cl_node_validator_keystores"],
            info["node_selectors"],
        )

        blobber_config = get_blobber_config(
            plan,
            participant,
            beacon_service_name,
            cl_context.beacon_http_url,
            info["new_cl_node_validator_keystores"],
            info["node_selectors"],
        )
        if blobber_config != None:
            blobber_configs_temp[participant_index] = struct(
                cl_context=cl_context,
                blobber_config=blobber_config,
                participant=participant,
            )

        # Add participant cl additional prometheus labels
        for metrics_info in cl_context.cl_nodes_metrics_info:
            if metrics_info != None:
                metrics_info["config"] = participant.prometheus_config

        cl_contexts_temp[participant_index] = cl_context

    # Add remaining CL contexts in participant order (skipping index 0 which was added earlier)
    for i in range(1, len(args_with_right_defaults.participants)):
        if i in cl_contexts_temp:
            all_cl_contexts.append(cl_contexts_temp[i])
            if i in blobber_configs_temp:
                blobber_configs_with_contexts.append(blobber_configs_temp[i])

    return (
        all_cl_contexts,
        all_snooper_el_engine_contexts,
        preregistered_validator_keys_for_nodes,
        global_other_index,
        blobber_configs_with_contexts,
    )
