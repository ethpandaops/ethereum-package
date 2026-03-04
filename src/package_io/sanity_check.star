PARTICIPANT_CATEGORIES = {
    "participants": [
        "el_type",
        "el_image",
        "el_binary_path",
        "el_log_level",
        "el_storage_type",
        "el_extra_env_vars",
        "el_extra_labels",
        "el_extra_params",
        "el_extra_mounts",
        "el_devices",
        "el_tolerations",
        "el_volume_size",
        "el_min_cpu",
        "el_max_cpu",
        "el_min_mem",
        "el_max_mem",
        "el_force_restart",
        "cl_type",
        "cl_image",
        "cl_binary_path",
        "cl_log_level",
        "cl_extra_env_vars",
        "cl_extra_labels",
        "cl_extra_params",
        "cl_extra_mounts",
        "cl_devices",
        "cl_tolerations",
        "cl_volume_size",
        "cl_min_cpu",
        "cl_max_cpu",
        "cl_min_mem",
        "cl_max_mem",
        "cl_force_restart",
        "supernode",
        "use_separate_vc",
        "vc_type",
        "vc_image",
        "vc_binary_path",
        "vc_log_level",
        "vc_extra_env_vars",
        "vc_extra_labels",
        "vc_extra_params",
        "vc_extra_mounts",
        "vc_devices",
        "vc_tolerations",
        "vc_min_cpu",
        "vc_max_cpu",
        "vc_min_mem",
        "vc_max_mem",
        "vc_force_restart",
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
        "blobber_image",
        "builder_network_params",
        "keymanager_enabled",
        "vc_beacon_node_indices",
        "checkpoint_sync_enabled",
        "skip_start",
    ],
}

