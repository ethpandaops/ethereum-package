constants = import_module("./constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
genesis_constants = import_module(
    "../prelaunch_data_generator/genesis_constants/genesis_constants.star"
)

sanity_check = import_module("./sanity_check.star")

DEFAULT_EL_IMAGES = {
    "geth": "ethereum/client-go:latest",
    "erigon": "ethpandaops/erigon:main",
    "nethermind": "nethermindeth/nethermind:master",
    "besu": "ethpandaops/besu:main",
    "reth": "ghcr.io/paradigmxyz/reth",
    "ethereumjs": "ethpandaops/ethereumjs:master",
    "nimbus": "ethpandaops/nimbus-eth1:master",
}

DEFAULT_CL_IMAGES = {
    "lighthouse": "ethpandaops/lighthouse:stable",
    "teku": "consensys/teku:latest",
    "nimbus": "statusim/nimbus-eth2:multiarch-latest",
    "prysm": "gcr.io/prysmaticlabs/prysm/beacon-chain:latest",
    "lodestar": "chainsafe/lodestar:latest",
    "grandine": "sifrai/grandine:stable",
}

DEFAULT_CL_IMAGES_MINIMAL = {
    "lighthouse": "ethpandaops/lighthouse:stable",
    "teku": "consensys/teku:latest",
    "nimbus": "ethpandaops/nimbus-eth2:stable-minimal",
    "prysm": "ethpandaops/prysm-beacon-chain:develop-minimal",
    "lodestar": "chainsafe/lodestar:latest",
    "grandine": "ethpandaops/grandine:master-minimal",
}

DEFAULT_VC_IMAGES = {
    "lighthouse": "ethpandaops/lighthouse:stable",
    "lodestar": "chainsafe/lodestar:latest",
    "nimbus": "statusim/nimbus-validator-client:multiarch-latest",
    "prysm": "gcr.io/prysmaticlabs/prysm/validator:latest",
    "teku": "consensys/teku:latest",
    "grandine": "sifrai/grandine:stable",
}

DEFAULT_VC_IMAGES_MINIMAL = {
    "lighthouse": "ethpandaops/lighthouse:stable",
    "lodestar": "chainsafe/lodestar:latest",
    "nimbus": "ethpandaops/nimbus-validator-client:stable-minimal",
    "prysm": "ethpandaops/prysm-validator:develop-minimal",
    "teku": "consensys/teku:latest",
    "grandine": "ethpandaops/grandine:master-minimal",
}

# Placeholder value for the deneb fork epoch if electra is being run
# TODO: This is a hack, and should be removed once we electra is rebased on deneb
HIGH_DENEB_VALUE_FORK_VERKLE = 2000000000

# MEV Params
MEV_BOOST_PORT = 18550
MEV_BOOST_SERVICE_NAME_PREFIX = "mev-boost"

# Minimum number of validators required for a network to be valid is 64
MIN_VALIDATORS = 64

DEFAULT_ADDITIONAL_SERVICES = []

ATTR_TO_BE_SKIPPED_AT_ROOT = (
    "network_params",
    "participants",
    "mev_params",
    "dora_params",
    "assertoor_params",
    "goomy_blob_params",
    "tx_spammer_params",
    "custom_flood_params",
    "xatu_sentry_params",
    "port_publisher",
)


def input_parser(plan, input_args):
    sanity_check.sanity_check(plan, input_args)
    result = parse_network_params(plan, input_args)

    # add default eth2 input params
    result["dora_params"] = get_default_dora_params()
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
    result["grafana_additional_dashboards"] = []
    result["tx_spammer_params"] = get_default_tx_spammer_params()
    result["custom_flood_params"] = get_default_custom_flood_params()
    result["disable_peer_scoring"] = False
    result["goomy_blob_params"] = get_default_goomy_blob_params()
    result["assertoor_params"] = get_default_assertoor_params()
    result["prometheus_params"] = get_default_prometheus_params()
    result["xatu_sentry_params"] = get_default_xatu_sentry_params()
    result["persistent"] = False
    result["parallel_keystore_generation"] = False
    result["global_tolerations"] = []
    result["global_node_selectors"] = {}
    result["port_publisher"] = get_port_publisher_params("default")

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
        elif attr == "dora_params":
            for sub_attr in input_args["dora_params"]:
                sub_value = input_args["dora_params"][sub_attr]
                result["dora_params"][sub_attr] = sub_value
        elif attr == "mev_params":
            for sub_attr in input_args["mev_params"]:
                sub_value = input_args["mev_params"][sub_attr]
                result["mev_params"][sub_attr] = sub_value
        elif attr == "tx_spammer_params":
            for sub_attr in input_args["tx_spammer_params"]:
                sub_value = input_args["tx_spammer_params"][sub_attr]
                result["tx_spammer_params"][sub_attr] = sub_value
        elif attr == "custom_flood_params":
            for sub_attr in input_args["custom_flood_params"]:
                sub_value = input_args["custom_flood_params"][sub_attr]
                result["custom_flood_params"][sub_attr] = sub_value
        elif attr == "goomy_blob_params":
            for sub_attr in input_args["goomy_blob_params"]:
                sub_value = input_args["goomy_blob_params"][sub_attr]
                result["goomy_blob_params"][sub_attr] = sub_value
        elif attr == "assertoor_params":
            for sub_attr in input_args["assertoor_params"]:
                sub_value = input_args["assertoor_params"][sub_attr]
                result["assertoor_params"][sub_attr] = sub_value
        elif attr == "xatu_sentry_params":
            for sub_attr in input_args["xatu_sentry_params"]:
                sub_value = input_args["xatu_sentry_params"][sub_attr]
                result["xatu_sentry_params"][sub_attr] = sub_value
        elif attr == "port_publisher":
            result["port_publisher"] = get_port_publisher_params("user", input_args)

    if result.get("disable_peer_scoring"):
        result = enrich_disable_peer_scoring(result)

    if result.get("mev_type") in (
        constants.MOCK_MEV_TYPE,
        constants.FLASHBOTS_MEV_TYPE,
        constants.MEV_RS_MEV_TYPE,
    ):
        result = enrich_mev_extra_params(
            result,
            MEV_BOOST_SERVICE_NAME_PREFIX,
            MEV_BOOST_PORT,
            result.get("mev_type"),
        )
    elif result.get("mev_type") == None:
        pass
    else:
        fail(
            "Unsupported MEV type: {0}, please use 'mock', 'flashbots' or 'mev-rs' type".format(
                result.get("mev_type")
            )
        )

    if result["port_publisher"]["nat_exit_ip"] == "auto":
        result["port_publisher"]["nat_exit_ip"] = get_public_ip(plan)

    return struct(
        participants=[
            struct(
                el_type=participant["el_type"],
                el_image=participant["el_image"],
                el_log_level=participant["el_log_level"],
                el_volume_size=participant["el_volume_size"],
                el_extra_params=participant["el_extra_params"],
                el_extra_env_vars=participant["el_extra_env_vars"],
                el_extra_labels=participant["el_extra_labels"],
                el_tolerations=participant["el_tolerations"],
                cl_type=participant["cl_type"],
                cl_image=participant["cl_image"],
                cl_log_level=participant["cl_log_level"],
                cl_volume_size=participant["cl_volume_size"],
                cl_extra_env_vars=participant["cl_extra_env_vars"],
                cl_tolerations=participant["cl_tolerations"],
                use_separate_vc=participant["use_separate_vc"],
                vc_type=participant["vc_type"],
                vc_image=participant["vc_image"],
                vc_log_level=participant["vc_log_level"],
                vc_count=participant["vc_count"],
                vc_tolerations=participant["vc_tolerations"],
                cl_extra_params=participant["cl_extra_params"],
                cl_extra_labels=participant["cl_extra_labels"],
                vc_extra_params=participant["vc_extra_params"],
                vc_extra_env_vars=participant["vc_extra_env_vars"],
                vc_extra_labels=participant["vc_extra_labels"],
                builder_network_params=participant["builder_network_params"],
                el_min_cpu=participant["el_min_cpu"],
                el_max_cpu=participant["el_max_cpu"],
                el_min_mem=participant["el_min_mem"],
                el_max_mem=participant["el_max_mem"],
                cl_min_cpu=participant["cl_min_cpu"],
                cl_max_cpu=participant["cl_max_cpu"],
                cl_min_mem=participant["cl_min_mem"],
                cl_max_mem=participant["cl_max_mem"],
                vc_min_cpu=participant["vc_min_cpu"],
                vc_max_cpu=participant["vc_max_cpu"],
                vc_min_mem=participant["vc_min_mem"],
                vc_max_mem=participant["vc_max_mem"],
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
                keymanager_enabled=participant["keymanager_enabled"],
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
            genesis_delay=result["network_params"]["genesis_delay"],
            genesis_gaslimit=result["network_params"]["genesis_gaslimit"],
            max_per_epoch_activation_churn_limit=result["network_params"][
                "max_per_epoch_activation_churn_limit"
            ],
            churn_limit_quotient=result["network_params"]["churn_limit_quotient"],
            ejection_balance=result["network_params"]["ejection_balance"],
            eth1_follow_distance=result["network_params"]["eth1_follow_distance"],
            deneb_fork_epoch=result["network_params"]["deneb_fork_epoch"],
            electra_fork_epoch=result["network_params"]["electra_fork_epoch"],
            eip7594_fork_epoch=result["network_params"]["eip7594_fork_epoch"],
            eip7594_fork_version=result["network_params"]["eip7594_fork_version"],
            eof_activation_epoch=result["network_params"]["eof_activation_epoch"],
            network=result["network_params"]["network"],
            min_validator_withdrawability_delay=result["network_params"][
                "min_validator_withdrawability_delay"
            ],
            shard_committee_period=result["network_params"]["shard_committee_period"],
            network_sync_base_url=result["network_params"]["network_sync_base_url"],
            data_column_sidecar_subnet_count=result["network_params"][
                "data_column_sidecar_subnet_count"
            ],
            samples_per_slot=result["network_params"]["samples_per_slot"],
            custody_requirement=result["network_params"]["custody_requirement"],
            max_blobs_per_block=result["network_params"]["max_blobs_per_block"],
            preset=result["network_params"]["preset"],
            additional_preloaded_contracts=result["network_params"][
                "additional_preloaded_contracts"
            ],
            devnet_repo=result["network_params"]["devnet_repo"],
            prefunded_accounts=result["network_params"]["prefunded_accounts"],
        ),
        mev_params=struct(
            mev_relay_image=result["mev_params"]["mev_relay_image"],
            mev_builder_image=result["mev_params"]["mev_builder_image"],
            mev_builder_cl_image=result["mev_params"]["mev_builder_cl_image"],
            mev_builder_extra_data=result["mev_params"]["mev_builder_extra_data"],
            mev_boost_image=result["mev_params"]["mev_boost_image"],
            mev_boost_args=result["mev_params"]["mev_boost_args"],
            mev_relay_api_extra_args=result["mev_params"]["mev_relay_api_extra_args"],
            mev_relay_housekeeper_extra_args=result["mev_params"][
                "mev_relay_housekeeper_extra_args"
            ],
            mev_relay_website_extra_args=result["mev_params"][
                "mev_relay_website_extra_args"
            ],
            mev_builder_extra_args=result["mev_params"]["mev_builder_extra_args"],
            mev_flood_image=result["mev_params"]["mev_flood_image"],
            mev_flood_extra_args=result["mev_params"]["mev_flood_extra_args"],
            mev_flood_seconds_per_bundle=result["mev_params"][
                "mev_flood_seconds_per_bundle"
            ],
        )
        if result["mev_params"]
        else None,
        dora_params=struct(
            image=result["dora_params"]["image"],
            env=result["dora_params"]["env"],
        ),
        tx_spammer_params=struct(
            tx_spammer_extra_args=result["tx_spammer_params"]["tx_spammer_extra_args"],
        ),
        goomy_blob_params=struct(
            goomy_blob_args=result["goomy_blob_params"]["goomy_blob_args"],
        ),
        prometheus_params=struct(
            storage_tsdb_retention_time=result["prometheus_params"][
                "storage_tsdb_retention_time"
            ],
            storage_tsdb_retention_size=result["prometheus_params"][
                "storage_tsdb_retention_size"
            ],
        ),
        apache_port=result["apache_port"],
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
        additional_services=result["additional_services"],
        wait_for_finalization=result["wait_for_finalization"],
        global_log_level=result["global_log_level"],
        mev_type=result["mev_type"],
        snooper_enabled=result["snooper_enabled"],
        ethereum_metrics_exporter_enabled=result["ethereum_metrics_exporter_enabled"],
        xatu_sentry_enabled=result["xatu_sentry_enabled"],
        parallel_keystore_generation=result["parallel_keystore_generation"],
        grafana_additional_dashboards=result["grafana_additional_dashboards"],
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
        checkpoint_sync_enabled=result["checkpoint_sync_enabled"],
        checkpoint_sync_url=result["checkpoint_sync_url"],
        port_publisher=struct(
            nat_exit_ip=result["port_publisher"]["nat_exit_ip"],
            cl_enabled=result["port_publisher"]["cl"]["enabled"],
            cl_public_port_start=result["port_publisher"]["cl"]["public_port_start"],
            el_enabled=result["port_publisher"]["el"]["enabled"],
            el_public_port_start=result["port_publisher"]["el"]["public_port_start"],
            vc_enabled=result["port_publisher"]["vc"]["enabled"],
            vc_public_port_start=result["port_publisher"]["vc"]["public_port_start"],
            additional_services_enabled=result["port_publisher"]["additional_services"][
                "enabled"
            ],
            additional_services_public_port_start=result["port_publisher"][
                "additional_services"
            ]["public_port_start"],
        ),
    )


def parse_network_params(plan, input_args):
    result = default_input_args(input_args)
    if input_args.get("network_params", {}).get("preset") == "minimal":
        result["network_params"] = default_minimal_network_params()

    # Ensure we handle matrix participants before standard participants are handled.
    if "participants_matrix" in input_args:
        participants_matrix = []
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
        # if its insterted we use the value inserted
        if attr not in ATTR_TO_BE_SKIPPED_AT_ROOT and attr in input_args:
            result[attr] = value
        elif attr == "network_params":
            for sub_attr in input_args["network_params"]:
                sub_value = input_args["network_params"][sub_attr]
                result["network_params"][sub_attr] = sub_value
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
            default_image = DEFAULT_EL_IMAGES.get(el_type, "")
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
                default_image = DEFAULT_CL_IMAGES_MINIMAL.get(cl_type, "")
            else:
                default_image = DEFAULT_CL_IMAGES.get(cl_type, "")
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

        if vc_type == "":
            # Defaults to matching the chosen CL client
            vc_type = cl_type
            participant["vc_type"] = vc_type

        vc_image = participant["vc_image"]
        if vc_image == "":
            if cl_image == "" or vc_type != cl_type:
                # If the validator client image is also empty, default to the image for the chosen CL client
                if result["network_params"]["preset"] == "minimal":
                    default_image = DEFAULT_VC_IMAGES_MINIMAL.get(vc_type, "")
                else:
                    default_image = DEFAULT_VC_IMAGES.get(vc_type, "")
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

        if result["parallel_keystore_generation"] and participant["vc_count"] != 1:
            fail(
                "parallel_keystore_generation is only supported for 1 validator client per participant (for now)"
            )

        # If the num validator keys per node is not divisible by vc_count of a participant, fail
        if (
            participant["vc_count"] > 0
            and result["network_params"]["num_validator_keys_per_node"]
            % participant["vc_count"]
            != 0
        ):
            fail(
                "num_validator_keys_per_node: {0} is not divisible by vc_count: {1} for participant: {2}".format(
                    result["network_params"]["num_validator_keys_per_node"],
                    participant["vc_count"],
                    str(index + 1)
                    + "-"
                    + participant["el_type"]
                    + "-"
                    + participant["cl_type"],
                )
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
            # unless we are running lighthouse, we don't support blobber
            if participant["cl_type"] != constants.CL_TYPE.lighthouse:
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

    if (
        result["network_params"]["network"] == constants.NETWORK_NAME.kurtosis
        or constants.NETWORK_NAME.shadowfork in result["network_params"]["network"]
    ):
        if MIN_VALIDATORS > actual_num_validators:
            fail(
                "We require at least {0} validators but got {1}".format(
                    MIN_VALIDATORS, actual_num_validators
                )
            )
    else:
        # Don't allow validators on non-kurtosis networks
        for participant in result["participants"]:
            participant["validator_count"] = 0

    if result["network_params"]["preset"] not in ["mainnet", "minimal"]:
        fail(
            "preset "
            + result["network_params"]["preset"]
            + " is not supported, it can only be mainnet or minimal"
        )

    if result["network_params"]["preset"] == "minimal":
        if result["network_params"]["deneb_fork_epoch"] > 0:
            fail("minimal preset only supports deneb genesis fork epoch")

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


def get_client_tolerations(
    specific_container_toleration, participant_tolerations, global_tolerations
):
    toleration_list = []
    tolerations = []
    tolerations = specific_container_toleration if specific_container_toleration else []
    if not tolerations:
        tolerations = participant_tolerations if participant_tolerations else []
        if not tolerations:
            tolerations = global_tolerations if global_tolerations else []

    if tolerations != []:
        for toleration_data in tolerations:
            if toleration_data.get("toleration_seconds"):
                toleration_list.append(
                    Toleration(
                        key=toleration_data.get("key", ""),
                        value=toleration_data.get("value", ""),
                        operator=toleration_data.get("operator", ""),
                        effect=toleration_data.get("effect", ""),
                        toleration_seconds=toleration_data.get("toleration_seconds"),
                    )
                )
            # Gyani has to fix this in the future
            # https://github.com/kurtosis-tech/kurtosis/issues/2093
            else:
                toleration_list.append(
                    Toleration(
                        key=toleration_data.get("key", ""),
                        value=toleration_data.get("value", ""),
                        operator=toleration_data.get("operator", ""),
                        effect=toleration_data.get("effect", ""),
                    )
                )

    return toleration_list


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
    return {
        "participants": participants,
        "participants_matrix": participants_matrix,
        "network_params": network_params,
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
        "global_tolerations": [],
        "global_node_selectors": {},
        "keymanager_enabled": False,
        "checkpoint_sync_enabled": False,
        "checkpoint_sync_url": "",
        "port_publisher": {
            "nat_exit_ip": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
            "public_port_start": None,
        },
    }


def default_network_params():
    return {
        "network": "kurtosis",
        "network_id": "3151908",
        "deposit_contract_address": "0x4242424242424242424242424242424242424242",
        "seconds_per_slot": 12,
        "num_validator_keys_per_node": 64,
        "preregistered_validator_keys_mnemonic": constants.DEFAULT_MNEMONIC,
        "preregistered_validator_count": 0,
        "genesis_delay": 20,
        "genesis_gaslimit": 30000000,
        "max_per_epoch_activation_churn_limit": 8,
        "churn_limit_quotient": 65536,
        "ejection_balance": 16000000000,
        "eth1_follow_distance": 2048,
        "min_validator_withdrawability_delay": 256,
        "shard_committee_period": 256,
        "deneb_fork_epoch": 0,
        "electra_fork_epoch": 100000000,
        "eip7594_fork_epoch": 100000001,
        "eip7594_fork_version": "0x60000038",
        "eof_activation_epoch": "",
        "network_sync_base_url": "https://snapshots.ethpandaops.io/",
        "data_column_sidecar_subnet_count": 128,
        "samples_per_slot": 8,
        "custody_requirement": 4,
        "max_blobs_per_block": 6,
        "preset": "mainnet",
        "additional_preloaded_contracts": {},
        "devnet_repo": "ethpandaops",
        "prefunded_accounts": {},
    }


def default_minimal_network_params():
    return {
        "network": "kurtosis",
        "network_id": "3151908",
        "deposit_contract_address": "0x4242424242424242424242424242424242424242",
        "seconds_per_slot": 6,
        "num_validator_keys_per_node": 64,
        "preregistered_validator_keys_mnemonic": constants.DEFAULT_MNEMONIC,
        "preregistered_validator_count": 0,
        "genesis_delay": 20,
        "genesis_gaslimit": 30000000,
        "max_per_epoch_activation_churn_limit": 4,
        "churn_limit_quotient": 32,
        "ejection_balance": 16000000000,
        "eth1_follow_distance": 16,
        "min_validator_withdrawability_delay": 256,
        "shard_committee_period": 64,
        "deneb_fork_epoch": 0,
        "electra_fork_epoch": 100000000,
        "eip7594_fork_epoch": 100000001,
        "eip7594_fork_version": "0x60000038",
        "eof_activation_epoch": "",
        "network_sync_base_url": "https://snapshots.ethpandaops.io/",
        "data_column_sidecar_subnet_count": 128,
        "samples_per_slot": 8,
        "custody_requirement": 4,
        "max_blobs_per_block": 6,
        "preset": "minimal",
        "additional_preloaded_contracts": {},
        "devnet_repo": "ethpandaops",
        "prefunded_accounts": {},
    }


def default_participant():
    return {
        "el_type": "geth",
        "el_image": "",
        "el_log_level": "",
        "el_extra_env_vars": {},
        "el_extra_labels": {},
        "el_extra_params": [],
        "el_tolerations": [],
        "el_volume_size": 0,
        "el_min_cpu": 0,
        "el_max_cpu": 0,
        "el_min_mem": 0,
        "el_max_mem": 0,
        "cl_type": "lighthouse",
        "cl_image": "",
        "cl_log_level": "",
        "cl_extra_env_vars": {},
        "cl_extra_labels": {},
        "cl_extra_params": [],
        "cl_tolerations": [],
        "cl_volume_size": 0,
        "cl_min_cpu": 0,
        "cl_max_cpu": 0,
        "cl_min_mem": 0,
        "cl_max_mem": 0,
        "use_separate_vc": None,
        "vc_type": "",
        "vc_image": "",
        "vc_log_level": "",
        "vc_count": 1,
        "vc_extra_env_vars": {},
        "vc_extra_labels": {},
        "vc_extra_params": [],
        "vc_tolerations": [],
        "vc_min_cpu": 0,
        "vc_max_cpu": 0,
        "vc_min_mem": 0,
        "vc_max_mem": 0,
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
        "builder_network_params": None,
        "keymanager_enabled": None,
    }


def get_default_dora_params():
    return {
        "image": "",
        "env": {},
    }


def get_default_mev_params(mev_type, preset):
    mev_relay_image = constants.DEFAULT_FLASHBOTS_RELAY_IMAGE
    mev_builder_image = constants.DEFAULT_FLASHBOTS_BUILDER_IMAGE
    if preset == "minimal":
        mev_builder_cl_image = DEFAULT_CL_IMAGES_MINIMAL[constants.CL_TYPE.lighthouse]
    else:
        mev_builder_cl_image = DEFAULT_CL_IMAGES[constants.CL_TYPE.lighthouse]
    mev_builder_extra_data = None
    mev_boost_image = constants.DEFAULT_FLASHBOTS_MEV_BOOST_IMAGE
    mev_boost_args = ["mev-boost", "--relay-check"]
    mev_relay_api_extra_args = []
    mev_relay_housekeeper_extra_args = []
    mev_relay_website_extra_args = []
    mev_builder_extra_args = []
    mev_flood_image = "flashbots/mev-flood"
    mev_flood_extra_args = []
    mev_flood_seconds_per_bundle = 15
    mev_builder_prometheus_config = {
        "scrape_interval": "15s",
        "labels": None,
        "storage_tsdb_retention_time": "1d",
        "storage_tsdb_retention_size": "512MB",
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

    return {
        "mev_relay_image": mev_relay_image,
        "mev_builder_image": mev_builder_image,
        "mev_builder_cl_image": mev_builder_cl_image,
        "mev_builder_extra_data": mev_builder_extra_data,
        "mev_builder_extra_args": mev_builder_extra_args,
        "mev_boost_image": mev_boost_image,
        "mev_boost_args": mev_boost_args,
        "mev_relay_api_extra_args": mev_relay_api_extra_args,
        "mev_relay_housekeeper_extra_args": mev_relay_housekeeper_extra_args,
        "mev_relay_website_extra_args": mev_relay_website_extra_args,
        "mev_flood_image": mev_flood_image,
        "mev_flood_extra_args": mev_flood_extra_args,
        "mev_flood_seconds_per_bundle": mev_flood_seconds_per_bundle,
        "mev_builder_prometheus_config": mev_builder_prometheus_config,
    }


def get_default_tx_spammer_params():
    return {"tx_spammer_extra_args": []}


def get_default_goomy_blob_params():
    return {"goomy_blob_args": []}


def get_default_assertoor_params():
    return {
        "image": "",
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
    }


def get_default_xatu_sentry_params():
    return {
        "xatu_sentry_image": "ethpandaops/xatu:latest",
        "xatu_server_addr": "localhost:8080",
        "xatu_server_headers": {},
        "xatu_server_tls": False,
        "beacon_subscriptions": [
            "attestation",
            "block",
            "chain_reorg",
            "finalized_checkpoint",
            "head",
            "voluntary_exit",
            "contribution_and_proof",
            "blob_sidecar",
        ],
    }


def get_default_custom_flood_params():
    # this is a simple script that increases the balance of the coinbase address at a cadence
    return {"interval_between_transactions": 1}


def get_port_publisher_params(parameter_type, input_args=None):
    port_publisher_parameters = {
        "nat_exit_ip": "KURTOSIS_IP_ADDR_PLACEHOLDER",
        "el": {"enabled": False, "public_port_start": 32000},
        "cl": {"enabled": False, "public_port_start": 33000},
        "vc": {"enabled": False, "public_port_start": 34000},
        "additional_services": {"enabled": False, "public_port_start": 35000},
    }
    if parameter_type == "default":
        return port_publisher_parameters
    else:
        for setting in input_args["port_publisher"]:
            if setting == "nat_exit_ip":
                nat_exit_ip_value = input_args["port_publisher"][setting]
                port_publisher_parameters[setting] = nat_exit_ip_value
            else:
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
        mev_url = "http://{0}-{1}-{2}-{3}:{4}".format(
            MEV_BOOST_SERVICE_NAME_PREFIX,
            index_str,
            participant["cl_type"],
            participant["el_type"],
            mev_port,
        )

        if participant["cl_type"] == "lighthouse":
            participant["cl_extra_params"].append("--builder={0}".format(mev_url))
        if participant["vc_type"] == "lighthouse":
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

    num_participants = len(parsed_arguments_dict["participants"])
    index_str = shared_utils.zfill_custom(
        num_participants + 1, len(str(num_participants + 1))
    )
    if mev_type == constants.FLASHBOTS_MEV_TYPE:
        mev_participant = default_participant()
        mev_participant["el_type"] = "geth"
        mev_participant.update(
            {
                "el_image": parsed_arguments_dict["mev_params"]["mev_builder_image"],
                "cl_image": parsed_arguments_dict["mev_params"]["mev_builder_cl_image"],
                "cl_log_level": parsed_arguments_dict["global_log_level"],
                "cl_extra_params": [
                    "--always-prepare-payload",
                    "--prepare-payload-lookahead",
                    "12000",
                    "--disable-peer-scoring",
                ],
                # TODO(maybe) make parts of this more passable like the mev-relay-endpoint & forks
                "el_extra_params": [
                    "--builder",
                    "--builder.remote_relay_endpoint=http://mev-relay-api:9062",
                    "--builder.beacon_endpoints=http://cl-{0}-lighthouse-geth-builder:4000".format(
                        index_str
                    ),
                    "--builder.bellatrix_fork_version={0}".format(
                        constants.BELLATRIX_FORK_VERSION
                    ),
                    "--builder.genesis_fork_version={0}".format(
                        constants.GENESIS_FORK_VERSION
                    ),
                    "--builder.genesis_validators_root={0}".format(
                        constants.GENESIS_VALIDATORS_ROOT_PLACEHOLDER
                    ),
                    '--miner.extradata="Illuminate Dmocratize Dstribute"',
                    "--builder.algotype=greedy",
                    "--metrics.builder",
                ]
                + parsed_arguments_dict["mev_params"]["mev_builder_extra_args"],
                "el_extra_env_vars": {
                    "BUILDER_TX_SIGNING_KEY": "0x"
                    + genesis_constants.PRE_FUNDED_ACCOUNTS[0].private_key
                },
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
                    "12000",
                    "--disable-peer-scoring",
                ],
                "el_extra_params": parsed_arguments_dict["mev_params"][
                    "mev_builder_extra_args"
                ],
                "validator_count": 0,
            }
        )
        parsed_arguments_dict["participants"].append(mev_participant)
    return parsed_arguments_dict


def deep_copy_participant(participant):
    part = {}
    for k, v in participant.items():
        if type(v) == type([]):
            part[k] = list(v)
        else:
            part[k] = v
    return part


def get_public_ip(plan):
    response = plan.run_sh(
        name="get-public-ip",
        description="Get the public IP address of the current machine",
        run="curl -s https://ident.me",
    )
    return response.output
