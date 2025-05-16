PARTICIPANT_CATEGORIES = {
    "participants": [
        "el_type",
        "el_image",
        "el_log_level",
        "el_extra_env_vars",
        "el_extra_labels",
        "el_extra_params",
        "el_tolerations",
        "el_volume_size",
        "el_min_cpu",
        "el_max_cpu",
        "el_min_mem",
        "el_max_mem",
        "cl_type",
        "cl_image",
        "cl_log_level",
        "cl_extra_env_vars",
        "cl_extra_labels",
        "cl_extra_params",
        "cl_tolerations",
        "cl_volume_size",
        "cl_min_cpu",
        "cl_max_cpu",
        "cl_min_mem",
        "cl_max_mem",
        "supernode",
        "use_separate_vc",
        "vc_type",
        "vc_image",
        "vc_log_level",
        "vc_extra_env_vars",
        "vc_extra_labels",
        "vc_extra_params",
        "vc_tolerations",
        "vc_min_cpu",
        "vc_max_cpu",
        "vc_min_mem",
        "vc_max_mem",
        "validator_count",
        "use_remote_signer",
        "remote_signer_type",
        "remote_signer_image",
        "remote_signer_extra_env_vars",
        "remote_signer_extra_labels",
        "remote_signer_extra_params",
        "remote_signer_tolerations",
        "remote_signer_min_cpu",
        "remote_signer_max_cpu",
        "remote_signer_min_mem",
        "remote_signer_max_mem",
        "node_selectors",
        "tolerations",
        "count",
        "snooper_enabled",
        "ethereum_metrics_exporter_enabled",
        "xatu_sentry_enabled",
        "prometheus_config",
        "blobber_enabled",
        "blobber_extra_params",
        "builder_network_params",
        "keymanager_enabled",
    ],
}

PARTICIPANT_MATRIX_PARAMS = {
    "participants_matrix": {
        "el": [
            "el_type",
            "el_image",
            "el_log_level",
            "el_extra_env_vars",
            "el_extra_labels",
            "el_extra_params",
            "el_tolerations",
            "el_volume_size",
            "el_min_cpu",
            "el_max_cpu",
            "el_min_mem",
            "el_max_mem",
        ],
        "cl": [
            "cl_type",
            "cl_image",
            "cl_log_level",
            "cl_extra_env_vars",
            "cl_extra_labels",
            "cl_extra_params",
            "cl_tolerations",
            "cl_volume_size",
            "cl_min_cpu",
            "cl_max_cpu",
            "cl_min_mem",
            "cl_max_mem",
            "use_separate_vc",
            "vc_type",
            "vc_image",
            "vc_log_level",
            "vc_extra_env_vars",
            "vc_extra_labels",
            "vc_extra_params",
            "vc_tolerations",
            "vc_min_cpu",
            "vc_max_cpu",
            "vc_min_mem",
            "vc_max_mem",
            "validator_count",
            "count",
            "supernode",
        ],
        "vc": [
            "vc_type",
            "vc_image",
            "vc_log_level",
            "vc_extra_env_vars",
            "vc_extra_labels",
            "vc_extra_params",
            "vc_tolerations",
            "vc_min_cpu",
            "vc_max_cpu",
            "vc_min_mem",
            "vc_max_mem",
            "validator_count",
        ],
        "remote_signer": [
            "remote_signer_type",
            "remote_signer_image",
            "remote_signer_extra_env_vars",
            "remote_signer_extra_labels",
            "remote_signer_extra_params",
            "remote_signer_tolerations",
            "remote_signer_min_cpu",
            "remote_signer_max_cpu",
            "remote_signer_min_mem",
            "remote_signer_max_mem",
        ],
    },
}

