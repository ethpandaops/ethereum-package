validator_keystores = import_module(
    "./prelaunch_data_generator/validator_keystores/validator_keystore_generator.star"
)

el_cl_genesis_data_generator = import_module(
    "./prelaunch_data_generator/el_cl_genesis/el_cl_genesis_generator.star"
)
el_cl_genesis_data = import_module(
    "./prelaunch_data_generator/el_cl_genesis/el_cl_genesis_data.star"
)

input_parser = import_module("./package_io/input_parser.star")

shared_utils = import_module("./shared_utils/shared_utils.star")

static_files = import_module("./static_files/static_files.star")

geth = import_module("./el/geth/geth_launcher.star")
besu = import_module("./el/besu/besu_launcher.star")
erigon = import_module("./el/erigon/erigon_launcher.star")
nethermind = import_module("./el/nethermind/nethermind_launcher.star")
reth = import_module("./el/reth/reth_launcher.star")
ethereumjs = import_module("./el/ethereumjs/ethereumjs_launcher.star")
nimbus_eth1 = import_module("./el/nimbus-eth1/nimbus_launcher.star")

lighthouse = import_module("./cl/lighthouse/lighthouse_launcher.star")
lodestar = import_module("./cl/lodestar/lodestar_launcher.star")
nimbus = import_module("./cl/nimbus/nimbus_launcher.star")
prysm = import_module("./cl/prysm/prysm_launcher.star")
teku = import_module("./cl/teku/teku_launcher.star")

validator_client = import_module("./validator_client/validator_client_launcher.star")

snooper = import_module("./snooper/snooper_engine_launcher.star")

ethereum_metrics_exporter = import_module(
    "./ethereum_metrics_exporter/ethereum_metrics_exporter_launcher.star"
)

xatu_sentry = import_module("./xatu_sentry/xatu_sentry_launcher.star")

genesis_constants = import_module(
    "./prelaunch_data_generator/genesis_constants/genesis_constants.star"
)
participant_module = import_module("./participant.star")

constants = import_module("./package_io/constants.star")

BOOT_PARTICIPANT_INDEX = 0

# The time that the CL genesis generation step takes to complete, based off what we've seen
# This is in seconds
CL_GENESIS_DATA_GENERATION_TIME = 5

