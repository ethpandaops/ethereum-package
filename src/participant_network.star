el_cl_genesis_data_generator = import_module(
    "./prelaunch_data_generator/el_cl_genesis/el_cl_genesis_generator.star"
)

input_parser = import_module("./package_io/input_parser.star")
shared_utils = import_module("./shared_utils/shared_utils.star")
static_files = import_module("./static_files/static_files.star")
constants = import_module("./package_io/constants.star")

ethereum_metrics_exporter = import_module(
    "./ethereum_metrics_exporter/ethereum_metrics_exporter_launcher.star"
)

participant_module = import_module("./participant.star")

xatu_sentry = import_module("./xatu_sentry/xatu_sentry_launcher.star")
launch_ephemery = import_module("./network_launcher/ephemery.star")
launch_public_network = import_module("./network_launcher/public_network.star")
launch_devnet = import_module("./network_launcher/devnet.star")
launch_kurtosis = import_module("./network_launcher/kurtosis.star")
launch_shadowfork = import_module("./network_launcher/shadowfork.star")

el_client_launcher = import_module("./el/el_launcher.star")
cl_client_launcher = import_module("./cl/cl_launcher.star")
vc = import_module("./vc/vc_launcher.star")
remote_signer = import_module("./remote_signer/remote_signer_launcher.star")

beacon_snooper = import_module("./snooper/snooper_beacon_launcher.star")