PARTICIPANT_MATRIX_PARAMS = {
    "participants_matrix": {
        "el": [
            "el_type",
            "el_image",
            "el_binary_path",
            "el_log_level",
            "el_storage_type",
            "el_extra_env_vars",
            "el_extra_labels",
            "el_extra_params",
            "el_extra_mounts",
            "el_devices",
            "el_tolerations",
            "el_volume_size",
            "el_min_cpu",
            "el_max_cpu",
            "el_min_mem",
            "el_max_mem",
            "el_force_restart",
        ],
        "cl": [
            "cl_type",
            "cl_image",
            "cl_binary_path",
            "cl_log_level",
            "cl_extra_env_vars",
            "cl_extra_labels",
            "cl_extra_params",
            "cl_extra_mounts",
            "cl_devices",
            "cl_tolerations",
            "cl_volume_size",
            "cl_min_cpu",
            "cl_max_cpu",
            "cl_min_mem",
            "cl_max_mem",
            "use_separate_vc",
            "vc_type",
            "vc_image",
            "vc_binary_path",
            "vc_log_level",
            "vc_extra_env_vars",
            "vc_extra_labels",
            "vc_extra_params",
            "vc_extra_mounts",
            "vc_tolerations",
            "vc_min_cpu",
            "vc_max_cpu",
            "vc_min_mem",
            "vc_max_mem",
            "vc_force_restart",
            "validator_count",
            "count",
            "supernode",
            "vc_beacon_node_indices",
            "checkpoint_sync_enabled",
            "cl_force_restart",
        ],
        "vc": [
            "vc_type",
            "vc_image",
            "vc_binary_path",
            "vc_log_level",
            "vc_extra_env_vars",
            "vc_extra_labels",
            "vc_extra_params",
            "vc_extra_mounts",
            "vc_devices",
            "vc_tolerations",
            "vc_min_cpu",
            "vc_max_cpu",
            "vc_min_mem",
            "vc_max_mem",
            "vc_force_restart",
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

PORT_PUBLISHER_PARAMS = {
    "port_publisher": {
        "el": [
            "enabled",
            "public_port_start",
            "nat_exit_ip",
        ],
        "cl": [
            "enabled",
            "public_port_start",
            "nat_exit_ip",
        ],
        "vc": [
            "enabled",
            "public_port_start",
            "nat_exit_ip",
        ],
        "remote_signer": [
            "enabled",
            "public_port_start",
            "nat_exit_ip",
        ],
        "additional_services": [
            "enabled",
            "public_port_start",
            "nat_exit_ip",
        ],
        "mev": [
            "enabled",
            "public_port_start",
            "nat_exit_ip",
        ],
        "other": [
            "enabled",
            "public_port_start",
            "nat_exit_ip",
        ],
    },
}

SUBCATEGORY_PARAMS = {
    "network_params": [
        "network",
        "network_id",
        "deposit_contract_address",
        "seconds_per_slot",
        "slot_duration_ms",
        "num_validator_keys_per_node",
        "preregistered_validator_keys_mnemonic",
        "preregistered_validator_count",
        "genesis_delay",
        "genesis_time",
        "genesis_gaslimit",
        "max_per_epoch_activation_churn_limit",
        "churn_limit_quotient",
        "ejection_balance",
        "eth1_follow_distance",
        "min_validator_withdrawability_delay",
        "min_builder_withdrawability_delay",
        "shard_committee_period",
        "attestation_due_bps_gloas",
        "aggregate_due_bps_gloas",
        "sync_message_due_bps_gloas",
        "contribution_due_bps_gloas",
        "payload_attestation_due_bps",
        "view_freeze_cutoff_bps",
        "inclusion_list_submission_due_bps",
        "proposer_inclusion_list_cutoff_bps",
        "altair_fork_epoch",
        "bellatrix_fork_epoch",
        "capella_fork_epoch",
        "deneb_fork_epoch",
        "electra_fork_epoch",
        "fulu_fork_epoch",
        "gloas_fork_epoch",
        "heze_fork_epoch",
        "eip7441_fork_epoch",
        "network_sync_base_url",
        "force_snapshot_sync",
        "shadowfork_block_height",
        "data_column_sidecar_subnet_count",
        "samples_per_slot",
        "custody_requirement",
        "max_blobs_per_block_electra",
        "target_blobs_per_block_electra",
        "max_request_blocks_deneb",
        "max_request_blob_sidecars_electra",
        "base_fee_update_fraction_electra",
        "preset",
        "additional_preloaded_contracts",
        "additional_mnemonics",
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
        "withdrawal_type",
        "withdrawal_address",
        "validator_balance",
        "min_epochs_for_data_column_sidecars_requests",
        "min_epochs_for_block_requests",
    ],
    "blockscout_params": ["image", "verif_image", "frontend_image", "env"],
    "dora_params": [
        "image",
        "env",
    ],
    "checkpointz_params": [
        "image",
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
    "rakoon_params": [
        "image",
        "tx_type",
        "workers",
        "batch_size",
        "seed",
        "fuzzing",
        "poll_interval",
        "extra_args",
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
    "tempo_params": [
        "retention_duration",
        "ingestion_rate_limit",
        "ingestion_burst_limit",
        "max_search_duration",
        "max_bytes_per_trace",
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
        "mev_builder_cl_extra_params",
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
        "custom_flood_params",
        "mock_mev_image",
        "launch_adminer",
        "run_multiple_relays",
        "helix_relay_image",
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
    "slashoor_params": [
        "image",
        "min_cpu",
        "max_cpu",
        "min_mem",
        "max_mem",
        "extra_args",
        "log_level",
        "beacon_timeout",
        "max_epochs_to_keep",
        "detector_enabled",
        "proposer_enabled",
        "submitter_enabled",
        "submitter_dry_run",
        "dora_enabled",
        "dora_url",
        "dora_scan_on_startup",
        "backfill_slots",
    ],
    "mempool_bridge_params": [
        "image",
        "source_enodes",
        "mode",
        "log_level",
        "send_concurrency",
        "polling_interval",
        "retry_interval",
    ],
    "ethereum_genesis_generator_params": [
        "image",
        "extra_env",
    ],
    "bootnodoor_params": [
        "image",
        "min_cpu",
        "max_cpu",
        "min_mem",
        "max_mem",
        "extra_args",
    ],
    "ews_params": [
        "image",
        "retain",
        "num_proofs",
        "env",
    ],
    "buildoor_params": [
        "image",
        "extra_args",
        "builder_api",
        "epbs_builder",
    ],
}

ADDITIONAL_SERVICES_PARAMS = [
    "bootnodoor",
    "assertoor",
    "broadcaster",
    "tx_fuzz",
    "custom_flood",
    "forkmon",
    "blockscout",
    "dora",
    "checkpointz",
    "full_beaconchain_explorer",
    "prometheus_grafana",
    "prometheus",
    "grafana",
    "tempo",
    "blobscan",
    "dugtrio",
    "blutgang",
    "erpc",
    "forky",
    "apache",
    "nginx",
    "tracoor",
    "mempool_bridge",
    "rakoon",
    "slashoor",
    "spamoor",
    "ews",
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
    "nginx_port": "",
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


def validate_nested_params(
    plan, input_args, category, nested_param_definition, special_keys=None
):
    if category not in input_args:
        return

    special_keys = special_keys or []
    allowed_top_level_keys = list(nested_param_definition.keys()) + special_keys

    # Validate top-level keys
    for param in input_args[category].keys():
        if param not in allowed_top_level_keys:
            fail(
                "Invalid parameter {0} for {1}, allowed fields: {2}".format(
                    param, category, allowed_top_level_keys
                )
            )

    # Validate nested parameters
    for sub_param in input_args[category]:
        if sub_param not in special_keys and sub_param in nested_param_definition:
            validate_params(
                plan,
                input_args[category],
                sub_param,
                nested_param_definition[sub_param],
            )


def sanity_check(plan, input_args):
    # Checks participants
    deep_validate_params(
        plan, input_args, "participants", PARTICIPANT_CATEGORIES["participants"]
    )
    # Checks participants_matrix (uses original logic for arrays of objects)
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

    # Checks port_publisher (uses new generic validation for key-value mappings)
    validate_nested_params(
        plan,
        input_args,
        "port_publisher",
        PORT_PUBLISHER_PARAMS["port_publisher"],
        ["nat_exit_ip"],
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
            + PORT_PUBLISHER_PARAMS.keys()
            + SUBCATEGORY_PARAMS.keys()
            + ADDITIONAL_CATEGORY_PARAMS.keys()
        )
        combined_root_params.append("additional_services")
        combined_root_params.append("extra_files")

        if param not in combined_root_params:
            fail(
                "Invalid parameter {0}, allowed fields {1}".format(
                    param, combined_root_params
                )
            )

    # If everything passes, print a message
    plan.print("Sanity check passed")
