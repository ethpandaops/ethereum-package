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

beacon_snooper = import_module("./snooper/snooper_beacon_launcher.star")


def launch_participant_network(
    plan,
    participants,
    network_params,
    global_log_level,
    jwt_file,
    keymanager_file,
    persistent,
    xatu_sentry_params,
    global_tolerations,
    global_node_selectors,
    keymanager_enabled,
    parallel_keystore_generation,
    port_publisher,
):
    network_id = network_params.network_id
    latest_block = ""
    num_participants = len(participants)
    cancun_time = 0
    prague_time = 0
    shadowfork_block = "latest"
    if (
        constants.NETWORK_NAME.shadowfork in network_params.network
        and ("verkle" in network_params.network)
        and ("holesky" in network_params.network)
    ):
        shadowfork_block = "793312"  # Hardcodes verkle shadowfork block for holesky

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
                shadowfork_block,
                participants,
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
            plan, network_params, participants, parallel_keystore_generation
        )

        el_cl_genesis_config_template = read_file(
            static_files.EL_CL_GENESIS_GENERATION_CONFIG_TEMPLATE_FILEPATH
        )

        el_cl_data = el_cl_genesis_data_generator.generate_el_cl_genesis_data(
            plan,
            ethereum_genesis_generator_image,
            el_cl_genesis_config_template,
            final_genesis_timestamp,
            network_id,
            network_params.deposit_contract_address,
            network_params.seconds_per_slot,
            network_params.preregistered_validator_keys_mnemonic,
            total_number_of_validator_keys,
            network_params.genesis_delay,
            network_params.max_per_epoch_activation_churn_limit,
            network_params.churn_limit_quotient,
            network_params.ejection_balance,
            network_params.eth1_follow_distance,
            network_params.deneb_fork_epoch,
            network_params.electra_fork_epoch,
            network_params.eip7594_fork_epoch,
            network_params.eip7594_fork_version,
            latest_block.files_artifacts[0] if latest_block != "" else "",
            network_params.min_validator_withdrawability_delay,
            network_params.shard_committee_period,
            network_params.data_column_sidecar_subnet_count,
            network_params.samples_per_slot,
            network_params.custody_requirement,
            network_params.target_number_of_peers,
            network_params.preset,
        )
    elif network_params.network in constants.PUBLIC_NETWORKS:
        # We are running a public network
        (
            el_cl_data,
            final_genesis_timestamp,
            network_id,
            validator_data,
        ) = launch_public_network.launch(
            plan, network_params.network, cancun_time, prague_time
        )
    elif network_params.network == constants.NETWORK_NAME.ephemery:
        # We are running an ephemery network
        (
            el_cl_data,
            final_genesis_timestamp,
            network_id,
            validator_data,
        ) = launch_ephemery.launch(plan, cancun_time, prague_time)
    else:
        # We are running a devnet
        (
            el_cl_data,
            final_genesis_timestamp,
            network_id,
            validator_data,
        ) = launch_devnet.launch(plan, network_params.network, cancun_time, prague_time)

    # Launch all execution layer clients
    all_el_contexts = el_client_launcher.launch(
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
    )

    # Launch all consensus layer clients
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

    (
        all_cl_contexts,
        all_snooper_engine_contexts,
        preregistered_validator_keys_for_nodes,
    ) = cl_client_launcher.launch(
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
        network_id,
        num_participants,
        validator_data,
        prysm_password_relative_filepath,
        prysm_password_artifact_uuid,
        port_publisher,
    )

    ethereum_metrics_exporter_context = None
    all_ethereum_metrics_exporter_contexts = []
    all_xatu_sentry_contexts = []
    all_vc_contexts = []
    all_snooper_beacon_contexts = []
    # Some CL clients cannot run validator clients in the same process and need
    # a separate validator client
    _cls_that_need_separate_vc = [
        constants.CL_TYPE.prysm,
        constants.CL_TYPE.lodestar,
        constants.CL_TYPE.lighthouse,
    ]

    for index, participant in enumerate(participants):
        el_type = participant.el_type
        cl_type = participant.cl_type
        vc_type = participant.vc_type
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))
        el_context = all_el_contexts[index]
        cl_context = all_cl_contexts[index]

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
            )
            plan.print(
                "Successfully added {0} ethereum metrics exporter participants".format(
                    ethereum_metrics_exporter_context
                )
            )

        all_ethereum_metrics_exporter_contexts.append(ethereum_metrics_exporter_context)

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
            all_snooper_beacon_contexts.append(None)
            continue

        if cl_type in _cls_that_need_separate_vc and not participant.use_separate_vc:
            fail("{0} needs a separate validator client!".format(cl_type))

        if not participant.use_separate_vc:
            all_vc_contexts.append(None)
            all_snooper_beacon_contexts.append(None)
            continue

        plan.print(
            "Using separate validator client for participant #{0}".format(index_str)
        )

        vc_keystores = None
        if participant.validator_count != 0:
            vc_keystores = preregistered_validator_keys_for_nodes[index]

        vc_context = None
        snooper_beacon_context = None

        if participant.snooper_enabled:
            snooper_service_name = "snooper-beacon-{0}-{1}-{2}".format(
                index_str, cl_type, vc_type
            )
            snooper_beacon_context = beacon_snooper.launch(
                plan,
                snooper_service_name,
                cl_context,
                node_selectors,
            )
            plan.print(
                "Successfully added {0} snooper participants".format(
                    snooper_beacon_context
                )
            )
        all_snooper_beacon_contexts.append(snooper_beacon_context)
        full_name = (
            "{0}-{1}-{2}".format(index_str, el_type, cl_type) + "-{0}".format(vc_type)
            if participant.cl_type != participant.vc_type
            else "{0}-{1}-{2}".format(index_str, el_type, cl_type)
        )

        vc_context = vc.launch(
            plan=plan,
            launcher=vc.new_vc_launcher(el_cl_genesis_data=el_cl_data),
            keymanager_file=keymanager_file,
            service_name="vc-{0}-{1}-{2}".format(index_str, vc_type, el_type),
            vc_type=vc_type,
            image=participant.vc_image,
            participant_log_level=participant.vc_log_level,
            global_log_level=global_log_level,
            cl_context=cl_context,
            el_context=el_context,
            full_name=full_name,
            snooper_enabled=participant.snooper_enabled,
            snooper_beacon_context=snooper_beacon_context,
            node_keystore_files=vc_keystores,
            vc_min_cpu=participant.vc_min_cpu,
            vc_max_cpu=participant.vc_max_cpu,
            vc_min_mem=participant.vc_min_mem,
            vc_max_mem=participant.vc_max_mem,
            extra_params=participant.vc_extra_params,
            extra_env_vars=participant.vc_extra_env_vars,
            extra_labels=participant.vc_extra_labels,
            prysm_password_relative_filepath=prysm_password_relative_filepath,
            prysm_password_artifact_uuid=prysm_password_artifact_uuid,
            vc_tolerations=participant.vc_tolerations,
            participant_tolerations=participant.tolerations,
            global_tolerations=global_tolerations,
            node_selectors=node_selectors,
            keymanager_enabled=participant.keymanager_enabled,
            preset=network_params.preset,
            network=network_params.network,
            electra_fork_epoch=network_params.electra_fork_epoch,
        )
        all_vc_contexts.append(vc_context)

        if vc_context and vc_context.metrics_info:
            vc_context.metrics_info["config"] = participant.prometheus_config

    all_participants = []

    for index, participant in enumerate(participants):
        el_type = participant.el_type
        cl_type = participant.cl_type
        vc_type = participant.vc_type
        snooper_engine_context = None
        snooper_beacon_context = None

        el_context = all_el_contexts[index]
        cl_context = all_cl_contexts[index]
        vc_context = all_vc_contexts[index]

        if participant.snooper_enabled:
            snooper_engine_context = all_snooper_engine_contexts[index]
            snooper_beacon_context = all_snooper_beacon_contexts[index]

        ethereum_metrics_exporter_context = None

        if participant.ethereum_metrics_exporter_enabled:
            ethereum_metrics_exporter_context = all_ethereum_metrics_exporter_contexts[
                index
            ]
        xatu_sentry_context = None

        if participant.xatu_sentry_enabled:
            xatu_sentry_context = all_xatu_sentry_contexts[index]

        participant_entry = participant_module.new_participant(
            el_type,
            cl_type,
            vc_type,
            el_context,
            cl_context,
            vc_context,
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
    )