SUBCATEGORY_PARAMS = {
    "network_params": [
        "network",
        "network_id",
        "deposit_contract_address",
        "seconds_per_slot",
        "num_validator_keys_per_node",
        "preregistered_validator_keys_mnemonic",
        "preregistered_validator_count",
        "genesis_delay",
        "genesis_gaslimit",
        "max_per_epoch_activation_churn_limit",
        "churn_limit_quotient",
        "ejection_balance",
        "eth1_follow_distance",
        "min_validator_withdrawability_delay",
        "shard_committee_period",
        "altair_fork_epoch",
        "bellatrix_fork_epoch",
        "capella_fork_epoch",
        "deneb_fork_epoch",
        "electra_fork_epoch",
        "fulu_fork_epoch",
        "eip7732_fork_epoch",
        "eip7805_fork_epoch",
        "network_sync_base_url",
        "force_snapshot_sync",
        "shadowfork_block_height",
        "data_column_sidecar_subnet_count",
        "samples_per_slot",
        "custody_requirement",
        "max_blobs_per_block_electra",
        "target_blobs_per_block_electra",
        "base_fee_update_fraction_electra",
        "preset",
        "additional_preloaded_contracts",
        "devnet_repo",
        "prefunded_accounts",
        "max_payload_size",
        "perfect_peerdas_enabled",
        "gas_limit",
        "bpo_1_epoch",
        "bpo_1_max_blobs",
        "bpo_1_target_blobs",
        "bpo_1_base_fee_update_fraction",
        "bpo_2_epoch",
        "bpo_2_max_blobs",
        "bpo_2_target_blobs",
        "bpo_2_base_fee_update_fraction",
        "bpo_3_epoch",
        "bpo_3_max_blobs",
        "bpo_3_target_blobs",
        "bpo_3_base_fee_update_fraction",
        "bpo_4_epoch",
        "bpo_4_max_blobs",
        "bpo_4_target_blobs",
        "bpo_4_base_fee_update_fraction",
        "bpo_5_epoch",
        "bpo_5_max_blobs",
        "bpo_5_target_blobs",
        "bpo_5_base_fee_update_fraction",
    ],
    "blockscout_params": [
        "image",
        "verif_image",
        "frontend_image",
    ],
    "dora_params": [
        "image",
        "env",
    ],
    "docker_cache_params": [
        "enabled",
        "url",
        "dockerhub_prefix",
        "github_prefix",
        "google_prefix",
    ],
    "tx_fuzz_params": [
        "image",
        "tx_fuzz_extra_args",
    ],
    "prometheus_params": [
        "min_cpu",
        "max_cpu",
        "min_mem",
        "max_mem",
        "storage_tsdb_retention_time",
        "storage_tsdb_retention_size",
        "image",
    ],
    "grafana_params": [
        "additional_dashboards",
        "min_cpu",
        "max_cpu",
        "min_mem",
        "max_mem",
        "image",
    ],
    "assertoor_params": [
        "image",
        "run_stability_check",
        "run_block_proposal_check",
        "run_transaction_test",
        "run_blob_transaction_test",
        "run_opcodes_transaction_test",
        "run_lifecycle_test",
        "tests",
    ],
    "mev_params": [
        "mev_relay_image",
        "mev_builder_image",
        "mev_builder_cl_image",
        "mev_builder_subsidy",
        "mev_boost_image",
        "mev_boost_args",
        "mev_relay_api_extra_args",
        "mev_relay_api_extra_env_vars",
        "mev_relay_housekeeper_extra_args",
        "mev_relay_housekeeper_extra_env_vars",
        "mev_relay_website_extra_args",
        "mev_relay_website_extra_env_vars",
        "mev_builder_extra_args",
        "mev_builder_prometheus_config",
        "mev_flood_image",
        "mev_flood_extra_args",
        "mev_flood_seconds_per_bundle",
        "custom_flood_params",
        "mock_mev_image",
    ],
    "xatu_sentry_params": [
        "xatu_sentry_image",
        "xatu_server_addr",
        "xatu_server_tls",
        "xatu_server_headers",
        "beacon_subscriptions",
    ],
    "spamoor_params": [
        "image",
        "min_cpu",
        "max_cpu",
        "min_mem",
        "max_mem",
        "extra_args",
        "spammers",
    ],
    "ethereum_genesis_generator_params": [
        "image",
    ],
    "port_publisher": [
        "nat_exit_ip",
        "el",
        "cl",
        "vc",
        "remote_signer",
        "additional_services",
        "mev",
        "other",
    ],
}