# Each CL node takes about this time to start up and start processing blocks, so when we create the CL
#  genesis data we need to set the genesis timestamp in the future so that nodes don't miss important slots
# (e.g. Altair fork)
# TODO(old) Make this client-specific (currently this is Nimbus)
# This is in seconds
CL_NODE_STARTUP_TIME = 5

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
    num_participants = len(participants)
    latest_block = ""
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
            base_network = shared_utils.get_network_name(network_params.network)
            # overload the network name to remove the shadowfork suffix
            if constants.NETWORK_NAME.ephemery in base_network:
                chain_id = plan.run_sh(
                    run="curl -s https://ephemery.dev/latest/config.yaml | yq .DEPOSIT_CHAIN_ID | tr -d '\n'",
                    image="linuxserver/yq",
                )
                network_id = chain_id.output
            else:
                network_id = constants.NETWORK_ID[
                    base_network
                ]  # overload the network id to match the network name
            latest_block = plan.run_sh(  # fetch the latest block
                run="mkdir -p /shadowfork && \
                    curl -o /shadowfork/latest_block.json https://ethpandaops-ethereum-node-snapshots.ams3.digitaloceanspaces.com/"
                + base_network
                + "/geth/"
                + shadowfork_block
                + "/_snapshot_eth_getBlockByNumber.json",
                image="badouralix/curl-jq",
                store=[StoreSpec(src="/shadowfork", name="latest_blocks")],
            )

            for index, participant in enumerate(participants):
                tolerations = input_parser.get_client_tolerations(
                    participant.el_tolerations,
                    participant.tolerations,
                    global_tolerations,
                )
                node_selectors = input_parser.get_client_node_selectors(
                    participant.node_selectors,
                    global_node_selectors,
                )

                cl_client_type = participant.cl_client_type
                el_client_type = participant.el_client_type

                # Zero-pad the index using the calculated zfill value
                index_str = shared_utils.zfill_custom(
                    index + 1, len(str(len(participants)))
                )

                el_service_name = "el-{0}-{1}-{2}".format(
                    index_str, el_client_type, cl_client_type
                )
                shadowfork_data = plan.add_service(
                    name="shadowfork-{0}".format(el_service_name),
                    config=ServiceConfig(
                        image="alpine:3.19.1",
                        cmd=[
                            "apk add --no-cache curl tar zstd && curl -s -L https://ethpandaops-ethereum-node-snapshots.ams3.digitaloceanspaces.com/"
                            + base_network
                            + "/"
                            + el_client_type
                            + "/"
                            + shadowfork_block
                            + "/snapshot.tar.zst"
                            + " | tar -I zstd -xvf - -C /data/"
                            + el_client_type
                            + "/execution-data"
                            + " && touch /tmp/finished"
                            + " && tail -f /dev/null"
                        ],
                        entrypoint=["/bin/sh", "-c"],
                        files={
                            "/data/"
                            + el_client_type
                            + "/execution-data": Directory(
                                persistent_key="data-{0}".format(el_service_name),
                                size=constants.VOLUME_SIZE[base_network][
                                    el_client_type + "_volume_size"
                                ],
                            ),
                        },
                        tolerations=tolerations,
                        node_selectors=node_selectors,
                    ),
                )
            for index, participant in enumerate(participants):
                cl_client_type = participant.cl_client_type
                el_client_type = participant.el_client_type

                # Zero-pad the index using the calculated zfill value
                index_str = shared_utils.zfill_custom(
                    index + 1, len(str(len(participants)))
                )

                el_service_name = "el-{0}-{1}-{2}".format(
                    index_str, el_client_type, cl_client_type
                )
                plan.wait(
                    service_name="shadowfork-{0}".format(el_service_name),
                    recipe=ExecRecipe(command=["cat", "/tmp/finished"]),
                    field="code",
                    assertion="==",
                    target_value=0,
                    interval="1s",
                    timeout="6h",  # 6 hours should be enough for the biggest network
                )

        # We are running a kurtosis or shadowfork network
        plan.print("Generating cl validator key stores")
        validator_data = None
        if not parallel_keystore_generation:
            validator_data = validator_keystores.generate_validator_keystores(
                plan, network_params.preregistered_validator_keys_mnemonic, participants
            )
        else:
            validator_data = (
                validator_keystores.generate_valdiator_keystores_in_parallel(
                    plan,
                    network_params.preregistered_validator_keys_mnemonic,
                    participants,
                )
            )

        plan.print(json.indent(json.encode(validator_data)))

        # We need to send the same genesis time to both the EL and the CL to ensure that timestamp based forking works as expected
        final_genesis_timestamp = get_final_genesis_timestamp(
            plan,
            network_params.genesis_delay
            + CL_GENESIS_DATA_GENERATION_TIME
            + num_participants * CL_NODE_STARTUP_TIME,
        )

        # if preregistered validator count is 0 (default) then calculate the total number of validators from the participants
        total_number_of_validator_keys = network_params.preregistered_validator_count

        if network_params.preregistered_validator_count == 0:
            for participant in participants:
                total_number_of_validator_keys += participant.validator_count

        plan.print("Generating EL CL data")

        # we are running bellatrix genesis (deprecated) - will be removed in the future
        if (
            network_params.capella_fork_epoch > 0
            and network_params.electra_fork_epoch == None
        ):
            ethereum_genesis_generator_image = (
                constants.ETHEREUM_GENESIS_GENERATOR.bellatrix_genesis
            )
        # we are running capella genesis - default behavior
        elif (
            network_params.capella_fork_epoch == 0
            and network_params.electra_fork_epoch == None
            and network_params.deneb_fork_epoch > 0
        ):
            ethereum_genesis_generator_image = (
                constants.ETHEREUM_GENESIS_GENERATOR.capella_genesis
            )
        # we are running deneb genesis -  experimental, soon to become default
        elif network_params.deneb_fork_epoch == 0:
            ethereum_genesis_generator_image = (
                constants.ETHEREUM_GENESIS_GENERATOR.deneb_genesis
            )
        # we are running electra - experimental
        elif network_params.electra_fork_epoch != None:
            if network_params.electra_fork_epoch == 0:
                ethereum_genesis_generator_image = (
                    constants.ETHEREUM_GENESIS_GENERATOR.verkle_genesis
                )
            else:
                ethereum_genesis_generator_image = (
                    constants.ETHEREUM_GENESIS_GENERATOR.verkle_support_genesis
                )
        else:
            fail(
                "Unsupported fork epoch configuration, need to define either capella_fork_epoch, deneb_fork_epoch or electra_fork_epoch"
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
        dummy = plan.run_sh(
            run="mkdir /network-configs",
            store=[StoreSpec(src="/network-configs/", name="el_cl_genesis_data")],
        )
        el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
            dummy.files_artifacts[0],
            constants.GENESIS_VALIDATORS_ROOT[network_params.network],
            cancun_time,
            prague_time,
        )
        final_genesis_timestamp = constants.GENESIS_TIME[network_params.network]
        network_id = constants.NETWORK_ID[network_params.network]
        validator_data = None
    elif network_params.network == constants.NETWORK_NAME.ephemery:
        el_cl_genesis_data_uuid = plan.run_sh(
            run="mkdir -p /network-configs/ && \
                curl -o latest.tar.gz https://ephemery.dev/latest.tar.gz && \
                tar xvzf latest.tar.gz -C /network-configs && \
                cat /network-configs/genesis_validators_root.txt",
            image="badouralix/curl-jq",
            store=[StoreSpec(src="/network-configs/", name="el_cl_genesis_data")],
        )
        genesis_validators_root = el_cl_genesis_data_uuid.output
        el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
            el_cl_genesis_data_uuid.files_artifacts[0],
            genesis_validators_root,
            cancun_time,
            prague_time,
        )
        final_genesis_timestamp = shared_utils.read_genesis_timestamp_from_config(
            plan, el_cl_genesis_data_uuid.files_artifacts[0]
        )
        network_id = shared_utils.read_genesis_network_id_from_config(
            plan, el_cl_genesis_data_uuid.files_artifacts[0]
        )
        validator_data = None
    else:
        # We are running a devnet
        url = calculate_devnet_url(network_params.network)
        el_cl_genesis_uuid = plan.upload_files(
            src=url,
            name="el_cl_genesis",
        )
        el_cl_genesis_data_uuid = plan.run_sh(
            run="mkdir -p /network-configs/ && mv /opt/* /network-configs/",
            store=[StoreSpec(src="/network-configs/", name="el_cl_genesis_data")],
            files={"/opt": el_cl_genesis_uuid},
        )
        genesis_validators_root = read_file(url + "/genesis_validators_root.txt")

        el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
            el_cl_genesis_data_uuid.files_artifacts[0],
            genesis_validators_root,
            cancun_time,
            prague_time,
        )
        final_genesis_timestamp = shared_utils.read_genesis_timestamp_from_config(
            plan, el_cl_genesis_data_uuid.files_artifacts[0]
        )
        network_id = shared_utils.read_genesis_network_id_from_config(
            plan, el_cl_genesis_data_uuid.files_artifacts[0]
        )
        validator_data = None

    el_launchers = {
        constants.EL_CLIENT_TYPE.geth: {
            "launcher": geth.new_geth_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
                network_id,
                network_params.capella_fork_epoch,
                el_cl_data.cancun_time,
                el_cl_data.prague_time,
                network_params.electra_fork_epoch,
            ),
            "launch_method": geth.launch,
        },
        constants.EL_CLIENT_TYPE.gethbuilder: {
            "launcher": geth.new_geth_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
                network_id,
                network_params.capella_fork_epoch,
                el_cl_data.cancun_time,
                el_cl_data.prague_time,
                network_params.electra_fork_epoch,
            ),
            "launch_method": geth.launch,
        },
        constants.EL_CLIENT_TYPE.besu: {
            "launcher": besu.new_besu_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": besu.launch,
        },
        constants.EL_CLIENT_TYPE.erigon: {
            "launcher": erigon.new_erigon_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
                network_id,
                el_cl_data.cancun_time,
            ),
            "launch_method": erigon.launch,
        },
        constants.EL_CLIENT_TYPE.nethermind: {
            "launcher": nethermind.new_nethermind_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": nethermind.launch,
        },
        constants.EL_CLIENT_TYPE.reth: {
            "launcher": reth.new_reth_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": reth.launch,
        },
        constants.EL_CLIENT_TYPE.ethereumjs: {
            "launcher": ethereumjs.new_ethereumjs_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": ethereumjs.launch,
        },
        constants.EL_CLIENT_TYPE.nimbus: {
            "launcher": nimbus_eth1.new_nimbus_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
            ),
            "launch_method": nimbus_eth1.launch,
        },
    }

    all_el_client_contexts = []

    for index, participant in enumerate(participants):
        cl_client_type = participant.cl_client_type
        el_client_type = participant.el_client_type
        node_selectors = input_parser.get_client_node_selectors(
            participant.node_selectors,
            global_node_selectors,
        )
        tolerations = input_parser.get_client_tolerations(
            participant.el_tolerations, participant.tolerations, global_tolerations
        )
        if el_client_type not in el_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    el_client_type, ",".join([el.name for el in el_launchers.keys()])
                )
            )

        el_launcher, launch_method = (
            el_launchers[el_client_type]["launcher"],
            el_launchers[el_client_type]["launch_method"],
        )

        # Zero-pad the index using the calculated zfill value
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        el_service_name = "el-{0}-{1}-{2}".format(
            index_str, el_client_type, cl_client_type
        )

        el_client_context = launch_method(
            plan,
            el_launcher,
            el_service_name,
            participant.el_client_image,
            participant.el_client_log_level,
            global_log_level,
            all_el_client_contexts,
            participant.el_min_cpu,
            participant.el_max_cpu,
            participant.el_min_mem,
            participant.el_max_mem,
            participant.el_extra_params,
            participant.el_extra_env_vars,
            participant.el_extra_labels,
            persistent,
            participant.el_client_volume_size,
            tolerations,
            node_selectors,
        )

        # Add participant el additional prometheus metrics
        for metrics_info in el_client_context.el_metrics_info:
            if metrics_info != None:
                metrics_info["config"] = participant.prometheus_config

        all_el_client_contexts.append(el_client_context)

    plan.print("Successfully added {0} EL participants".format(num_participants))

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
    all_ethereum_metrics_exporter_contexts = []
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

        ethereum_metrics_exporter_context = None

        if participant.ethereum_metrics_exporter_enabled:
            pair_name = "{0}-{1}-{2}".format(index_str, cl_client_type, el_client_type)

            ethereum_metrics_exporter_service_name = (
                "ethereum-metrics-exporter-{0}".format(pair_name)
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
            service_name="validator-client-{0}-{1}".format(
                index_str, validator_client_type
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


# this is a python procedure so that Kurtosis can do idempotent runs
# time.now() runs everytime bringing non determinism
# note that the timestamp it returns is a string
def get_final_genesis_timestamp(plan, padding):
    result = plan.run_python(
        run="""
import time
import sys
padding = int(sys.argv[1])
print(int(time.time()+padding), end="")
""",
        args=[str(padding)],
        store=[StoreSpec(src="/tmp", name="final-genesis-timestamp")],
    )
    return result.output


def calculate_devnet_url(network):
    sf_suffix_mapping = {"hsf": "-hsf-", "gsf": "-gsf-", "ssf": "-ssf-"}
    shadowfork = "sf-" in network

    if shadowfork:
        for suffix, delimiter in sf_suffix_mapping.items():
            if delimiter in network:
                network_parts = network.split(delimiter, 1)
                network_type = suffix
    else:
        network_parts = network.split("-devnet-", 1)
        network_type = "devnet"

    devnet_name, devnet_number = network_parts[0], network_parts[1]
    devnet_category = devnet_name.split("-")[0]
    devnet_subname = (
        devnet_name.split("-")[1] + "-" if len(devnet_name.split("-")) > 1 else ""
    )

    return "github.com/ethpandaops/{0}-devnets/network-configs/{1}{2}-{3}".format(
        devnet_category, devnet_subname, network_type, devnet_number
    )
