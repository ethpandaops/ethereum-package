constants = import_module("./constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
genesis_constants = import_module(
    "../prelaunch_data_generator/genesis_constants/genesis_constants.star"
)

sanity_check = import_module("./sanity_check.star")

DEFAULT_EL_IMAGES = {
    "geth": "ethereum/client-go:latest",
    "erigon": "erigontech/erigon:latest",
    "nethermind": "nethermind/nethermind:latest",
    "besu": "hyperledger/besu:latest",
    "reth": "ghcr.io/paradigmxyz/reth",
    "ethereumjs": "ethpandaops/ethereumjs:master",
    "nimbus": "statusim/nimbus-eth1:master",
    "ethrex": "ghcr.io/lambdaclass/ethrex:latest",
    "dummy": "ethpandaops/dummy-el:master",
}

DEFAULT_CL_IMAGES = {
    "lighthouse": "sigp/lighthouse:latest",
    "teku": "consensys/teku:latest",
    "nimbus": "statusim/nimbus-eth2:multiarch-latest",
    "prysm": "offchainlabs/prysm-beacon-chain:stable",
    "lodestar": "chainsafe/lodestar:latest",
    "grandine": "sifrai/grandine:stable",
    "consensoor": "ethpandaops/consensoor:main",
}

DEFAULT_CL_IMAGES_MINIMAL = {
    "lighthouse": "ethpandaops/lighthouse:unstable",
    "teku": "ethpandaops/teku:master",
    "nimbus": "ethpandaops/nimbus-eth2:unstable-minimal",
    "prysm": "ethpandaops/prysm-beacon-chain:develop-minimal",
    "lodestar": "ethpandaops/lodestar:unstable",
    "grandine": "ethpandaops/grandine:develop-minimal",
    "consensoor": "ethpandaops/consensoor:main",
}

DEFAULT_VC_IMAGES = {
    "lighthouse": "sigp/lighthouse:latest",
    "lodestar": "chainsafe/lodestar:latest",
    "nimbus": "statusim/nimbus-validator-client:multiarch-latest",
    "prysm": "offchainlabs/prysm-validator:stable",
    "teku": "consensys/teku:latest",
    "grandine": "sifrai/grandine:stable",
    "vero": "ghcr.io/serenita-org/vero:latest",
    "consensoor": "ethpandaops/consensoor:main",
}

DEFAULT_VC_IMAGES_MINIMAL = {
    "lighthouse": "ethpandaops/lighthouse:unstable",
    "lodestar": "ethpandaops/lodestar:unstable",
    "nimbus": "ethpandaops/nimbus-validator-client:unstable-minimal",
    "prysm": "ethpandaops/prysm-validator:develop-minimal",
    "teku": "ethpandaops/teku:master",
    "grandine": "ethpandaops/grandine:develop-minimal",
    "vero": "ghcr.io/serenita-org/vero:latest",
    "consensoor": "ethpandaops/consensoor:main",
}

DEFAULT_REMOTE_SIGNER_IMAGES = {
    "web3signer": "consensys/web3signer:latest",
}

# MEV Params
MEV_BOOST_PORT = 18550

DEFAULT_ADDITIONAL_SERVICES = []

ATTR_TO_BE_SKIPPED_AT_ROOT = (
    "network_params",
    "participants",
    "mev_params",
    "blockscout_params",
    "dora_params",
    "checkpointz_params",
    "docker_cache_params",
    "assertoor_params",
    "prometheus_params",
    "grafana_params",
    "tempo_params",
    "tx_fuzz_params",
    "rakoon_params",
    "custom_flood_params",
    "xatu_sentry_params",
    "port_publisher",
    "spamoor_params",
    "slashoor_params",
    "bootnodoor_params",
    "mempool_bridge_params",
    "ews_params",
    "buildoor_params",
    "ethereum_genesis_generator_params",
)


def input_parser(plan, input_args):
    sanity_check.sanity_check(plan, input_args)
    result = parse_network_params(plan, input_args)
    # add default eth2 input params
    result["blockscout_params"] = get_default_blockscout_params()
    result["dora_params"] = get_default_dora_params()
    result["checkpointz_params"] = get_default_checkpointz_params()
    result["docker_cache_params"] = get_default_docker_cache_params()
    result["mev_params"] = get_default_mev_params(
        result.get("mev_type"), result["network_params"]["preset"]
    )
    if (
        result["network_params"]["network"] == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in result["network_params"]["network"]
    ):
        result["additional_services"] = DEFAULT_ADDITIONAL_SERVICES
    else:
        result["additional_services"] = []
    result["tx_fuzz_params"] = get_default_tx_fuzz_params()
    result["rakoon_params"] = get_default_rakoon_params()
    result["custom_flood_params"] = get_default_custom_flood_params()
    result["disable_peer_scoring"] = False
    result["grafana_params"] = get_default_grafana_params()
    result["assertoor_params"] = get_default_assertoor_params()
    result["prometheus_params"] = get_default_prometheus_params()
    result["tempo_params"] = get_default_tempo_params()
    result["xatu_sentry_params"] = get_default_xatu_sentry_params()
    result["persistent"] = False
    result["parallel_keystore_generation"] = False
    result["global_tolerations"] = []
    result["global_node_selectors"] = {}
    result["port_publisher"] = get_port_publisher_params("default")
    result["spamoor_params"] = get_default_spamoor_params()
    result["slashoor_params"] = get_default_slashoor_params()
    result["mempool_bridge_params"] = get_default_mempool_bridge_params()
    result["ews_params"] = get_default_ews_params()
    result["buildoor_params"] = get_default_buildoor_params()

    if constants.NETWORK_NAME.shadowfork in result["network_params"]["network"]:
        shadow_base = result["network_params"]["network"].split("-shadowfork")[0]
        result["network_params"][
            "deposit_contract_address"
        ] = constants.DEPOSIT_CONTRACT_ADDRESS[shadow_base]

    if constants.NETWORK_NAME.shadowfork in result["network_params"]["network"]:
        shadow_base = result["network_params"]["network"].split("-shadowfork")[0]
        result["network_params"][
            "deposit_contract_address"
        ] = constants.DEPOSIT_CONTRACT_ADDRESS[shadow_base]

    for attr in input_args:
        value = input_args[attr]
        # if its inserted we use the value inserted
        if attr not in ATTR_TO_BE_SKIPPED_AT_ROOT and attr in input_args:
            result[attr] = value
        # custom eth2 attributes config
        elif attr == "blockscout_params":
            for sub_attr in input_args["blockscout_params"]:
                sub_value = input_args["blockscout_params"][sub_attr]
                result["blockscout_params"][sub_attr] = sub_value
        elif attr == "dora_params":
            for sub_attr in input_args["dora_params"]:
                sub_value = input_args["dora_params"][sub_attr]
                result["dora_params"][sub_attr] = sub_value
        elif attr == "docker_cache_params":
            for sub_attr in input_args["docker_cache_params"]:
                sub_value = input_args["docker_cache_params"][sub_attr]
                result["docker_cache_params"][sub_attr] = sub_value
        elif attr == "mev_params":
            for sub_attr in input_args["mev_params"]:
                sub_value = input_args["mev_params"][sub_attr]
                result["mev_params"][sub_attr] = sub_value
        elif attr == "tx_fuzz_params":
            for sub_attr in input_args["tx_fuzz_params"]:
                sub_value = input_args["tx_fuzz_params"][sub_attr]
                result["tx_fuzz_params"][sub_attr] = sub_value
        elif attr == "rakoon_params":
            for sub_attr in input_args["rakoon_params"]:
                sub_value = input_args["rakoon_params"][sub_attr]
                result["rakoon_params"][sub_attr] = sub_value
        elif attr == "custom_flood_params":
            for sub_attr in input_args["custom_flood_params"]:
                sub_value = input_args["custom_flood_params"][sub_attr]
                result["custom_flood_params"][sub_attr] = sub_value
        elif attr == "assertoor_params":
            for sub_attr in input_args["assertoor_params"]:
                sub_value = input_args["assertoor_params"][sub_attr]
                result["assertoor_params"][sub_attr] = sub_value
        elif attr == "prometheus_params":
            for sub_attr in input_args["prometheus_params"]:
                sub_value = input_args["prometheus_params"][sub_attr]
                result["prometheus_params"][sub_attr] = sub_value
        elif attr == "grafana_params":
            for sub_attr in input_args["grafana_params"]:
                sub_value = input_args["grafana_params"][sub_attr]
                result["grafana_params"][sub_attr] = sub_value
        elif attr == "tempo_params":
            for sub_attr in input_args["tempo_params"]:
                sub_value = input_args["tempo_params"][sub_attr]
                result["tempo_params"][sub_attr] = sub_value
        elif attr == "xatu_sentry_params":
            for sub_attr in input_args["xatu_sentry_params"]:
                sub_value = input_args["xatu_sentry_params"][sub_attr]
                result["xatu_sentry_params"][sub_attr] = sub_value
        elif attr == "port_publisher":
            result["port_publisher"] = get_port_publisher_params("user", input_args)
        elif attr == "spamoor_params":
            for sub_attr in input_args["spamoor_params"]:
                sub_value = input_args["spamoor_params"][sub_attr]
                result["spamoor_params"][sub_attr] = sub_value
        elif attr == "slashoor_params":
            for sub_attr in input_args["slashoor_params"]:
                sub_value = input_args["slashoor_params"][sub_attr]
                result["slashoor_params"][sub_attr] = sub_value
        elif attr == "mempool_bridge_params":
            for sub_attr in input_args["mempool_bridge_params"]:
                sub_value = input_args["mempool_bridge_params"][sub_attr]
                result["mempool_bridge_params"][sub_attr] = sub_value
        elif attr == "bootnodoor_params":
            for sub_attr in input_args["bootnodoor_params"]:
                sub_value = input_args["bootnodoor_params"][sub_attr]
                result["bootnodoor_params"][sub_attr] = sub_value
        elif attr == "ethereum_genesis_generator_params":
            for sub_attr in input_args["ethereum_genesis_generator_params"]:
                sub_value = input_args["ethereum_genesis_generator_params"][sub_attr]
                result["ethereum_genesis_generator_params"][sub_attr] = sub_value
        elif attr == "checkpointz_params":
            for sub_attr in input_args["checkpointz_params"]:
                sub_value = input_args["checkpointz_params"][sub_attr]
                result["checkpointz_params"][sub_attr] = sub_value
        elif attr == "ews_params":
            for sub_attr in input_args["ews_params"]:
                sub_value = input_args["ews_params"][sub_attr]
                result["ews_params"][sub_attr] = sub_value
        elif attr == "buildoor_params":
            for sub_attr in input_args["buildoor_params"]:
                sub_value = input_args["buildoor_params"][sub_attr]
                result["buildoor_params"][sub_attr] = sub_value

    if result.get("disable_peer_scoring"):
        result = enrich_disable_peer_scoring(result)

    if result.get("mev_type") in (
        constants.MOCK_MEV_TYPE,
        constants.FLASHBOTS_MEV_TYPE,
        constants.MEV_RS_MEV_TYPE,
        constants.COMMIT_BOOST_MEV_TYPE,
        constants.HELIX_MEV_TYPE,
        constants.BUILDOOR_MEV_TYPE,
    ):
        result = enrich_mev_extra_params(
            result,
            constants.MEV_BOOST_SERVICE_NAME_PREFIX,
            constants.MEV_BOOST_PORT,
            result.get("mev_type"),
        )
    elif result.get("mev_type") == None:
        pass
    else:
        fail(
            "Unsupported MEV type: {0}, please use 'mock', 'flashbots', 'mev-rs', 'commit-boost', 'helix' or 'buildoor' type".format(
                result.get("mev_type")
            )
        )

    if (
        result["mev_params"].get("mev_builder_subsidy") != 0
        and result["network_params"].get("prefunded_accounts") == {}
    ):
        fail(
            'mev_builder_subsidy is not 0 but prefunded_accounts is empty, please provide a prefunded account for the builder. Example: prefunded_accounts: \'{"0xb9e79D19f651a941757b35830232E7EFC77E1c79": {"balance": "100000ETH"}}\''
        )

    if result["network_params"].get("force_snapshot_sync") and not result["persistent"]:
        fail(
            "network_params.force_snapshot_sync is enabled but persistent is false, please set persistent to true, otherwise the snapshot won't be able to be kept for the run"
        )
    if "shadowfork" in result["network_params"]["network"] and not result["persistent"]:
        fail(
            "shadowfork networks require persistent to be true, otherwise the snapshot won't be able to be kept for the run"
        )

    # Check for shadowfork + archive mode and unsupported client + archive mode combinations
    is_shadowfork = "shadowfork" in result["network_params"]["network"]
    unsupported_archive_clients = ["dummy", "ethrex", "ethereumjs", "nimbus"]

    for idx, participant in enumerate(result["participants"]):
        el_type = participant["el_type"]
        el_storage_type = participant["el_storage_type"]

        # Check if shadowfork is enabled with archive mode
        if is_shadowfork and el_storage_type == "archive":
            fail(
                "Participant {0} (el_type={1}): Archive mode (el_storage_type='archive') is not supported with shadowfork networks. Shadowfork fetches an existing database which may have a different storage type.".format(
                    idx, el_type
                )
            )

        # Check if client doesn't support archive mode
        if el_type in unsupported_archive_clients and el_storage_type == "archive":
            fail(
                "Participant {0}: {1} does not support archive mode (el_storage_type='archive'). Please remove the el_storage_type setting or use a different EL client.".format(
                    idx, el_type
                )
            )

    if result["docker_cache_params"]["enabled"]:
        docker_cache_image_override(plan, result)
    else:
        plan.print("Docker cache is disabled")

    # Handle global nat_exit_ip setting - if set, apply to all service groups
    if result["port_publisher"]["nat_exit_ip"] != "KURTOSIS_IP_ADDR_PLACEHOLDER":
        global_nat_exit_ip = result["port_publisher"]["nat_exit_ip"]
        if global_nat_exit_ip == "auto":
            global_nat_exit_ip = get_public_ip(
                plan, result["global_tolerations"], result["global_node_selectors"]
            )
            result["port_publisher"]["nat_exit_ip"] = global_nat_exit_ip

        # Set all service groups to use the global value
        for service_group in [
            "el",
            "cl",
            "vc",
            "remote_signer",
            "additional_services",
            "mev",
            "other",
        ]:
            result["port_publisher"][service_group]["nat_exit_ip"] = global_nat_exit_ip
    else:
        # Auto-detect public IP for each service group that has nat_exit_ip set to "auto"
        public_ip = None
        for service_group in [
            "el",
            "cl",
            "vc",
            "remote_signer",
            "additional_services",
            "mev",
            "other",
        ]:
            if result["port_publisher"][service_group]["nat_exit_ip"] == "auto":
                if public_ip == None:
                    public_ip = get_public_ip(
                        plan,
                        result["global_tolerations"],
                        result["global_node_selectors"],
                    )
                result["port_publisher"][service_group]["nat_exit_ip"] = public_ip

    if "prometheus_grafana" in result["additional_services"]:
        plan.print(
            "prometheus_grafana in no longer supported, please use 'prometheus' and 'grafana' instead in the additional_services field"
        )
        if (
            "grafana" in result["additional_services"]
            or "prometheus" in result["additional_services"]
        ):
            fail(
                "Please do not define 'grafana' or 'prometheus' in the additional_services field when 'prometheus_grafana' is used to launch both"
            )

    if (
        "mev_type" == constants.MOCK_MEV_TYPE
        and input_args["participants"][0]["cl_type"] != constants.CL_TYPE.lighthouse
    ):
        fail(
            "Mock mev is only supported if the first participant is lighthouse client, please use a different client or set mev_type to 'flashbots', 'mev-rs' or 'commit-boost' or make the first participant lighthouse"
        )

    if (
        result["network_params"]["bpo_1_epoch"]
        < result["network_params"]["fulu_fork_epoch"]
    ):
        result["network_params"]["bpo_1_epoch"] = result["network_params"][
            "fulu_fork_epoch"
        ]
        plan.print(
            "BPO 1 epoch adjusted to Fulu epoch {0}".format(
                result["network_params"]["fulu_fork_epoch"]
            )
        )
    if (
        result["network_params"]["bpo_2_epoch"]
        < result["network_params"]["bpo_1_epoch"]
    ):
        result["network_params"]["bpo_2_epoch"] = result["network_params"][
            "bpo_1_epoch"
        ]
        plan.print(
            "BPO 2 epoch adjusted to BPO 1 epoch {0}".format(
                result["network_params"]["bpo_1_epoch"]
            )
        )
    if (
        result["network_params"]["bpo_3_epoch"]
        < result["network_params"]["bpo_2_epoch"]
    ):
        result["network_params"]["bpo_3_epoch"] = result["network_params"][
            "bpo_2_epoch"
        ]
        plan.print(
            "BPO 3 epoch adjusted to BPO 2 epoch {0}".format(
                result["network_params"]["bpo_2_epoch"]
            )
        )
    if (
        result["network_params"]["bpo_4_epoch"]
        < result["network_params"]["bpo_3_epoch"]
    ):
        result["network_params"]["bpo_4_epoch"] = result["network_params"][
            "bpo_3_epoch"
        ]
        plan.print(
            "BPO 4 epoch adjusted to BPO 3 epoch {0}".format(
                result["network_params"]["bpo_3_epoch"]
            )
        )
    if (
        result["network_params"]["bpo_5_epoch"]
        < result["network_params"]["bpo_4_epoch"]
    ):
        result["network_params"]["bpo_5_epoch"] = result["network_params"][
            "bpo_4_epoch"
        ]
        plan.print(
            "BPO 5 epoch adjusted to BPO 4 epoch {0}".format(
                result["network_params"]["bpo_4_epoch"]
            )
        )

    if result["network_params"]["fulu_fork_epoch"] != constants.FAR_FUTURE_EPOCH:
        has_supernodes = False
        has_node_with_128_plus_validators = False
        num_perfect_peerdas_participants = 0
        for participant in result["participants"]:
            num_perfect_peerdas_participants += 1
            if participant.get("supernode", False):
                has_supernodes = True
            if participant.get("validator_count", 0) >= 128:
                has_node_with_128_plus_validators = True

        if result["network_params"]["perfect_peerdas_enabled"]:
            if num_perfect_peerdas_participants < 16:
                fail(
                    "perfect_peerdas_enabled is true (this is a unique test if you don't know what it does, consider removing it) but the number of participants ({0}) is less than 16. Please set the number of participants to at least 16.".format(
                        str(num_perfect_peerdas_participants)
                    )
                )

        if (
            not has_supernodes
            and not has_node_with_128_plus_validators
            and not result["network_params"]["perfect_peerdas_enabled"]
            and (
                result["network_params"]["network"] == constants.NETWORK_NAME.kurtosis
                or "shadowfork" in result["network_params"]["network"]
            )
        ):
            fail(
                "Fulu fork is enabled (epoch: {0}) but no supernodes are configured, no nodes have 128 or more validators, and perfect_peerdas_enabled is not enabled. Either configure a supernode, ensure at least one node has 128+ validators, or enable perfect_peerdas_enabled in network_params with 16 participants.".format(
                    str(result["network_params"]["fulu_fork_epoch"])
                )
            )

    if "ews" in result["additional_services"]:
        has_non_dummy_el = False
        has_dummy_el = False
        for participant in result["participants"]:
            if participant["el_type"] != "dummy":
                has_non_dummy_el = True
            else:
                has_dummy_el = True
        if not has_non_dummy_el:
            fail(
                "ews (execution-witness-sentry) is enabled but all participants are using dummy EL. At least one participant must use a real EL client (geth, reth, nethermind, etc.) to produce blocks."
            )
        if not has_dummy_el:
            fail(
                "ews (execution-witness-sentry) is enabled but no participants are using dummy EL. At least one participant must use dummy EL to receive execution witnesses."
            )

    if (
        "bootnodoor" not in result["additional_services"]
        and result["participants"][0]["el_type"] == "dummy"
    ):
        fail(
            "First participant cannot use dummy EL without bootnodoor enabled. The first participant acts as the bootnode for the network. Either enable bootnodoor in additional_services or use a real EL client (geth, reth, nethermind, etc.) for the first participant."
        )

    if (
        "mempool_bridge" in result["additional_services"]
        and result["network_params"]["network"] not in constants.PUBLIC_NETWORKS
        and constants.NETWORK_NAME.shadowfork not in result["network_params"]["network"]
    ):
        fail(
            "Mempool bridge is enabled but network is not mainnet, sepolia, hoodi or shadowfork, please set network to mainnet, sepolia, hoodi or shadowfork"
        )

    return struct(
        participants=[
            struct(
                el_type=participant["el_type"],
                el_image=participant["el_image"],
                el_binary_path=participant["el_binary_path"],
                el_log_level=participant["el_log_level"],
                el_storage_type=participant["el_storage_type"],
                el_volume_size=participant["el_volume_size"],
                el_extra_params=participant["el_extra_params"],
                el_extra_mounts=participant["el_extra_mounts"],
                el_devices=participant["el_devices"],
                el_extra_env_vars=participant["el_extra_env_vars"],
                el_extra_labels=participant["el_extra_labels"],
                el_tolerations=participant["el_tolerations"],
                cl_type=participant["cl_type"],
                cl_image=participant["cl_image"],
                cl_binary_path=participant["cl_binary_path"],
                cl_log_level=participant["cl_log_level"],
                cl_volume_size=participant["cl_volume_size"],
                cl_extra_env_vars=participant["cl_extra_env_vars"],
                cl_tolerations=participant["cl_tolerations"],
                use_separate_vc=participant["use_separate_vc"],
                vc_type=participant["vc_type"],
                vc_image=participant["vc_image"],
                vc_binary_path=participant["vc_binary_path"],
                vc_log_level=participant["vc_log_level"],
                vc_tolerations=participant["vc_tolerations"],
                cl_extra_params=participant["cl_extra_params"],
                cl_extra_mounts=participant["cl_extra_mounts"],
                cl_devices=participant["cl_devices"],
                cl_extra_labels=participant["cl_extra_labels"],
                vc_extra_params=participant["vc_extra_params"],
                vc_extra_mounts=participant["vc_extra_mounts"],
                vc_devices=participant["vc_devices"],
                vc_extra_env_vars=participant["vc_extra_env_vars"],
                vc_extra_labels=participant["vc_extra_labels"],
                use_remote_signer=participant["use_remote_signer"],
                remote_signer_type=participant["remote_signer_type"],
                remote_signer_image=participant["remote_signer_image"],
                remote_signer_tolerations=participant["remote_signer_tolerations"],
                remote_signer_extra_env_vars=participant[
                    "remote_signer_extra_env_vars"
                ],
                remote_signer_extra_params=participant["remote_signer_extra_params"],
                remote_signer_extra_labels=participant["remote_signer_extra_labels"],
                builder_network_params=participant["builder_network_params"],
                supernode=participant["supernode"],
                el_min_cpu=participant["el_min_cpu"],
                el_max_cpu=participant["el_max_cpu"],
                el_min_mem=participant["el_min_mem"],
                el_max_mem=participant["el_max_mem"],
                el_force_restart=participant["el_force_restart"],
                cl_min_cpu=participant["cl_min_cpu"],
                cl_max_cpu=participant["cl_max_cpu"],
                cl_min_mem=participant["cl_min_mem"],
                cl_max_mem=participant["cl_max_mem"],
                cl_force_restart=participant["cl_force_restart"],
                vc_min_cpu=participant["vc_min_cpu"],
                vc_max_cpu=participant["vc_max_cpu"],
                vc_min_mem=participant["vc_min_mem"],
                vc_max_mem=participant["vc_max_mem"],
                vc_force_restart=participant["vc_force_restart"],
                remote_signer_min_cpu=participant["remote_signer_min_cpu"],
                remote_signer_max_cpu=participant["remote_signer_max_cpu"],
                remote_signer_min_mem=participant["remote_signer_min_mem"],
                remote_signer_max_mem=participant["remote_signer_max_mem"],
                validator_count=participant["validator_count"],
                tolerations=participant["tolerations"],
                node_selectors=participant["node_selectors"],
                snooper_enabled=participant["snooper_enabled"],
                count=participant["count"],
                ethereum_metrics_exporter_enabled=participant[
                    "ethereum_metrics_exporter_enabled"
                ],
                xatu_sentry_enabled=participant["xatu_sentry_enabled"],
                prometheus_config=struct(
                    scrape_interval=participant["prometheus_config"]["scrape_interval"],
                    labels=participant["prometheus_config"]["labels"],
                ),
                blobber_enabled=participant["blobber_enabled"],
                blobber_extra_params=participant["blobber_extra_params"],
                blobber_image=participant["blobber_image"],
                keymanager_enabled=participant["keymanager_enabled"],
                vc_beacon_node_indices=participant["vc_beacon_node_indices"],
                checkpoint_sync_enabled=participant["checkpoint_sync_enabled"],
                skip_start=participant["skip_start"],
            )
            for participant in result["participants"]
        ],
        network_params=struct(
            preregistered_validator_keys_mnemonic=result["network_params"][
                "preregistered_validator_keys_mnemonic"
            ],
            preregistered_validator_count=result["network_params"][
                "preregistered_validator_count"
            ],
            num_validator_keys_per_node=result["network_params"][
                "num_validator_keys_per_node"
            ],
            network_id=result["network_params"]["network_id"],
            deposit_contract_address=result["network_params"][
                "deposit_contract_address"
            ],
            seconds_per_slot=result["network_params"]["seconds_per_slot"],
            slot_duration_ms=result["network_params"]["slot_duration_ms"],
            genesis_delay=result["network_params"]["genesis_delay"],
            genesis_time=result["network_params"]["genesis_time"],
            genesis_gaslimit=result["network_params"]["genesis_gaslimit"],
            max_per_epoch_activation_churn_limit=result["network_params"][
                "max_per_epoch_activation_churn_limit"
            ],
            churn_limit_quotient=result["network_params"]["churn_limit_quotient"],
            ejection_balance=result["network_params"]["ejection_balance"],
            eth1_follow_distance=result["network_params"]["eth1_follow_distance"],
            altair_fork_epoch=result["network_params"]["altair_fork_epoch"],
            bellatrix_fork_epoch=result["network_params"]["bellatrix_fork_epoch"],
            capella_fork_epoch=result["network_params"]["capella_fork_epoch"],
            deneb_fork_epoch=result["network_params"]["deneb_fork_epoch"],
            electra_fork_epoch=result["network_params"]["electra_fork_epoch"],
            fulu_fork_epoch=result["network_params"]["fulu_fork_epoch"],
            gloas_fork_epoch=result["network_params"]["gloas_fork_epoch"],
            eip7805_fork_epoch=result["network_params"]["eip7805_fork_epoch"],
            eip7441_fork_epoch=result["network_params"]["eip7441_fork_epoch"],
            network=result["network_params"]["network"],
            min_validator_withdrawability_delay=result["network_params"][
                "min_validator_withdrawability_delay"
            ],
            min_builder_withdrawability_delay=result["network_params"][
                "min_builder_withdrawability_delay"
            ],
            shard_committee_period=result["network_params"]["shard_committee_period"],
            attestation_due_bps_gloas=result["network_params"][
                "attestation_due_bps_gloas"
            ],
            aggregate_due_bps_gloas=result["network_params"]["aggregate_due_bps_gloas"],
            sync_message_due_bps_gloas=result["network_params"][
                "sync_message_due_bps_gloas"
            ],
            contribution_due_bps_gloas=result["network_params"][
                "contribution_due_bps_gloas"
            ],
            payload_attestation_due_bps=result["network_params"][
                "payload_attestation_due_bps"
            ],
            view_freeze_cutoff_bps=result["network_params"]["view_freeze_cutoff_bps"],
            inclusion_list_submission_due_bps=result["network_params"][
                "inclusion_list_submission_due_bps"
            ],
            proposer_inclusion_list_cutoff_bps=result["network_params"][
                "proposer_inclusion_list_cutoff_bps"
            ],
            network_sync_base_url=result["network_params"]["network_sync_base_url"],
            force_snapshot_sync=result["network_params"]["force_snapshot_sync"],
            shadowfork_block_height=result["network_params"]["shadowfork_block_height"],
            data_column_sidecar_subnet_count=result["network_params"][
                "data_column_sidecar_subnet_count"
            ],
            samples_per_slot=result["network_params"]["samples_per_slot"],
            custody_requirement=result["network_params"]["custody_requirement"],
            max_blobs_per_block_electra=result["network_params"][
                "max_blobs_per_block_electra"
            ],
            target_blobs_per_block_electra=result["network_params"][
                "target_blobs_per_block_electra"
            ],
            max_request_blocks_deneb=result["network_params"][
                "max_request_blocks_deneb"
            ],
            max_request_blob_sidecars_electra=result["network_params"][
                "max_request_blob_sidecars_electra"
            ],
            base_fee_update_fraction_electra=result["network_params"][
                "base_fee_update_fraction_electra"
            ],
            bpo_1_epoch=result["network_params"]["bpo_1_epoch"],
            bpo_1_max_blobs=result["network_params"]["bpo_1_max_blobs"],
            bpo_1_target_blobs=result["network_params"]["bpo_1_target_blobs"],
            bpo_1_base_fee_update_fraction=result["network_params"][
                "bpo_1_base_fee_update_fraction"
            ],
            bpo_2_epoch=result["network_params"]["bpo_2_epoch"],
            bpo_2_max_blobs=result["network_params"]["bpo_2_max_blobs"],
            bpo_2_target_blobs=result["network_params"]["bpo_2_target_blobs"],
            bpo_2_base_fee_update_fraction=result["network_params"][
                "bpo_2_base_fee_update_fraction"
            ],
            bpo_3_epoch=result["network_params"]["bpo_3_epoch"],
            bpo_3_max_blobs=result["network_params"]["bpo_3_max_blobs"],
            bpo_3_target_blobs=result["network_params"]["bpo_3_target_blobs"],
            bpo_3_base_fee_update_fraction=result["network_params"][
                "bpo_3_base_fee_update_fraction"
            ],
            bpo_4_epoch=result["network_params"]["bpo_4_epoch"],
            bpo_4_max_blobs=result["network_params"]["bpo_4_max_blobs"],
            bpo_4_target_blobs=result["network_params"]["bpo_4_target_blobs"],
            bpo_4_base_fee_update_fraction=result["network_params"][
                "bpo_4_base_fee_update_fraction"
            ],
            bpo_5_epoch=result["network_params"]["bpo_5_epoch"],
            bpo_5_max_blobs=result["network_params"]["bpo_5_max_blobs"],
            bpo_5_target_blobs=result["network_params"]["bpo_5_target_blobs"],
            bpo_5_base_fee_update_fraction=result["network_params"][
                "bpo_5_base_fee_update_fraction"
            ],
            preset=result["network_params"]["preset"],
            additional_preloaded_contracts=result["network_params"][
                "additional_preloaded_contracts"
            ],
            additional_mnemonics=result["network_params"]["additional_mnemonics"],
            devnet_repo=result["network_params"]["devnet_repo"],
            prefunded_accounts=result["network_params"]["prefunded_accounts"],
            max_payload_size=result["network_params"]["max_payload_size"],
            perfect_peerdas_enabled=result["network_params"]["perfect_peerdas_enabled"],
            gas_limit=result["network_params"]["gas_limit"],
            withdrawal_type=result["network_params"]["withdrawal_type"],
            withdrawal_address=result["network_params"]["withdrawal_address"],
            validator_balance=result["network_params"]["validator_balance"],
            min_epochs_for_data_column_sidecars_requests=result["network_params"][
                "min_epochs_for_data_column_sidecars_requests"
            ],
            min_epochs_for_block_requests=result["network_params"][
                "min_epochs_for_block_requests"
            ],
        ),
        mev_params=struct(
            mev_relay_image=result["mev_params"]["mev_relay_image"],
            mev_builder_image=result["mev_params"]["mev_builder_image"],
            mev_builder_cl_image=result["mev_params"]["mev_builder_cl_image"],
            mev_builder_extra_data=result["mev_params"]["mev_builder_extra_data"],
            mev_builder_subsidy=result["mev_params"]["mev_builder_subsidy"],
            mev_boost_image=result["mev_params"]["mev_boost_image"],
            mev_boost_args=result["mev_params"]["mev_boost_args"],
            mev_relay_api_extra_args=result["mev_params"]["mev_relay_api_extra_args"],
            mev_relay_api_extra_env_vars=result["mev_params"][
                "mev_relay_api_extra_env_vars"
            ],
            mev_relay_housekeeper_extra_args=result["mev_params"][
                "mev_relay_housekeeper_extra_args"
            ],
            mev_relay_housekeeper_extra_env_vars=result["mev_params"][
                "mev_relay_housekeeper_extra_env_vars"
            ],
            mev_relay_website_extra_args=result["mev_params"][
                "mev_relay_website_extra_args"
            ],
            mev_relay_website_extra_env_vars=result["mev_params"][
                "mev_relay_website_extra_env_vars"
            ],
            mev_builder_extra_args=result["mev_params"]["mev_builder_extra_args"],
            mev_builder_cl_extra_params=result["mev_params"][
                "mev_builder_cl_extra_params"
            ],
            mev_builder_prometheus_config=result["mev_params"][
                "mev_builder_prometheus_config"
            ],
            mock_mev_image=result["mev_params"]["mock_mev_image"],
            launch_adminer=result["mev_params"]["launch_adminer"],
            run_multiple_relays=result["mev_params"]["run_multiple_relays"],
            helix_relay_image=result["mev_params"]["helix_relay_image"],
        )
        if result["mev_params"]
        else None,
        blockscout_params=struct(
            image=result["blockscout_params"]["image"],
            verif_image=result["blockscout_params"]["verif_image"],
            frontend_image=result["blockscout_params"]["frontend_image"],
            env=result["blockscout_params"]["env"],
        ),
        checkpointz_params=struct(
            image=result["checkpointz_params"]["image"],
        ),
        dora_params=struct(
            image=result["dora_params"]["image"],
            env=result["dora_params"]["env"],
        ),
        docker_cache_params=struct(
            enabled=result["docker_cache_params"]["enabled"],
            url=result["docker_cache_params"]["url"],
            dockerhub_prefix=result["docker_cache_params"]["dockerhub_prefix"],
            github_prefix=result["docker_cache_params"]["github_prefix"],
            google_prefix=result["docker_cache_params"]["google_prefix"],
        ),
        tx_fuzz_params=struct(
            image=result["tx_fuzz_params"]["image"],
            tx_fuzz_extra_args=result["tx_fuzz_params"]["tx_fuzz_extra_args"],
        ),
        rakoon_params=struct(
            image=result["rakoon_params"]["image"],
            tx_type=result["rakoon_params"]["tx_type"],
            workers=result["rakoon_params"]["workers"],
            batch_size=result["rakoon_params"]["batch_size"],
            seed=result["rakoon_params"]["seed"],
            fuzzing=result["rakoon_params"]["fuzzing"],
            poll_interval=result["rakoon_params"]["poll_interval"],
            extra_args=result["rakoon_params"]["extra_args"],
        ),
        prometheus_params=struct(
            storage_tsdb_retention_time=result["prometheus_params"][
                "storage_tsdb_retention_time"
            ],
            storage_tsdb_retention_size=result["prometheus_params"][
                "storage_tsdb_retention_size"
            ],
            min_cpu=result["prometheus_params"]["min_cpu"],
            max_cpu=result["prometheus_params"]["max_cpu"],
            min_mem=result["prometheus_params"]["min_mem"],
            max_mem=result["prometheus_params"]["max_mem"],
            image=result["prometheus_params"]["image"],
        ),
        grafana_params=struct(
            additional_dashboards=result["grafana_params"]["additional_dashboards"],
            min_cpu=result["grafana_params"]["min_cpu"],
            max_cpu=result["grafana_params"]["max_cpu"],
            min_mem=result["grafana_params"]["min_mem"],
            max_mem=result["grafana_params"]["max_mem"],
            image=result["grafana_params"]["image"],
        ),
        tempo_params=struct(
            retention_duration=result["tempo_params"]["retention_duration"],
            ingestion_rate_limit=result["tempo_params"]["ingestion_rate_limit"],
            ingestion_burst_limit=result["tempo_params"]["ingestion_burst_limit"],
            max_search_duration=result["tempo_params"]["max_search_duration"],
            max_bytes_per_trace=result["tempo_params"]["max_bytes_per_trace"],
            min_cpu=result["tempo_params"]["min_cpu"],
            max_cpu=result["tempo_params"]["max_cpu"],
            min_mem=result["tempo_params"]["min_mem"],
            max_mem=result["tempo_params"]["max_mem"],
            image=result["tempo_params"]["image"],
        ),
        apache_port=result["apache_port"],
        nginx_port=result["nginx_port"],
        assertoor_params=struct(
            image=result["assertoor_params"]["image"],
            run_stability_check=result["assertoor_params"]["run_stability_check"],
            run_block_proposal_check=result["assertoor_params"][
                "run_block_proposal_check"
            ],
            run_lifecycle_test=result["assertoor_params"]["run_lifecycle_test"],
            run_transaction_test=result["assertoor_params"]["run_transaction_test"],
            run_blob_transaction_test=result["assertoor_params"][
                "run_blob_transaction_test"
            ],
            run_opcodes_transaction_test=result["assertoor_params"][
                "run_opcodes_transaction_test"
            ],
            tests=result["assertoor_params"]["tests"],
        ),
        custom_flood_params=struct(
            interval_between_transactions=result["custom_flood_params"][
                "interval_between_transactions"
            ],
        ),
        spamoor_params=struct(
            image=result["spamoor_params"]["image"],
            min_cpu=result["spamoor_params"]["min_cpu"],
            max_cpu=result["spamoor_params"]["max_cpu"],
            min_mem=result["spamoor_params"]["min_mem"],
            max_mem=result["spamoor_params"]["max_mem"],
            spammers=result["spamoor_params"]["spammers"],
            extra_args=result["spamoor_params"]["extra_args"],
        ),
        slashoor_params=struct(
            image=result["slashoor_params"]["image"],
            min_cpu=result["slashoor_params"]["min_cpu"],
            max_cpu=result["slashoor_params"]["max_cpu"],
            min_mem=result["slashoor_params"]["min_mem"],
            max_mem=result["slashoor_params"]["max_mem"],
            extra_args=result["slashoor_params"]["extra_args"],
            log_level=result["slashoor_params"]["log_level"],
            beacon_timeout=result["slashoor_params"]["beacon_timeout"],
            max_epochs_to_keep=result["slashoor_params"]["max_epochs_to_keep"],
            detector_enabled=result["slashoor_params"]["detector_enabled"],
            proposer_enabled=result["slashoor_params"]["proposer_enabled"],
            submitter_enabled=result["slashoor_params"]["submitter_enabled"],
            submitter_dry_run=result["slashoor_params"]["submitter_dry_run"],
            dora_enabled=result["slashoor_params"]["dora_enabled"],
            dora_url=result["slashoor_params"]["dora_url"],
            dora_scan_on_startup=result["slashoor_params"]["dora_scan_on_startup"],
            backfill_slots=result["slashoor_params"]["backfill_slots"],
        ),
        mempool_bridge_params=struct(
            image=result["mempool_bridge_params"]["image"],
            source_enodes=result["mempool_bridge_params"]["source_enodes"],
            mode=result["mempool_bridge_params"]["mode"],
            log_level=result["mempool_bridge_params"]["log_level"],
            send_concurrency=result["mempool_bridge_params"]["send_concurrency"],
            polling_interval=result["mempool_bridge_params"]["polling_interval"],
            retry_interval=result["mempool_bridge_params"]["retry_interval"],
        ),
        additional_services=result["additional_services"],
        wait_for_finalization=result["wait_for_finalization"],
        global_log_level=result["global_log_level"],
        mev_type=result["mev_type"],
        snooper_enabled=result["snooper_enabled"],
        ethereum_metrics_exporter_enabled=result["ethereum_metrics_exporter_enabled"],
        xatu_sentry_enabled=result["xatu_sentry_enabled"],
        parallel_keystore_generation=result["parallel_keystore_generation"],
        disable_peer_scoring=result["disable_peer_scoring"],
        persistent=result["persistent"],
        xatu_sentry_params=struct(
            xatu_sentry_image=result["xatu_sentry_params"]["xatu_sentry_image"],
            xatu_server_addr=result["xatu_sentry_params"]["xatu_server_addr"],
            xatu_server_headers=result["xatu_sentry_params"]["xatu_server_headers"],
            beacon_subscriptions=result["xatu_sentry_params"]["beacon_subscriptions"],
            xatu_server_tls=result["xatu_sentry_params"]["xatu_server_tls"],
        ),
        global_tolerations=result["global_tolerations"],
        global_node_selectors=result["global_node_selectors"],
        keymanager_enabled=result["keymanager_enabled"],
        extra_files=result.get("extra_files", {}),
        checkpoint_sync_enabled=result["checkpoint_sync_enabled"],
        checkpoint_sync_url=result["checkpoint_sync_url"],
        ethereum_genesis_generator_params=struct(
            image=result["ethereum_genesis_generator_params"]["image"],
            extra_env=result["ethereum_genesis_generator_params"]["extra_env"],
        ),
        port_publisher=struct(
            nat_exit_ip=result["port_publisher"]["nat_exit_ip"],
            cl_enabled=result["port_publisher"]["cl"]["enabled"],
            cl_public_port_start=result["port_publisher"]["cl"]["public_port_start"],
            cl_nat_exit_ip=result["port_publisher"]["cl"]["nat_exit_ip"],
            el_enabled=result["port_publisher"]["el"]["enabled"],
            el_public_port_start=result["port_publisher"]["el"]["public_port_start"],
            el_nat_exit_ip=result["port_publisher"]["el"]["nat_exit_ip"],
            vc_enabled=result["port_publisher"]["vc"]["enabled"],
            vc_public_port_start=result["port_publisher"]["vc"]["public_port_start"],
            vc_nat_exit_ip=result["port_publisher"]["vc"]["nat_exit_ip"],
            remote_signer_enabled=result["port_publisher"]["remote_signer"]["enabled"],
            remote_signer_public_port_start=result["port_publisher"]["remote_signer"][
                "public_port_start"
            ],
            remote_signer_nat_exit_ip=result["port_publisher"]["remote_signer"][
                "nat_exit_ip"
            ],
            additional_services_enabled=result["port_publisher"]["additional_services"][
                "enabled"
            ],
            additional_services_public_port_start=result["port_publisher"][
                "additional_services"
            ]["public_port_start"],
            additional_services_nat_exit_ip=result["port_publisher"][
                "additional_services"
            ]["nat_exit_ip"],
            mev_enabled=result["port_publisher"]["mev"]["enabled"],
            mev_public_port_start=result["port_publisher"]["mev"]["public_port_start"],
            mev_nat_exit_ip=result["port_publisher"]["mev"]["nat_exit_ip"],
            other_enabled=result["port_publisher"]["other"]["enabled"],
            other_public_port_start=result["port_publisher"]["other"][
                "public_port_start"
            ],
            other_nat_exit_ip=result["port_publisher"]["other"]["nat_exit_ip"],
        ),
        bootnodoor_params=struct(
            image=result["bootnodoor_params"]["image"],
            min_cpu=result["bootnodoor_params"]["min_cpu"],
            max_cpu=result["bootnodoor_params"]["max_cpu"],
            min_mem=result["bootnodoor_params"]["min_mem"],
            max_mem=result["bootnodoor_params"]["max_mem"],
            extra_args=result["bootnodoor_params"]["extra_args"],
        ),
        ews_params=struct(
            image=result["ews_params"]["image"],
            retain=result["ews_params"]["retain"],
            num_proofs=result["ews_params"]["num_proofs"],
            env=result["ews_params"]["env"],
        ),
        buildoor_params=struct(
            image=result["buildoor_params"]["image"],
            extra_args=result["buildoor_params"]["extra_args"],
            builder_api=result["buildoor_params"]["builder_api"],
            epbs_builder=result["buildoor_params"]["epbs_builder"],
        ),
    )


def parse_network_params(plan, input_args):
    result = default_input_args(input_args)
    if input_args.get("network_params", {}).get("preset") == "minimal":
        result["network_params"] = default_minimal_network_params()

    # Ensure we handle matrix participants before standard participants are handled.
    if "participants_matrix" in input_args:
        participants = []

        el_matrix = []
        if "el" in input_args["participants_matrix"]:
            el_matrix = input_args["participants_matrix"]["el"]
        cl_matrix = []
        if "cl" in input_args["participants_matrix"]:
            cl_matrix = input_args["participants_matrix"]["cl"]
        vc_matrix = []
        if "vc" in input_args["participants_matrix"]:
            vc_matrix = input_args["participants_matrix"]["vc"]

        for el in el_matrix:
            for cl in cl_matrix:
                participant = {k: v for k, v in el.items()}
                for k, v in cl.items():
                    participant[k] = v

                participants.append(participant)

        for index, participant in enumerate(participants):
            for vc in vc_matrix:
                for k, v in vc.items():
                    participants[index][k] = v

        if "participants" in input_args:
            input_args["participants"].extend(participants)
        else:
            input_args["participants"] = participants

    for attr in input_args:
        value = input_args[attr]
        # if its inserted we use the value inserted
        if attr not in ATTR_TO_BE_SKIPPED_AT_ROOT:
            result[attr] = value
        elif attr == "network_params":
            for sub_attr in input_args["network_params"]:
                sub_value = input_args["network_params"][sub_attr]
                result["network_params"][sub_attr] = sub_value

            # Apply 2/3 ratio for BPO max and target blobs
            for bpo_num in range(1, 6):  # BPO 1 through 5
                max_key = "bpo_{}_max_blobs".format(bpo_num)
                target_key = "bpo_{}_target_blobs".format(bpo_num)

                # If only max is set (non-zero), calculate target as 2/3 of max (rounded)
                if result["network_params"].get(max_key) and not result[
                    "network_params"
                ].get(target_key):
                    result["network_params"][target_key] = int(
                        result["network_params"][max_key] * 2.0 / 3.0 + 0.5
                    )
                # If only target is set (non-zero), calculate max as target * 3/2 (rounded)
                elif result["network_params"].get(target_key) and not result[
                    "network_params"
                ].get(max_key):
                    result["network_params"][max_key] = int(
                        result["network_params"][target_key] * 3.0 / 2.0 + 0.5
                    )
                # If both are set or both are 0, don't override
        elif attr == "participants":
            participants = []
            for participant in input_args["participants"]:
                new_participant = default_participant()
                for sub_attr, sub_value in participant.items():
                    # if the value is set in input we set it in participant
                    new_participant[sub_attr] = sub_value
                for _ in range(0, new_participant["count"]):
                    participant_copy = deep_copy_participant(new_participant)
                    participants.append(participant_copy)
            result["participants"] = participants

    total_participant_count = 0
    actual_num_validators = 0
    # validation of the above defaults
    for index, participant in enumerate(result["participants"]):
        el_type = participant["el_type"]
        cl_type = participant["cl_type"]
        vc_type = participant["vc_type"]
        remote_signer_type = participant["remote_signer_type"]

        if (
            cl_type in (constants.CL_TYPE.nimbus)
            and (result["network_params"]["seconds_per_slot"] < 12)
            and result["network_params"]["preset"] == "mainnet"
        ):
            fail(
                "nimbus can't be run with slot times below 12 seconds with "
                + result["network_params"]["preset"]
                + " preset"
            )

        if (
            cl_type in (constants.CL_TYPE.nimbus)
            and (result["network_params"]["seconds_per_slot"] != 6)
            and result["network_params"]["preset"] == "minimal"
        ):
            fail(
                "nimbus can't be run with slot times different than 6 seconds with "
                + result["network_params"]["preset"]
                + " preset"
            )

        el_image = participant["el_image"]
        if el_image == "":
            # Get devnet-modified images if network contains 'devnet'
            effective_el_images = get_devnet_modified_images(
                result["network_params"]["network"], DEFAULT_EL_IMAGES
            )
            default_image = effective_el_images.get(el_type, "")
            if default_image == "":
                fail(
                    "{0} received an empty image name and we don't have a default for it".format(
                        el_type
                    )
                )
            participant["el_image"] = default_image

        cl_image = participant["cl_image"]
        if cl_image == "":
            if result["network_params"]["preset"] == "minimal":
                # Get devnet-modified images if network contains 'devnet'
                effective_cl_images = get_devnet_modified_images(
                    result["network_params"]["network"], DEFAULT_CL_IMAGES_MINIMAL
                )
                default_image = effective_cl_images.get(cl_type, "")
            else:
                # Get devnet-modified images if network contains 'devnet'
                effective_cl_images = get_devnet_modified_images(
                    result["network_params"]["network"], DEFAULT_CL_IMAGES
                )
                default_image = effective_cl_images.get(cl_type, "")
            if default_image == "":
                fail(
                    "{0} received an empty image name and we don't have a default for it".format(
                        cl_type
                    )
                )
            participant["cl_image"] = default_image

        if participant["use_separate_vc"] == None:
            # Default to false for CL clients that can run validator clients
            # in the same process.
            if (
                cl_type
                in (
                    constants.CL_TYPE.nimbus,
                    constants.CL_TYPE.teku,
                    constants.CL_TYPE.grandine,
                )
                and vc_type == ""
            ):
                participant["use_separate_vc"] = False
            else:
                participant["use_separate_vc"] = True

        if participant["use_remote_signer"] and not participant["use_separate_vc"]:
            fail("`use_remote_signer` requires `use_separate_vc`")

        if vc_type == "":
            # Defaults to matching the chosen CL client
            vc_type = cl_type
            participant["vc_type"] = vc_type

        vc_image = participant["vc_image"]
        if vc_image == "":
            if cl_image == "" or vc_type != cl_type:
                # If the validator client image is also empty, default to the image for the chosen CL client
                if result["network_params"]["preset"] == "minimal":
                    # Get devnet-modified images if network contains 'devnet'
                    effective_vc_images = get_devnet_modified_images(
                        result["network_params"]["network"], DEFAULT_VC_IMAGES_MINIMAL
                    )
                    default_image = effective_vc_images.get(vc_type, "")
                else:
                    # Get devnet-modified images if network contains 'devnet'
                    effective_vc_images = get_devnet_modified_images(
                        result["network_params"]["network"], DEFAULT_VC_IMAGES
                    )
                    default_image = effective_vc_images.get(vc_type, "")
            else:
                if cl_type == "prysm":
                    default_image = cl_image.replace("beacon-chain", "validator")
                elif cl_type == "nimbus":
                    default_image = cl_image.replace(
                        "nimbus-eth2", "nimbus-validator-client"
                    )
                else:
                    default_image = cl_image
            if default_image == "":
                fail(
                    "{0} received an empty image name and we don't have a default for it".format(
                        vc_type
                    )
                )
            participant["vc_image"] = default_image

        remote_signer_image = participant["remote_signer_image"]
        if remote_signer_image == "":
            participant["remote_signer_image"] = DEFAULT_REMOTE_SIGNER_IMAGES.get(
                remote_signer_type, ""
            )

        snooper_enabled = participant["snooper_enabled"]
        if snooper_enabled == None:
            participant["snooper_enabled"] = result["snooper_enabled"]

        keymanager_enabled = participant["keymanager_enabled"]
        if keymanager_enabled == None:
            participant["keymanager_enabled"] = result["keymanager_enabled"]

        ethereum_metrics_exporter_enabled = participant[
            "ethereum_metrics_exporter_enabled"
        ]
        if ethereum_metrics_exporter_enabled == None:
            participant["ethereum_metrics_exporter_enabled"] = result[
                "ethereum_metrics_exporter_enabled"
            ]

        xatu_sentry_enabled = participant["xatu_sentry_enabled"]
        if xatu_sentry_enabled == None:
            participant["xatu_sentry_enabled"] = result["xatu_sentry_enabled"]

        blobber_enabled = participant["blobber_enabled"]
        if blobber_enabled:
            # lighthouse, lodestar, prysm, and grandine support blobber
            if participant["cl_type"] not in [
                constants.CL_TYPE.lighthouse,
                constants.CL_TYPE.lodestar,
                constants.CL_TYPE.prysm,
                constants.CL_TYPE.grandine,
            ]:
                fail(
                    "blobber is not supported for {0} client".format(
                        participant["cl_type"]
                    )
                )

        validator_count = participant["validator_count"]
        if validator_count == None:
            participant["validator_count"] = result["network_params"][
                "num_validator_keys_per_node"
            ]

        actual_num_validators += participant["validator_count"]

        cl_extra_params = participant.get("cl_extra_params", [])
        participant["cl_extra_params"] = cl_extra_params

        vc_extra_params = participant.get("vc_extra_params", [])
        participant["vc_extra_params"] = vc_extra_params

        remote_signer_extra_params = participant.get("remote_signer_extra_params", [])
        participant["remote_signer_extra_params"] = remote_signer_extra_params

        total_participant_count += participant["count"]

    if total_participant_count == 1:
        for index, participant in enumerate(result["participants"]):
            # If there is only one participant, we run lodestar as a single node mode
            if participant["cl_type"] == constants.CL_TYPE.lodestar:
                participant["cl_extra_params"].append("--sync.isSingleNode")
                participant["cl_extra_params"].append(
                    "--network.allowPublishToZeroPeers"
                )

    if result["network_params"]["network_id"].strip() == "":
        fail("network_id is empty or spaces it needs to be of non zero length")

    if result["network_params"]["deposit_contract_address"].strip() == "":
        fail(
            "deposit_contract_address is empty or spaces it needs to be of non zero length"
        )

    if (
        result["network_params"]["network"] == "kurtosis"
        or constants.NETWORK_NAME.shadowfork in result["network_params"]["network"]
    ):
        if (
            result["network_params"]["preregistered_validator_keys_mnemonic"].strip()
            == ""
        ):
            fail(
                "preregistered_validator_keys_mnemonic is empty or spaces it needs to be of non zero length"
            )

    if result["network_params"]["seconds_per_slot"] == 0:
        fail("seconds_per_slot is 0 needs to be > 0 ")

    seconds_per_slot = result["network_params"]["seconds_per_slot"]
    slot_duration_ms = result["network_params"]["slot_duration_ms"]
    preset = result["network_params"]["preset"]

    if preset == "minimal":
        seconds_per_slot_is_set = seconds_per_slot != 6
        slot_duration_ms_is_set = slot_duration_ms != 6000
    else:
        seconds_per_slot_is_set = seconds_per_slot != 12
        slot_duration_ms_is_set = slot_duration_ms != 12000

    # Apply validation logic based on your requirements:
    # One set 8/12000 -> 8/8000
    # Both set incorrectly -> fail
    if seconds_per_slot_is_set and not slot_duration_ms_is_set:
        result["network_params"]["slot_duration_ms"] = seconds_per_slot * 1000
    elif not seconds_per_slot_is_set and slot_duration_ms_is_set:
        result["network_params"]["seconds_per_slot"] = int(slot_duration_ms / 1000)
    else:
        expected_slot_duration_ms = seconds_per_slot * 1000
        if slot_duration_ms != expected_slot_duration_ms:
            fail(
                "seconds_per_slot ({0}) and slot_duration_ms ({1}) are inconsistent. Expected slot_duration_ms to be {2}. Use the same value for both, or only define one of them.".format(
                    seconds_per_slot, slot_duration_ms, expected_slot_duration_ms
                )
            )

    if (
        result["network_params"]["network"] != constants.NETWORK_NAME.kurtosis
        and constants.NETWORK_NAME.shadowfork not in result["network_params"]["network"]
    ):
        for participant in result["participants"]:
            participant["validator_count"] = 0

    if result["network_params"]["preset"] not in ["mainnet", "minimal"]:
        fail(
            "preset "
            + result["network_params"]["preset"]
            + " is not supported, it can only be mainnet or minimal"
        )

    return result


def get_client_log_level_or_default(
    participant_log_level, global_log_level, client_log_levels
):
    log_level = client_log_levels.get(participant_log_level, "")
    if log_level == "":
        log_level = client_log_levels.get(global_log_level, "")
        if log_level == "":
            fail(
                "No participant log level defined, and the client log level has no mapping for global log level '{0}'".format(
                    global_log_level
                )
            )
    return log_level


def get_client_node_selectors(participant_node_selectors, global_node_selectors):
    node_selectors = {}
    node_selectors = participant_node_selectors if participant_node_selectors else {}
    if node_selectors == {}:
        node_selectors = global_node_selectors if global_node_selectors else {}

    return node_selectors


def default_input_args(input_args):
    network_params = default_network_params()
    if "participants_matrix" not in input_args:
        participants = [default_participant()]
    else:
        participants = []

    participants_matrix = []

    if (
        "network_params" in input_args
        and "network" in input_args["network_params"]
        and (
            input_args["network_params"]["network"] in constants.PUBLIC_NETWORKS
            or input_args["network_params"]["network"]
            == constants.NETWORK_NAME.ephemery
            or "devnet" in input_args["network_params"]["network"]
        )
    ):
        checkpoint_sync_enabled = True
    else:
        checkpoint_sync_enabled = False

    return {
        "participants": participants,
        "participants_matrix": participants_matrix,
        "network_params": network_params,
        "extra_files": {},
        "wait_for_finalization": False,
        "global_log_level": "info",
        "snooper_enabled": False,
        "ethereum_metrics_exporter_enabled": False,
        "parallel_keystore_generation": False,
        "disable_peer_scoring": False,
        "persistent": False,
        "mev_type": None,
        "xatu_sentry_enabled": False,
        "apache_port": None,
        "nginx_port": None,
        "global_tolerations": [],
        "global_node_selectors": {},
        "use_remote_signer": False,
        "keymanager_enabled": False,
        "checkpoint_sync_enabled": checkpoint_sync_enabled,
        "checkpoint_sync_url": "",
        "ethereum_genesis_generator_params": get_default_ethereum_genesis_generator_params(),
        "port_publisher": {
            "nat_exit_ip": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
            "public_port_start": None,
        },
        "spamoor_params": get_default_spamoor_params(),
        "bootnodoor_params": get_default_bootnodoor_params(),
    }


def default_network_params():
    return {
        "network": "kurtosis",
        "network_id": "3151908",
        "deposit_contract_address": "0x00000000219ab540356cBB839Cbe05303d7705Fa",
        "seconds_per_slot": 12,
        "slot_duration_ms": 12000,
        "num_validator_keys_per_node": 128,
        "preregistered_validator_keys_mnemonic": constants.DEFAULT_MNEMONIC,
        "preregistered_validator_count": 0,
        "genesis_delay": 20,
        "genesis_time": 0,
        "genesis_gaslimit": 60000000,
        "max_per_epoch_activation_churn_limit": 8,
        "churn_limit_quotient": 65536,
        "ejection_balance": 16000000000,
        "eth1_follow_distance": 2048,
        "min_validator_withdrawability_delay": 256,
        "min_builder_withdrawability_delay": 4096,
        "shard_committee_period": 256,
        "attestation_due_bps_gloas": 2500,
        "aggregate_due_bps_gloas": 5000,
        "sync_message_due_bps_gloas": 2500,
        "contribution_due_bps_gloas": 5000,
        "payload_attestation_due_bps": 7500,
        "view_freeze_cutoff_bps": 7500,
        "inclusion_list_submission_due_bps": 6667,
        "proposer_inclusion_list_cutoff_bps": 9167,
        "altair_fork_epoch": 0,
        "bellatrix_fork_epoch": 0,
        "capella_fork_epoch": 0,
        "deneb_fork_epoch": 0,
        "electra_fork_epoch": 0,
        "fulu_fork_epoch": 0,
        "gloas_fork_epoch": constants.FAR_FUTURE_EPOCH,
        "eip7805_fork_epoch": constants.FAR_FUTURE_EPOCH,
        "eip7441_fork_epoch": constants.FAR_FUTURE_EPOCH,
        "network_sync_base_url": "https://snapshots.ethpandaops.io/",
        "force_snapshot_sync": False,
        "shadowfork_block_height": "latest",
        "data_column_sidecar_subnet_count": 128,
        "samples_per_slot": 8,
        "custody_requirement": 4,
        "max_blobs_per_block_electra": 9,
        "target_blobs_per_block_electra": 6,
        "max_request_blocks_deneb": 128,
        "max_request_blob_sidecars_electra": 1152,
        "base_fee_update_fraction_electra": 5007716,
        "preset": "mainnet",
        "additional_preloaded_contracts": {},
        "additional_mnemonics": [],
        "devnet_repo": "ethpandaops",
        "prefunded_accounts": {},
        "max_payload_size": 10485760,
        "perfect_peerdas_enabled": False,
        "gas_limit": 0,
        "bpo_1_epoch": 0,
        "bpo_1_max_blobs": 15,
        "bpo_1_target_blobs": 10,
        "bpo_1_base_fee_update_fraction": 8346193,
        "bpo_2_epoch": 18446744073709551615,
        "bpo_2_max_blobs": 21,
        "bpo_2_target_blobs": 14,
        "bpo_2_base_fee_update_fraction": 11684671,
        "bpo_3_epoch": 18446744073709551615,
        "bpo_3_max_blobs": 0,
        "bpo_3_target_blobs": 0,
        "bpo_3_base_fee_update_fraction": 0,
        "bpo_4_epoch": 18446744073709551615,
        "bpo_4_max_blobs": 0,
        "bpo_4_target_blobs": 0,
        "bpo_4_base_fee_update_fraction": 0,
        "bpo_5_epoch": 18446744073709551615,
        "bpo_5_max_blobs": 0,
        "bpo_5_target_blobs": 0,
        "bpo_5_base_fee_update_fraction": 0,
        "withdrawal_type": "0x00",
        "withdrawal_address": "0x8943545177806ED17B9F23F0a21ee5948eCaa776",
        "validator_balance": 32,
        "min_epochs_for_data_column_sidecars_requests": 4096,
        "min_epochs_for_block_requests": 33024,
    }


def default_minimal_network_params():
    return {
        "network": "kurtosis",
        "network_id": "3151908",
        "deposit_contract_address": "0x00000000219ab540356cBB839Cbe05303d7705Fa",
        "seconds_per_slot": 6,
        "slot_duration_ms": 6000,
        "num_validator_keys_per_node": 128,
        "preregistered_validator_keys_mnemonic": constants.DEFAULT_MNEMONIC,
        "preregistered_validator_count": 0,
        "genesis_delay": 20,
        "genesis_time": 0,
        "genesis_gaslimit": 60000000,
        "max_per_epoch_activation_churn_limit": 4,
        "churn_limit_quotient": 32,
        "ejection_balance": 16000000000,
        "eth1_follow_distance": 16,
        "min_validator_withdrawability_delay": 256,
        "min_builder_withdrawability_delay": 8,
        "shard_committee_period": 64,
        "attestation_due_bps_gloas": 2500,
        "aggregate_due_bps_gloas": 5000,
        "sync_message_due_bps_gloas": 2500,
        "contribution_due_bps_gloas": 5000,
        "payload_attestation_due_bps": 7500,
        "view_freeze_cutoff_bps": 7500,
        "inclusion_list_submission_due_bps": 6667,
        "proposer_inclusion_list_cutoff_bps": 9167,
        "altair_fork_epoch": 0,
        "bellatrix_fork_epoch": 0,
        "capella_fork_epoch": 0,
        "deneb_fork_epoch": 0,
        "electra_fork_epoch": 0,
        "fulu_fork_epoch": 0,
        "gloas_fork_epoch": constants.FAR_FUTURE_EPOCH,
        "eip7805_fork_epoch": constants.FAR_FUTURE_EPOCH,
        "eip7441_fork_epoch": constants.FAR_FUTURE_EPOCH,
        "network_sync_base_url": "https://snapshots.ethpandaops.io/",
        "force_snapshot_sync": False,
        "shadowfork_block_height": "latest",
        "data_column_sidecar_subnet_count": 128,
        "samples_per_slot": 8,
        "custody_requirement": 4,
        "max_blobs_per_block_electra": 9,
        "target_blobs_per_block_electra": 6,
        "max_request_blocks_deneb": 128,
        "max_request_blob_sidecars_electra": 1152,
        "base_fee_update_fraction_electra": 5007716,
        "preset": "minimal",
        "additional_preloaded_contracts": {},
        "additional_mnemonics": [],
        "devnet_repo": "ethpandaops",
        "prefunded_accounts": {},
        "max_payload_size": 10485760,
        "perfect_peerdas_enabled": False,
        "gas_limit": 0,
        "bpo_1_epoch": 0,
        "bpo_1_max_blobs": 15,
        "bpo_1_target_blobs": 10,
        "bpo_1_base_fee_update_fraction": 8346193,
        "bpo_2_epoch": 18446744073709551615,
        "bpo_2_max_blobs": 21,
        "bpo_2_target_blobs": 14,
        "bpo_2_base_fee_update_fraction": 11684671,
        "bpo_3_epoch": 18446744073709551615,
        "bpo_3_max_blobs": 0,
        "bpo_3_target_blobs": 0,
        "bpo_3_base_fee_update_fraction": 0,
        "bpo_4_epoch": 18446744073709551615,
        "bpo_4_max_blobs": 0,
        "bpo_4_target_blobs": 0,
        "bpo_4_base_fee_update_fraction": 0,
        "bpo_5_epoch": 18446744073709551615,
        "bpo_5_max_blobs": 0,
        "bpo_5_target_blobs": 0,
        "bpo_5_base_fee_update_fraction": 0,
        "withdrawal_type": "0x00",
        "withdrawal_address": "0x8943545177806ED17B9F23F0a21ee5948eCaa776",
        "validator_balance": 32,
        "min_epochs_for_data_column_sidecars_requests": 4096,
        "min_epochs_for_block_requests": 272,
    }


def default_participant():
    return {
        "el_type": "geth",
        "el_image": "",
        "el_binary_path": "",
        "el_log_level": "",
        "el_storage_type": "",
        "el_extra_env_vars": {},
        "el_extra_labels": {},
        "el_extra_params": [],
        "el_extra_mounts": {},
        "el_devices": [],
        "el_tolerations": [],
        "el_volume_size": 0,
        "el_min_cpu": 0,
        "el_max_cpu": 0,
        "el_min_mem": 0,
        "el_max_mem": 0,
        "el_force_restart": False,
        "cl_type": "lighthouse",
        "cl_image": "",
        "cl_binary_path": "",
        "cl_log_level": "",
        "cl_extra_env_vars": {},
        "cl_extra_labels": {},
        "cl_extra_params": [],
        "cl_extra_mounts": {},
        "cl_devices": [],
        "cl_tolerations": [],
        "cl_volume_size": 0,
        "cl_min_cpu": 0,
        "cl_max_cpu": 0,
        "cl_min_mem": 0,
        "cl_max_mem": 0,
        "cl_force_restart": False,
        "supernode": False,
        "use_separate_vc": None,
        "vc_type": "",
        "vc_image": "",
        "vc_binary_path": "",
        "vc_log_level": "",
        "vc_extra_env_vars": {},
        "vc_extra_labels": {},
        "vc_extra_params": [],
        "vc_extra_mounts": {},
        "vc_devices": [],
        "vc_tolerations": [],
        "vc_min_cpu": 0,
        "vc_max_cpu": 0,
        "vc_min_mem": 0,
        "vc_max_mem": 0,
        "vc_force_restart": False,
        "use_remote_signer": None,
        "remote_signer_type": "web3signer",
        "remote_signer_image": "",
        "remote_signer_extra_env_vars": {},
        "remote_signer_extra_labels": {},
        "remote_signer_extra_params": [],
        "remote_signer_tolerations": [],
        "remote_signer_min_cpu": 0,
        "remote_signer_max_cpu": 0,
        "remote_signer_min_mem": 0,
        "remote_signer_max_mem": 0,
        "validator_count": None,
        "node_selectors": {},
        "tolerations": [],
        "count": 1,
        "snooper_enabled": None,
        "ethereum_metrics_exporter_enabled": None,
        "xatu_sentry_enabled": None,
        "prometheus_config": {
            "scrape_interval": "15s",
            "labels": None,
        },
        "blobber_enabled": False,
        "blobber_extra_params": [],
        "blobber_image": "ethpandaops/blobber:latest",
        "builder_network_params": None,
        "keymanager_enabled": None,
        "vc_beacon_node_indices": None,
        "checkpoint_sync_enabled": None,
        "skip_start": False,
    }


def get_default_blockscout_params():
    return {
        "image": "ghcr.io/blockscout/blockscout:latest",
        "verif_image": "ghcr.io/blockscout/smart-contract-verifier:latest",
        "frontend_image": "ghcr.io/blockscout/frontend:latest",
        "env": {},
    }


def get_default_dora_params():
    return {
        "image": constants.DEFAULT_DORA_IMAGE,
        "env": {},
    }


def get_default_checkpointz_params():
    return {
        "image": constants.DEFAULT_CHECKPOINTZ_IMAGE,
    }


def get_default_docker_cache_params():
    return {
        "enabled": False,
        "url": "",
        "dockerhub_prefix": "/dh/",
        "github_prefix": "/gh/",
        "google_prefix": "/gcr/",
    }


def get_default_mev_params(mev_type, preset):
    mev_relay_image = constants.DEFAULT_FLASHBOTS_RELAY_IMAGE
    mev_builder_image = constants.DEFAULT_FLASHBOTS_BUILDER_IMAGE
    if preset == "minimal":
        mev_builder_cl_image = DEFAULT_CL_IMAGES_MINIMAL[constants.CL_TYPE.lighthouse]
    else:
        mev_builder_cl_image = DEFAULT_CL_IMAGES[constants.CL_TYPE.lighthouse]
    mev_builder_extra_data = None
    mev_builder_subsidy = 0
    mev_boost_image = constants.DEFAULT_FLASHBOTS_MEV_BOOST_IMAGE
    mev_boost_args = ["mev-boost", "--relay-check"]
    mev_relay_api_extra_args = []
    mev_relay_api_extra_env_vars = {}
    mev_relay_housekeeper_extra_args = []
    mev_relay_housekeeper_extra_env_vars = {}
    mev_relay_website_extra_args = []
    mev_relay_website_extra_env_vars = {}
    mev_builder_extra_args = []
    mev_builder_cl_extra_params = []
    launch_adminer = False
    mev_builder_prometheus_config = {
        "scrape_interval": "15s",
        "labels": None,
        "storage_tsdb_retention_time": "1d",
        "storage_tsdb_retention_size": "512MB",
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
    }

    if mev_type == constants.MEV_RS_MEV_TYPE:
        if preset == "minimal":
            mev_relay_image = constants.DEFAULT_MEV_RS_IMAGE_MINIMAL
            mev_builder_image = constants.DEFAULT_MEV_RS_IMAGE_MINIMAL
            mev_builder_cl_image = DEFAULT_CL_IMAGES_MINIMAL[
                constants.CL_TYPE.lighthouse
            ]
            mev_boost_image = constants.DEFAULT_MEV_RS_IMAGE_MINIMAL
        else:
            mev_relay_image = constants.DEFAULT_MEV_RS_IMAGE
            mev_builder_image = constants.DEFAULT_MEV_RS_IMAGE
            mev_builder_cl_image = DEFAULT_CL_IMAGES[constants.CL_TYPE.lighthouse]
            mev_boost_image = constants.DEFAULT_MEV_RS_IMAGE
        mev_builder_extra_data = "0x68656C6C6F20776F726C640A"  # "hello world\n"
        mev_builder_extra_args = ["--mev-builder-config=" + "/config/config.toml"]

    if mev_type == constants.COMMIT_BOOST_MEV_TYPE:
        mev_relay_image = constants.DEFAULT_FLASHBOTS_RELAY_IMAGE
        mev_builder_image = constants.DEFAULT_FLASHBOTS_BUILDER_IMAGE
        mev_boost_image = constants.DEFAULT_COMMIT_BOOST_MEV_BOOST_IMAGE
        mev_builder_cl_image = DEFAULT_CL_IMAGES[constants.CL_TYPE.lighthouse]
        mev_builder_extra_data = (
            "0x436F6D6D69742D426F6F737420F09F93BB"  # Commit-Boost 📻
        )

    if mev_type == constants.MOCK_MEV_TYPE:
        mev_builder_image = constants.DEFAULT_MOCK_MEV_IMAGE
        mev_boost_image = constants.DEFAULT_FLASHBOTS_MEV_BOOST_IMAGE

    if mev_type == constants.HELIX_MEV_TYPE:
        mev_relay_image = constants.DEFAULT_HELIX_RELAY_IMAGE
        mev_builder_image = constants.DEFAULT_FLASHBOTS_BUILDER_IMAGE
        mev_boost_image = constants.DEFAULT_FLASHBOTS_MEV_BOOST_IMAGE
        mev_builder_cl_image = DEFAULT_CL_IMAGES[constants.CL_TYPE.lighthouse]
        mev_builder_extra_data = "0x48656C6978"  # "Helix" in hex

    return {
        "mev_relay_image": mev_relay_image,
        "mev_builder_image": mev_builder_image,
        "mock_mev_image": mev_builder_image
        if mev_type == constants.MOCK_MEV_TYPE
        else None,
        "mev_builder_subsidy": mev_builder_subsidy,
        "mev_builder_cl_image": mev_builder_cl_image,
        "mev_builder_extra_data": mev_builder_extra_data,
        "mev_builder_extra_args": mev_builder_extra_args,
        "mev_builder_cl_extra_params": mev_builder_cl_extra_params,
        "mev_boost_image": mev_boost_image,
        "mev_boost_args": mev_boost_args,
        "mev_relay_api_extra_args": mev_relay_api_extra_args,
        "mev_relay_api_extra_env_vars": mev_relay_api_extra_env_vars,
        "mev_relay_housekeeper_extra_args": mev_relay_housekeeper_extra_args,
        "mev_relay_housekeeper_extra_env_vars": mev_relay_housekeeper_extra_env_vars,
        "mev_relay_website_extra_args": mev_relay_website_extra_args,
        "mev_relay_website_extra_env_vars": mev_relay_website_extra_env_vars,
        "mev_builder_prometheus_config": mev_builder_prometheus_config,
        "launch_adminer": launch_adminer,
        "run_multiple_relays": False,
        "helix_relay_image": constants.DEFAULT_HELIX_RELAY_IMAGE,
    }


def get_default_tx_fuzz_params():
    return {
        "image": "ethpandaops/tx-fuzz:master",
        "tx_fuzz_extra_args": [],
    }


def get_default_rakoon_params():
    return {
        "image": "ethpandaops/fuzztools:main",
        "tx_type": "eip7702",
        "workers": 50,
        "batch_size": 100,
        "seed": "",
        "fuzzing": True,
        "poll_interval": "",
        "extra_args": [],
    }


def get_default_assertoor_params():
    return {
        "image": constants.DEFAULT_ASSERTOOR_IMAGE,
        "run_stability_check": False,
        "run_block_proposal_check": False,
        "run_lifecycle_test": False,
        "run_transaction_test": False,
        "run_blob_transaction_test": False,
        "run_opcodes_transaction_test": False,
        "tests": [],
    }


def get_default_prometheus_params():
    return {
        "storage_tsdb_retention_time": "1d",
        "storage_tsdb_retention_size": "512MB",
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
        "image": "prom/prometheus:v3.2.1",
    }


def get_default_grafana_params():
    return {
        "additional_dashboards": [],
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
        "image": "grafana/grafana:latest",
    }


def get_default_tempo_params():
    return {
        "retention_duration": "12h",
        "ingestion_rate_limit": 20971520,  # 20MB
        "ingestion_burst_limit": 52428800,  # 50MB
        "max_search_duration": "30s",
        "max_bytes_per_trace": 52428800,  # 50MB
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
        "image": "grafana/tempo:latest",
    }


def get_default_xatu_sentry_params():
    return {
        "xatu_sentry_image": "ethpandaops/xatu:latest",
        "xatu_server_addr": "localhost:8080",
        "xatu_server_headers": {},
        "xatu_server_tls": False,
        "beacon_subscriptions": [
            "attestation",
            "single_attestation",
            "block",
            "block_gossip",
            "chain_reorg",
            "finalized_checkpoint",
            "head",
            "voluntary_exit",
            "contribution_and_proof",
            "blob_sidecar",
            "data_column_sidecar",
        ],
    }


def get_default_spamoor_params():
    return {
        "image": constants.DEFAULT_SPAMOOR_IMAGE,
        "min_cpu": 100,
        "max_cpu": 2000,
        "min_mem": 100,
        "max_mem": 800,
        "extra_args": [],
        "spammers": [
            # default spammers
            {
                "name": "EOA Spammer (Kurtosis Package)",
                "description": "200 type-2 eoa transactions per slot, gas limit 20 gwei",
                "scenario": "eoatx",
                "config": {
                    "throughput": 200,
                    "max_pending": 400,
                    "max_wallets": 200,
                    "base_fee": 20,
                },
            },
            {
                "name": "Blob Spammer (Kurtosis Package)",
                "description": "3 type-4 blob transactions per slot with 1-2 sidecars each, gas/blobgas limit 20 gwei",
                "scenario": "blob-combined",
                "config": {
                    "throughput": 3,
                    "sidecars": 2,
                    "max_pending": 6,
                    "max_wallets": 20,
                    "base_fee": 20,
                    "blob_fee": 20,
                },
            },
        ],
    }


def get_default_slashoor_params():
    return {
        "image": constants.DEFAULT_SLASHOOR_IMAGE,
        "min_cpu": 100,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 512,
        "extra_args": [],
        "log_level": "info",
        "beacon_timeout": "30s",
        "max_epochs_to_keep": 54000,
        "detector_enabled": True,
        "proposer_enabled": True,
        "submitter_enabled": True,
        "submitter_dry_run": False,
        "dora_enabled": True,
        "dora_url": "",
        "dora_scan_on_startup": True,
        "backfill_slots": 64,
    }


def get_default_custom_flood_params():
    # this is a simple script that increases the balance of the coinbase address at a cadence
    return {"interval_between_transactions": 1}


def get_default_mempool_bridge_params():
    return {
        "image": "ethpandaops/mempool-bridge:latest",
        "source_enodes": [],
        "mode": "p2p",
        "log_level": "",
        "send_concurrency": 10,
        "polling_interval": "10s",
        "retry_interval": "30s",
    }


def get_default_bootnodoor_params():
    return {
        "image": constants.DEFAULT_BOOTNODOOR_IMAGE,
        "min_cpu": 100,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 512,
        "extra_args": [],
    }


def get_default_ews_params():
    return {
        "image": constants.DEFAULT_EWS_IMAGE,
        "retain": 10,
        "num_proofs": 1,
        "env": {},
    }


def get_default_buildoor_params():
    return {
        "image": constants.DEFAULT_BUILDOOR_IMAGE,
        "extra_args": [],
        "builder_api": True,
        "epbs_builder": True,
    }


def get_port_publisher_params(parameter_type, input_args=None):
    port_publisher_parameters = {
        "nat_exit_ip": "KURTOSIS_IP_ADDR_PLACEHOLDER",
        "el": {
            "enabled": False,
            "public_port_start": 32000,
            "nat_exit_ip": "KURTOSIS_IP_ADDR_PLACEHOLDER",
        },
        "cl": {
            "enabled": False,
            "public_port_start": 33000,
            "nat_exit_ip": "KURTOSIS_IP_ADDR_PLACEHOLDER",
        },
        "vc": {
            "enabled": False,
            "public_port_start": 34000,
            "nat_exit_ip": "KURTOSIS_IP_ADDR_PLACEHOLDER",
        },
        "remote_signer": {
            "enabled": False,
            "public_port_start": 35000,
            "nat_exit_ip": "KURTOSIS_IP_ADDR_PLACEHOLDER",
        },
        "additional_services": {
            "enabled": False,
            "public_port_start": 36000,
            "nat_exit_ip": "KURTOSIS_IP_ADDR_PLACEHOLDER",
        },
        "mev": {
            "enabled": False,
            "public_port_start": 37000,
            "nat_exit_ip": "KURTOSIS_IP_ADDR_PLACEHOLDER",
        },
        "other": {
            "enabled": False,
            "public_port_start": 38000,
            "nat_exit_ip": "KURTOSIS_IP_ADDR_PLACEHOLDER",
        },
    }
    if parameter_type == "default":
        return port_publisher_parameters
    else:
        for setting in input_args["port_publisher"]:
            if setting == "nat_exit_ip":
                # Handle global nat_exit_ip setting
                nat_exit_ip_value = input_args["port_publisher"][setting]
                port_publisher_parameters[setting] = nat_exit_ip_value
            else:
                # Handle service group settings
                for sub_setting in input_args["port_publisher"][setting]:
                    sub_setting_value = input_args["port_publisher"][setting][
                        sub_setting
                    ]
                    port_publisher_parameters[setting][sub_setting] = sub_setting_value
        return port_publisher_parameters


def enrich_disable_peer_scoring(parsed_arguments_dict):
    for index, participant in enumerate(parsed_arguments_dict["participants"]):
        if participant["cl_type"] == "lighthouse":
            participant["cl_extra_params"].append("--disable-peer-scoring")
        if participant["cl_type"] == "prysm":
            participant["cl_extra_params"].append("--disable-peer-scorer")
        if participant["cl_type"] == "teku":
            participant["cl_extra_params"].append("--Xp2p-gossip-scoring-enabled")
        if participant["cl_type"] == "lodestar":
            participant["cl_extra_params"].append("--disablePeerScoring")
        if participant["cl_type"] == "grandine":
            participant["cl_extra_params"].append("--disable-peer-scoring")
    return parsed_arguments_dict


# TODO perhaps clean this up into a map
def enrich_mev_extra_params(parsed_arguments_dict, mev_prefix, mev_port, mev_type):
    for index, participant in enumerate(parsed_arguments_dict["participants"]):
        index_str = shared_utils.zfill_custom(
            index + 1, len(str(len(parsed_arguments_dict["participants"])))
        )

        if mev_type == constants.COMMIT_BOOST_MEV_TYPE:
            prefix = constants.COMMIT_BOOST_SERVICE_NAME_PREFIX
        else:
            prefix = constants.MEV_BOOST_SERVICE_NAME_PREFIX

        mev_url = "http://{0}-{1}-{2}-{3}:{4}".format(
            prefix,
            index_str,
            participant["cl_type"],
            participant["el_type"],
            mev_port,
        )

        if participant["cl_type"] == "lighthouse":
            participant["cl_extra_params"].append("--builder={0}".format(mev_url))
        if participant["vc_type"] == "lighthouse":
            if (
                parsed_arguments_dict["network_params"]["gas_limit"] == 0
            ):  # if the gas limit is set we already enable builder-proposals
                participant["vc_extra_params"].append("--builder-proposals")
        if participant["cl_type"] == "lodestar":
            participant["cl_extra_params"].append("--builder")
            participant["cl_extra_params"].append("--builder.urls={0}".format(mev_url))
        if participant["vc_type"] == "lodestar":
            participant["vc_extra_params"].append("--builder")
        if participant["cl_type"] == "nimbus":
            participant["cl_extra_params"].append("--payload-builder=true")
            participant["cl_extra_params"].append(
                "--payload-builder-url={0}".format(mev_url)
            )
        if participant["vc_type"] == "nimbus":
            participant["vc_extra_params"].append("--payload-builder=true")
        if participant["cl_type"] == "teku":
            participant["cl_extra_params"].append(
                "--builder-endpoint={0}".format(mev_url)
            )
            participant["cl_extra_params"].append(
                "--validators-builder-registration-default-enabled=true"
            )
        if participant["vc_type"] == "teku":
            participant["vc_extra_params"].append(
                "--validators-builder-registration-default-enabled=true"
            )
        if participant["cl_type"] == "prysm":
            participant["cl_extra_params"].append(
                "--http-mev-relay={0}".format(mev_url)
            )
        if participant["vc_type"] == "prysm":
            participant["vc_extra_params"].append("--enable-builder")
        if participant["cl_type"] == "grandine":
            participant["cl_extra_params"].append("--builder-url={0}".format(mev_url))

        if participant["vc_type"] == "vero":
            participant["vc_extra_params"].append("--use-external-builder")

    num_participants = len(parsed_arguments_dict["participants"])
    index_str = shared_utils.zfill_custom(
        num_participants + 1, len(str(num_participants + 1))
    )
    if (
        mev_type == constants.FLASHBOTS_MEV_TYPE
        or mev_type == constants.COMMIT_BOOST_MEV_TYPE
        or mev_type == constants.HELIX_MEV_TYPE
    ):
        mev_participant = default_participant()
        mev_participant["el_type"] = "reth-builder"
        mev_participant.update(
            {
                "el_image": parsed_arguments_dict["mev_params"]["mev_builder_image"],
                "cl_image": parsed_arguments_dict["mev_params"]["mev_builder_cl_image"],
                "cl_log_level": parsed_arguments_dict["global_log_level"],
                "cl_extra_params": [
                    "--always-prepare-payload",
                    "--prepare-payload-lookahead",
                    "8000",
                    "--disable-peer-scoring",
                    "--supernode",
                ]
                + parsed_arguments_dict["mev_params"]["mev_builder_cl_extra_params"],
                "el_extra_params": parsed_arguments_dict["mev_params"][
                    "mev_builder_extra_args"
                ],
                "validator_count": 0,
                "prometheus_config": parsed_arguments_dict["mev_params"][
                    "mev_builder_prometheus_config"
                ],
            }
        )

        parsed_arguments_dict["participants"].append(mev_participant)

    if mev_type == constants.MEV_RS_MEV_TYPE:
        mev_participant = default_participant()
        mev_participant["el_type"] = "reth-builder"
        mev_participant.update(
            {
                "el_image": parsed_arguments_dict["mev_params"]["mev_builder_image"],
                "cl_image": parsed_arguments_dict["mev_params"]["mev_builder_cl_image"],
                "cl_log_level": parsed_arguments_dict["global_log_level"],
                "cl_extra_params": [
                    "--always-prepare-payload",
                    "--prepare-payload-lookahead",
                    "8000",
                    "--disable-peer-scoring",
                ]
                + parsed_arguments_dict["mev_params"]["mev_builder_cl_extra_params"],
                "el_extra_params": parsed_arguments_dict["mev_params"][
                    "mev_builder_extra_args"
                ],
                "validator_count": 0,
            }
        )
        parsed_arguments_dict["participants"].append(mev_participant)
    if mev_type == constants.MOCK_MEV_TYPE:
        parsed_arguments_dict["mev_params"]["mock_mev_image"] = parsed_arguments_dict[
            "mev_params"
        ]["mock_mev_image"]
    return parsed_arguments_dict


def deep_copy_participant(participant):
    part = {}
    for k, v in participant.items():
        if type(v) == type([]):
            part[k] = list(v)
        else:
            part[k] = v
    return part


def get_public_ip(plan, global_tolerations=[], global_node_selectors={}):
    response = plan.run_sh(
        name="get-public-ip",
        description="Get the public IP address of the current machine",
        run="curl -s https://ident.me",
        tolerations=shared_utils.get_tolerations(global_tolerations=global_tolerations),
        node_selectors=global_node_selectors,
    )
    return response.output


def docker_cache_image_override(plan, result):
    plan.print("Docker cache is enabled, overriding image urls")
    participant_overridable_image = [
        "el_image",
        "cl_image",
        "vc_image",
        "remote_signer_image",
        "blobber_image",
    ]
    tooling_overridable_image = [
        "dora_params.image",
        "assertoor_params.image",
        "mev_params.mev_relay_image",
        "mev_params.mev_builder_image",
        "mev_params.mev_builder_cl_image",
        "mev_params.mev_boost_image",
        "mev_params.mock_mev_image",
        "xatu_sentry_params.xatu_sentry_image",
        "tx_fuzz_params.image",
        "rakoon_params.image",
        "prometheus_params.image",
        "grafana_params.image",
        "tempo_params.image",
        "spamoor_params.image",
        "ethereum_genesis_generator_params.image",
    ]

    if result["docker_cache_params"]["url"] == "":
        fail(
            "docker_cache_params.url is empty or spaces, please provide a valid docker cache url, or disable the docker cache"
        )
    for index, participant in enumerate(result["participants"]):
        for images in participant_overridable_image:
            if result["docker_cache_params"]["url"] in participant[images]:
                break
            elif constants.CONTAINER_REGISTRY.ghcr in participant[images]:
                participant[images] = (
                    result["docker_cache_params"]["url"]
                    + result["docker_cache_params"]["github_prefix"]
                    + "/".join(participant[images].split("/")[1:])
                )
            elif constants.CONTAINER_REGISTRY.gcr in participant[images]:
                participant[images] = (
                    result["docker_cache_params"]["url"]
                    + result["docker_cache_params"]["google_prefix"]
                    + "/".join(participant[images].split("/")[1:])
                )
            elif participant[images].startswith("ethpandaops/"):
                # Handle ethpandaops images (including devnet-modified ones)
                participant[images] = (
                    result["docker_cache_params"]["url"]
                    + result["docker_cache_params"]["dockerhub_prefix"]
                    + participant[images]
                )
            elif constants.CONTAINER_REGISTRY.dockerhub in participant[images]:
                participant[images] = (
                    result["docker_cache_params"]["url"]
                    + result["docker_cache_params"]["dockerhub_prefix"]
                    + participant[images]
                )
            else:
                plan.print(
                    "Using local client image instead of docker cache for {0} for participant {1}".format(
                        images, index + 1
                    )
                )

    for tooling_image_key in tooling_overridable_image:
        image_parts = tooling_image_key.split(".")
        if (
            result[image_parts[0]][image_parts[1]] != None
            and result["docker_cache_params"]["url"]
            in result[image_parts[0]][image_parts[1]]
        ):
            break
        elif (
            result[image_parts[0]][image_parts[1]] != None
            and constants.CONTAINER_REGISTRY.ghcr
            in result[image_parts[0]][image_parts[1]]
        ):
            result[image_parts[0]][image_parts[1]] = (
                result["docker_cache_params"]["url"]
                + result["docker_cache_params"]["github_prefix"]
                + "/".join(result[image_parts[0]][image_parts[1]].split("/")[1:])
            )
        elif (
            result[image_parts[0]][image_parts[1]] != None
            and constants.CONTAINER_REGISTRY.gcr
            in result[image_parts[0]][image_parts[1]]
        ):
            result[image_parts[0]][image_parts[1]] = (
                result["docker_cache_params"]["url"]
                + result["docker_cache_params"]["google_prefix"]
                + "/".join(result[image_parts[0]][image_parts[1]].split("/")[1:])
            )
        elif (
            result[image_parts[0]][image_parts[1]] != None
            and constants.CONTAINER_REGISTRY.dockerhub
            in result[image_parts[0]][image_parts[1]]
        ):
            result[image_parts[0]][image_parts[1]] = (
                result["docker_cache_params"]["url"]
                + result["docker_cache_params"]["dockerhub_prefix"]
                + result[image_parts[0]][image_parts[1]]
            )
        else:
            plan.print(
                "Using local tooling image instead of docker cache for {0}".format(
                    tooling_image_key
                )
            )


def get_default_ethereum_genesis_generator_params():
    return {
        "image": constants.DEFAULT_ETHEREUM_GENESIS_GENERATOR_IMAGE,
        "extra_env": {},
    }


def get_devnet_image_tag(network_name, original_image):
    if "devnet" not in network_name:
        return original_image

    # For devnet networks, convert all client images to ethpandaops
    if "/" in original_image:
        # Extract just the image name (everything after the last /)
        image_name_with_tag = original_image.split("/")[-1]
        if ":" in image_name_with_tag:
            image_name = image_name_with_tag.split(":")[0]
        else:
            image_name = image_name_with_tag

        # Special case: ethereum/client-go should become ethpandaops/geth
        if image_name == "client-go":
            image_name = "geth"
        # Special case: gcr.io/offchainlabs/prysm/beacon-chain should become ethpandaops/prysm-beacon-chain
        elif image_name == "beacon-chain" and "prysm" in original_image:
            image_name = "prysm-beacon-chain"
        # Special case: gcr.io/offchainlabs/prysm/validator should become ethpandaops/prysm-validator
        elif image_name == "validator" and "prysm" in original_image:
            image_name = "prysm-validator"

        return "ethpandaops/{0}:{1}".format(image_name, network_name)
    else:
        # Handle edge case where there's no registry prefix
        if ":" in original_image:
            image_name = original_image.split(":")[0]
        else:
            image_name = original_image
        return "ethpandaops/{0}:{1}".format(image_name, network_name)


DEVNET_EXCLUDED_CLIENTS = {
    "teku": "ethpandaops/teku:master",
    "besu": "ethpandaops/besu:main",
}


def get_devnet_modified_images(network_name, default_images):
    if "devnet" not in network_name:
        return default_images

    modified_images = {}
    for client_type, image in default_images.items():
        if client_type in DEVNET_EXCLUDED_CLIENTS:
            modified_images[client_type] = DEVNET_EXCLUDED_CLIENTS[client_type]
        else:
            modified_images[client_type] = get_devnet_image_tag(network_name, image)

    return modified_images