ADDITIONAL_SERVICES_PARAMS = [
    "assertoor",
    "broadcaster",
    "tx_fuzz",
    "custom_flood",
    "forkmon",
    "blockscout",
    "dora",
    "full_beaconchain_explorer",
    "prometheus_grafana",
    "blobscan",
    "dugtrio",
    "blutgang",
    "forky",
    "apache",
    "tracoor",
    "spamoor",
]

ADDITIONAL_CATEGORY_PARAMS = {
    "wait_for_finalization": "",
    "global_log_level": "",
    "snooper_enabled": "",
    "ethereum_metrics_exporter_enabled": "",
    "parallel_keystore_generation": "",
    "disable_peer_scoring": "",
    "persistent": "",
    "mev_type": "",
    "xatu_sentry_enabled": "",
    "apache_port": "",
    "global_tolerations": "",
    "global_node_selectors": "",
    "keymanager_enabled": "",
    "checkpoint_sync_enabled": "",
    "checkpoint_sync_url": "",
}


def deep_validate_params(plan, input_args, category, allowed_params):
    if category in input_args:
        for item in input_args[category]:
            for param in item.keys():
                if param not in allowed_params:
                    fail(
                        "Invalid parameter {0} for {1}. Allowed fields: {2}".format(
                            param, category, allowed_params
                        )
                    )


def validate_params(plan, input_args, category, allowed_params):
    if category in input_args:
        for param in input_args[category].keys():
            if param not in allowed_params:
                fail(
                    "Invalid parameter {0} for {1}. Allowed fields: {2}".format(
                        param, category, allowed_params
                    )
                )


def sanity_check(plan, input_args):
    # Checks participants
    deep_validate_params(
        plan, input_args, "participants", PARTICIPANT_CATEGORIES["participants"]
    )
    # Checks participants_matrix
    if "participants_matrix" in input_args:
        for sub_matrix_participant in input_args["participants_matrix"]:
            if (
                sub_matrix_participant
                not in PARTICIPANT_MATRIX_PARAMS["participants_matrix"]
            ):
                fail(
                    "Invalid parameter {0} for participants_matrix, allowed fields: {1}".format(
                        sub_matrix_participant,
                        PARTICIPANT_MATRIX_PARAMS["participants_matrix"].keys(),
                    )
                )
            else:
                deep_validate_params(
                    plan,
                    input_args["participants_matrix"],
                    sub_matrix_participant,
                    PARTICIPANT_MATRIX_PARAMS["participants_matrix"][
                        sub_matrix_participant
                    ],
                )

    # Checks additional services
    if "additional_services" in input_args:
        for additional_services in input_args["additional_services"]:
            if additional_services not in ADDITIONAL_SERVICES_PARAMS:
                fail(
                    "Invalid additional_services {0}, allowed fields: {1}".format(
                        additional_services, ADDITIONAL_SERVICES_PARAMS
                    )
                )

    # Checks subcategories
    for subcategories in SUBCATEGORY_PARAMS.keys():
        validate_params(
            plan, input_args, subcategories, SUBCATEGORY_PARAMS[subcategories]
        )
    # Checks everything else
    for param in input_args.keys():
        combined_root_params = (
            PARTICIPANT_CATEGORIES.keys()
            + PARTICIPANT_MATRIX_PARAMS.keys()
            + SUBCATEGORY_PARAMS.keys()
            + ADDITIONAL_CATEGORY_PARAMS.keys()
        )
        combined_root_params.append("additional_services")

        if param not in combined_root_params:
            fail(
                "Invalid parameter {0}, allowed fields {1}".format(
                    param, combined_root_params
                )
            )

    # If everything passes, print a message
    plan.print("Sanity check passed")