def launch_participant_network(
    plan,
    args_with_right_defaults,
    network_params,
    jwt_file,
    keymanager_file,
    persistent,
    xatu_sentry_params,
    global_tolerations,
    global_node_selectors,
    keymanager_enabled,
    parallel_keystore_generation,
):
    network_id = network_params.network_id
    num_participants = len(args_with_right_defaults.participants)
    total_number_of_validator_keys = 0
    latest_block = ""
    global_other_index = 0
    if (
        network_params.network == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in network_params.network
    ):
        if (
            constants.NETWORK_NAME.shadowfork in network_params.network
        ):  # shadowfork requires some preparation
            latest_block, network_id = launch_shadowfork.shadowfork_prep(
                plan,
                network_params,
                args_with_right_defaults.participants,
                global_tolerations,
                global_node_selectors,
            )

        # We are running a kurtosis or shadowfork network
        (
            total_number_of_validator_keys,
            ethereum_genesis_generator_image,
            final_genesis_timestamp,
            validator_data,
        ) = launch_kurtosis.launch(
            plan, network_params, args_with_right_defaults, parallel_keystore_generation
        )

        el_cl_genesis_config_template = read_file(
            static_files.EL_CL_GENESIS_GENERATION_CONFIG_TEMPLATE_FILEPATH
        )

        el_cl_genesis_additional_contracts_template = read_file(
            static_files.EL_CL_GENESIS_ADDITIONAL_CONTRACTS_TEMPLATE_FILEPATH
        )

        el_cl_data = el_cl_genesis_data_generator.generate_el_cl_genesis_data(
            plan,
            ethereum_genesis_generator_image,
            el_cl_genesis_config_template,
            el_cl_genesis_additional_contracts_template,
            final_genesis_timestamp,
            network_params,
            total_number_of_validator_keys,
            latest_block.files_artifacts[0] if latest_block != "" else "",
        )
    elif network_params.network == constants.NETWORK_NAME.ephemery:
        # We are running an ephemery network
        (
            el_cl_data,
            final_genesis_timestamp,
            network_id,
            validator_data,
        ) = launch_ephemery.launch(plan)
    elif (
        network_params.network in constants.PUBLIC_NETWORKS
        and network_params.network != constants.NETWORK_NAME.ephemery
    ):
        # We are running a public network
        (
            el_cl_data,
            final_genesis_timestamp,
            network_id,
            validator_data,
        ) = launch_public_network.launch(
            plan,
            args_with_right_defaults.participants,
            network_params,
            global_tolerations,
            global_node_selectors,
        )
    else:
        # We are running a devnet
        (
            el_cl_data,
            final_genesis_timestamp,
            network_id,
            validator_data,
        ) = launch_devnet.launch(
            plan,
            network_params.network,
            network_params.devnet_repo,
        )

    # Launch all execution layer clients
    all_el_contexts = el_client_launcher.launch(
        plan,
        network_params,
        el_cl_data,
        jwt_file,
        args_with_right_defaults.participants,
        args_with_right_defaults.global_log_level,
        global_node_selectors,
        global_tolerations,
        persistent,
        network_id,
        num_participants,
        args_with_right_defaults.port_publisher,
        args_with_right_defaults.mev_type,
        args_with_right_defaults.mev_params,
    )

    # Launch all consensus layer clients
    prysm_password_relative_filepath = (
        validator_data.prysm_password_relative_filepath
        if total_number_of_validator_keys > 0
        else None
    )
    prysm_password_artifact_uuid = (
        validator_data.prysm_password_artifact_uuid
        if total_number_of_validator_keys > 0
        else None
    )

    (
        all_cl_contexts,
        all_snooper_engine_contexts,
        preregistered_validator_keys_for_nodes,
        global_other_index,
    ) = cl_client_launcher.launch(
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
        num_participants,
        validator_data,
        prysm_password_relative_filepath,
        prysm_password_artifact_uuid,
        global_other_index,
    )

    ethereum_metrics_exporter_context = None
    all_ethereum_metrics_exporter_contexts = []
    all_xatu_sentry_contexts = []
    all_vc_contexts = []
    all_remote_signer_contexts = []
    all_snooper_beacon_contexts = []
    # Some CL clients cannot run validator clients in the same process and need
    # a separate validator client
    _cls_that_need_separate_vc = [
        constants.CL_TYPE.prysm,
        constants.CL_TYPE.lodestar,
        constants.CL_TYPE.lighthouse,
    ]

    current_vc_index = 0
    if not args_with_right_defaults.participants:
        fail("No participants configured")

    for index, participant in enumerate(args_with_right_defaults.participants):
        el_type = participant.el_type
        cl_type = participant.cl_type
        vc_type = participant.vc_type
        remote_signer_type = participant.remote_signer_type
        index_str = shared_utils.zfill_custom(
            index + 1, len(str(len(args_with_right_defaults.participants)))
        )
        el_context = all_el_contexts[index] if index < len(all_el_contexts) else None
        cl_context = all_cl_contexts[index] if index < len(all_cl_contexts) else None

        node_selectors = input_parser.get_client_node_selectors(
            participant.node_selectors,
            global_node_selectors,
        )
        if participant.ethereum_metrics_exporter_enabled:
            pair_name = "{0}-{1}-{2}".format(index_str, cl_type, el_type)

            ethereum_metrics_exporter_service_name = (
                "ethereum-metrics-exporter-{0}".format(pair_name)
            )

            ethereum_metrics_exporter_context = ethereum_metrics_exporter.launch(
                plan,
                pair_name,
                ethereum_metrics_exporter_service_name,
                el_context,
                cl_context,
                node_selectors,
                args_with_right_defaults.port_publisher,
                global_other_index,
                args_with_right_defaults.docker_cache_params,
            )
            global_other_index += 1
            plan.print(
                "Successfully added {0} ethereum metrics exporter participants".format(
                    ethereum_metrics_exporter_context
                )
            )

            all_ethereum_metrics_exporter_contexts.append(
                ethereum_metrics_exporter_context
            )

            xatu_sentry_context = None

        if participant.xatu_sentry_enabled:
            pair_name = "{0}-{1}-{2}".format(index_str, cl_type, el_type)

            xatu_sentry_service_name = "xatu-sentry-{0}".format(pair_name)

            xatu_sentry_context = xatu_sentry.launch(
                plan,
                xatu_sentry_service_name,
                cl_context,
                xatu_sentry_params,
                network_params,
                pair_name,
                node_selectors,
            )
            plan.print(
                "Successfully added {0} xatu sentry participants".format(
                    xatu_sentry_context
                )
            )

            all_xatu_sentry_contexts.append(xatu_sentry_context)

        plan.print("Successfully added {0} CL participants".format(num_participants))

        plan.print("Start adding validators for participant #{0}".format(index_str))
        if participant.use_separate_vc == None:
            # This should only be the case for the MEV participant,
            # the regular participants default to False/True
            all_vc_contexts.append(None)
            all_remote_signer_contexts.append(None)
            all_snooper_beacon_contexts.append(None)
            continue

        if cl_type in _cls_that_need_separate_vc and not participant.use_separate_vc:
            fail("{0} needs a separate validator client!".format(cl_type))

        if not participant.use_separate_vc:
            all_vc_contexts.append(None)
            all_remote_signer_contexts.append(None)
            all_snooper_beacon_contexts.append(None)
            continue

        plan.print(
            "Using separate validator client for participant #{0}".format(index_str)
        )

        vc_keystores = None
        if participant.validator_count != 0:
            vc_keystores = preregistered_validator_keys_for_nodes[index]

        vc_context = None
        remote_signer_context = None
        snooper_beacon_context = None

        if participant.snooper_enabled:
            snooper_service_name = "snooper-beacon-{0}-{1}-{2}".format(
                index_str,
                cl_type,
                vc_type,
            )
            snooper_beacon_context = beacon_snooper.launch(
                plan,
                snooper_service_name,
                cl_context,
                node_selectors,
                args_with_right_defaults.port_publisher,
                global_other_index,
                args_with_right_defaults.docker_cache_params,
            )
            global_other_index += 1
            plan.print(
                "Successfully added {0} snooper participants".format(
                    snooper_beacon_context
                )
            )
        all_snooper_beacon_contexts.append(snooper_beacon_context)
        full_name = (
            "{0}-{1}-{2}-{3}".format(
                index_str,
                el_type,
                cl_type,
                vc_type,
            )
            if participant.cl_type != participant.vc_type
            else "{0}-{1}-{2}".format(
                index_str,
                el_type,
                cl_type,
            )
        )

        if participant.use_remote_signer:
            remote_signer_context = remote_signer.launch(
                plan=plan,
                launcher=remote_signer.new_remote_signer_launcher(
                    el_cl_genesis_data=el_cl_data
                ),
                service_name="signer-{0}".format(full_name),
                remote_signer_type=remote_signer_type,
                image=participant.remote_signer_image,
                full_name="{0}-remote_signer".format(full_name),
                vc_type=vc_type,
                node_keystore_files=vc_keystores,
                participant=participant,
                global_tolerations=global_tolerations,
                node_selectors=node_selectors,
                port_publisher=args_with_right_defaults.port_publisher,
                remote_signer_index=current_vc_index,
            )

        all_remote_signer_contexts.append(remote_signer_context)
        if remote_signer_context and remote_signer_context.metrics_info:
            remote_signer_context.metrics_info["config"] = participant.prometheus_config

        vc_context = vc.launch(
            plan=plan,
            launcher=vc.new_vc_launcher(el_cl_genesis_data=el_cl_data),
            keymanager_file=keymanager_file,
            service_name="vc-{0}".format(full_name),
            vc_type=vc_type,
            image=participant.vc_image,
            global_log_level=args_with_right_defaults.global_log_level,
            cl_context=cl_context,
            el_context=el_context,
            remote_signer_context=remote_signer_context,
            full_name=full_name,
            snooper_enabled=participant.snooper_enabled,
            snooper_beacon_context=snooper_beacon_context,
            node_keystore_files=vc_keystores,
            participant=participant,
            prysm_password_relative_filepath=prysm_password_relative_filepath,
            prysm_password_artifact_uuid=prysm_password_artifact_uuid,
            global_tolerations=global_tolerations,
            node_selectors=node_selectors,
            network_params=network_params,
            port_publisher=args_with_right_defaults.port_publisher,
            vc_index=current_vc_index,
        )
        all_vc_contexts.append(vc_context)

        if vc_context and vc_context.metrics_info:
            vc_context.metrics_info["config"] = participant.prometheus_config
        current_vc_index += 1

    all_participants = []

    for index, participant in enumerate(args_with_right_defaults.participants):
        el_type = participant.el_type
        cl_type = participant.cl_type
        vc_type = participant.vc_type
        remote_signer_type = participant.remote_signer_type
        snooper_engine_context = None
        snooper_beacon_context = None

        el_context = all_el_contexts[index] if index < len(all_el_contexts) else None
        cl_context = all_cl_contexts[index] if index < len(all_cl_contexts) else None
        vc_context = all_vc_contexts[index] if index < len(all_vc_contexts) else None

        remote_signer_context = (
            all_remote_signer_contexts[index]
            if index < len(all_remote_signer_contexts)
            else None
        )

        if participant.snooper_enabled:
            snooper_engine_context = all_snooper_engine_contexts[index]
            snooper_beacon_context = all_snooper_beacon_contexts[index]

        ethereum_metrics_exporter_context = None

        if participant.ethereum_metrics_exporter_enabled:
            ethereum_metrics_exporter_context = all_ethereum_metrics_exporter_contexts[
                index
            ]
        xatu_sentry_context = None

        if participant.xatu_sentry_enabled and index < len(all_xatu_sentry_contexts):
            xatu_sentry_context = all_xatu_sentry_contexts[index]

        participant_entry = participant_module.new_participant(
            el_type,
            cl_type,
            vc_type,
            remote_signer_type,
            el_context,
            cl_context,
            vc_context,
            remote_signer_context,
            snooper_engine_context,
            snooper_beacon_context,
            ethereum_metrics_exporter_context,
            xatu_sentry_context,
        )

        all_participants.append(participant_entry)

    return (
        all_participants,
        final_genesis_timestamp,
        el_cl_data.genesis_validators_root,
        el_cl_data.files_artifact_uuid,
        network_id,
        el_cl_data.osaka_time,
    )
