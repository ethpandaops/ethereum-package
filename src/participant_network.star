el_cl_genesis_data_generator = import_module(
    "./prelaunch_data_generator/el_cl_genesis/el_cl_genesis_generator.star"
)
el_cl_genesis_data = import_module(
    "./prelaunch_data_generator/el_cl_genesis/el_cl_genesis_data.star"
)

input_parser = import_module("./package_io/input_parser.star")
shared_utils = import_module("./shared_utils/shared_utils.star")
static_files = import_module("./static_files/static_files.star")
constants = import_module("./package_io/constants.star")

ethereum_metrics_exporter = import_module(
    "./ethereum_metrics_exporter/ethereum_metrics_exporter_launcher.star"
)

genesis_constants = import_module(
    "./prelaunch_data_generator/genesis_constants/genesis_constants.star"
)
participant_module = import_module("./participant.star")

xatu_sentry = import_module("./xatu_sentry/xatu_sentry_launcher.star")
launch_ephemery = import_module("./network_launcher/ephemery.star")
launch_public_network = import_module("./network_launcher/public_network.star")
launch_devnet = import_module("./network_launcher/devnet.star")
launch_kurtosis = import_module("./network_launcher/kurtosis.star")
launch_shadowfork = import_module("./network_launcher/shadowfork.star")

el_client_launcher = import_module("./el/el_client_launcher.star")
cl_client_launcher = import_module("./cl/cl_client_launcher.star")
validator_client = import_module("./validator_client/validator_client_launcher.star")
CL_CLIENT_CONTEXT_BOOTNODE = None


def launch_participant_network(
    plan,
    participants,
    network_params,
    global_log_level,
    jwt_file,
    persistent,
    xatu_sentry_params,
    global_tolerations,
    global_node_selectors,
    parallel_keystore_generation=False,
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
            network_params.max_churn,
            network_params.ejection_balance,
            network_params.eth1_follow_distance,
            network_params.capella_fork_epoch,
            network_params.deneb_fork_epoch,
            network_params.electra_fork_epoch,
            latest_block.files_artifacts[0] if latest_block != "" else "",
            network_params.min_validator_withdrawability_delay,
            network_params.shard_committee_period,
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
    all_el_client_contexts = el_client_launcher.launch(
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
    )

    # Launch all consensus layer clients

    all_cl_client_contexts = cl_client_launcher.launch(
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
    )

    ethereum_metrics_exporter_context = None
    all_ethereum_metrics_exporter_contexts = []
    if participant.ethereum_metrics_exporter_enabled:
        pair_name = "{0}-{1}-{2}".format(index_str, cl_client_type, el_client_type)

        ethereum_metrics_exporter_service_name = "ethereum-metrics-exporter-{0}".format(
            pair_name
        )

        ethereum_metrics_exporter_context = ethereum_metrics_exporter.launch(
            plan,
            pair_name,
            ethereum_metrics_exporter_service_name,
            el_client_context,
            cl_client_context,
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
        pair_name = "{0}-{1}-{2}".format(index_str, cl_client_type, el_client_type)

        xatu_sentry_service_name = "xatu-sentry-{0}".format(pair_name)

        xatu_sentry_context = xatu_sentry.launch(
            plan,
            xatu_sentry_service_name,
            cl_client_context,
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

    all_validator_client_contexts = []
    # Some CL clients cannot run validator clients in the same process and need
    # a separate validator client
    _cls_that_need_separate_vc = [
        constants.CL_CLIENT_TYPE.prysm,
        constants.CL_CLIENT_TYPE.lodestar,
        constants.CL_CLIENT_TYPE.lighthouse,
    ]
    for index, participant in enumerate(participants):
        cl_client_type = participant.cl_client_type
        validator_client_type = participant.validator_client_type

        if participant.use_separate_validator_client == None:
            # This should only be the case for the MEV participant,
            # the regular participants default to False/True
            all_validator_client_contexts.append(None)
            continue

        if (
            cl_client_type in _cls_that_need_separate_vc
            and not participant.use_separate_validator_client
        ):
            fail("{0} needs a separate validator client!".format(cl_client_type))

        if not participant.use_separate_validator_client:
            all_validator_client_contexts.append(None)
            continue

        el_client_context = all_el_client_contexts[index]
        cl_client_context = all_cl_client_contexts[index]

        # Zero-pad the index using the calculated zfill value
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        plan.print(
            "Using separate validator client for participant #{0}".format(index_str)
        )

        vc_keystores = None
        if participant.validator_count != 0:
            vc_keystores = preregistered_validator_keys_for_nodes[index]

        validator_client_context = validator_client.launch(
            plan=plan,
            launcher=validator_client.new_validator_client_launcher(
                el_cl_genesis_data=el_cl_data
            ),
            service_name="vc-{0}-{1}-{2}".format(
                index_str, validator_client_type, el_client_type
            ),
            validator_client_type=validator_client_type,
            image=participant.validator_client_image,
            participant_log_level=participant.validator_client_log_level,
            global_log_level=global_log_level,
            cl_client_context=cl_client_context,
            el_client_context=el_client_context,
            node_keystore_files=vc_keystores,
            v_min_cpu=participant.v_min_cpu,
            v_max_cpu=participant.v_max_cpu,
            v_min_mem=participant.v_min_mem,
            v_max_mem=participant.v_max_mem,
            extra_params=participant.validator_extra_params,
            extra_labels=participant.validator_extra_labels,
            prysm_password_relative_filepath=prysm_password_relative_filepath,
            prysm_password_artifact_uuid=prysm_password_artifact_uuid,
            validator_tolerations=participant.validator_tolerations,
            participant_tolerations=participant.tolerations,
            global_tolerations=global_tolerations,
            node_selectors=node_selectors,
        )
        all_validator_client_contexts.append(validator_client_context)

        if validator_client_context and validator_client_context.metrics_info:
            validator_client_context.metrics_info[
                "config"
            ] = participant.prometheus_config

    all_participants = []

    for index, participant in enumerate(participants):
        el_client_type = participant.el_client_type
        cl_client_type = participant.cl_client_type
        validator_client_type = participant.validator_client_type

        el_client_context = all_el_client_contexts[index]
        cl_client_context = all_cl_client_contexts[index]
        validator_client_context = all_validator_client_contexts[index]

        if participant.snooper_enabled:
            snooper_engine_context = all_snooper_engine_contexts[index]

        ethereum_metrics_exporter_context = None

        if participant.ethereum_metrics_exporter_enabled:
            ethereum_metrics_exporter_context = all_ethereum_metrics_exporter_contexts[
                index
            ]
        xatu_sentry_context = None

        if participant.xatu_sentry_enabled:
            xatu_sentry_context = all_xatu_sentry_contexts[index]

        participant_entry = participant_module.new_participant(
            el_client_type,
            cl_client_type,
            validator_client_type,
            el_client_context,
            cl_client_context,
            validator_client_context,
            snooper_engine_context,
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
