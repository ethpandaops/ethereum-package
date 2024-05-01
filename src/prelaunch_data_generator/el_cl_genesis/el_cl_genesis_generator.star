shared_utils = import_module("../../shared_utils/shared_utils.star")

el_cl_genesis_data = import_module("./el_cl_genesis_data.star")

constants = import_module("../../package_io/constants.star")

GENESIS_VALUES_PATH = "/opt"
GENESIS_VALUES_FILENAME = "values.env"
SHADOWFORK_FILEPATH = "/shadowfork"


def generate_el_cl_genesis_data(
    plan,
    image,
    genesis_generation_config_yml_template,
    genesis_unix_timestamp,
    network_id,
    deposit_contract_address,
    seconds_per_slot,
    preregistered_validator_keys_mnemonic,
    total_num_validator_keys_to_preregister,
    genesis_delay,
    max_churn,
    ejection_balance,
    eth1_follow_distance,
    deneb_fork_epoch,
    electra_fork_epoch,
    latest_block,
    min_validator_withdrawability_delay,
    shard_committee_period,
    preset,
):
    files = {}
    shadowfork_file = ""
    if latest_block != "":
        files[SHADOWFORK_FILEPATH] = latest_block
        shadowfork_file = SHADOWFORK_FILEPATH + "/latest_block.json"

    template_data = new_env_file_for_el_cl_genesis_data(
        genesis_unix_timestamp,
        network_id,
        deposit_contract_address,
        seconds_per_slot,
        preregistered_validator_keys_mnemonic,
        total_num_validator_keys_to_preregister,
        genesis_delay,
        max_churn,
        ejection_balance,
        eth1_follow_distance,
        deneb_fork_epoch,
        electra_fork_epoch,
        shadowfork_file,
        min_validator_withdrawability_delay,
        shard_committee_period,
        preset,
    )
    genesis_generation_template = shared_utils.new_template_and_data(
        genesis_generation_config_yml_template, template_data
    )

    genesis_values_and_dest_filepath = {}

    genesis_values_and_dest_filepath[
        GENESIS_VALUES_FILENAME
    ] = genesis_generation_template

    genesis_generation_config_artifact_name = plan.render_templates(
        genesis_values_and_dest_filepath, "genesis-el-cl-env-file"
    )

    files[GENESIS_VALUES_PATH] = genesis_generation_config_artifact_name

    genesis = plan.run_sh(
        description="Creating genesis",
        run="cp /opt/values.env /config/values.env && ./entrypoint.sh all && mkdir /network-configs && mv /data/custom_config_data/* /network-configs/",
        image=image,
        files=files,
        store=[
            StoreSpec(src="/network-configs/", name="el_cl_genesis_data"),
            StoreSpec(
                src="/network-configs/genesis_validators_root.txt",
                name="genesis_validators_root",
            ),
        ],
        wait=None,
    )

    genesis_validators_root = plan.run_sh(
        description="Reading genesis validators root",
        run="cat /data/genesis_validators_root.txt",
        files={"/data": genesis.files_artifacts[1]},
        wait=None,
    )

    cancun_time = plan.run_sh(
        description="Reading cancun time from genesis",
        run="jq .config.cancunTime /data/genesis.json | tr -d '\n'",
        image="badouralix/curl-jq",
        files={"/data": genesis.files_artifacts[0]},
    )

    prague_time = plan.run_sh(
        description="Reading prague time from genesis",
        run="jq .config.pragueTime /data/genesis.json | tr -d '\n'",
        image="badouralix/curl-jq",
        files={"/data": genesis.files_artifacts[0]},
    )

    result = el_cl_genesis_data.new_el_cl_genesis_data(
        genesis.files_artifacts[0],
        genesis_validators_root.output,
        cancun_time.output,
        prague_time.output,
    )

    return result


def new_env_file_for_el_cl_genesis_data(
    genesis_unix_timestamp,
    network_id,
    deposit_contract_address,
    seconds_per_slot,
    preregistered_validator_keys_mnemonic,
    total_num_validator_keys_to_preregister,
    genesis_delay,
    max_churn,
    ejection_balance,
    eth1_follow_distance,
    deneb_fork_epoch,
    electra_fork_epoch,
    shadowfork_file,
    min_validator_withdrawability_delay,
    shard_committee_period,
    preset,
):
    return {
        "UnixTimestamp": genesis_unix_timestamp,
        "NetworkId": network_id,
        "DepositContractAddress": deposit_contract_address,
        "SecondsPerSlot": seconds_per_slot,
        "PreregisteredValidatorKeysMnemonic": preregistered_validator_keys_mnemonic,
        "NumValidatorKeysToPreregister": total_num_validator_keys_to_preregister,
        "GenesisDelay": genesis_delay,
        "MaxChurn": max_churn,
        "EjectionBalance": ejection_balance,
        "Eth1FollowDistance": eth1_follow_distance,
        "DenebForkEpoch": deneb_fork_epoch,
        "ElectraForkEpoch": electra_fork_epoch,
        "GenesisForkVersion": constants.GENESIS_FORK_VERSION,
        "BellatrixForkVersion": constants.BELLATRIX_FORK_VERSION,
        "CapellaForkVersion": constants.CAPELLA_FORK_VERSION,
        "DenebForkVersion": constants.DENEB_FORK_VERSION,
        "ElectraForkVersion": constants.ELECTRA_FORK_VERSION,
        "ShadowForkFile": shadowfork_file,
        "MinValidatorWithdrawabilityDelay": min_validator_withdrawability_delay,
        "ShardCommitteePeriod": shard_committee_period,
        "Preset": preset,
    }
