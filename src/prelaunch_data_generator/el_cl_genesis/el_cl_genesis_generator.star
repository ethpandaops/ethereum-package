shared_utils = import_module("../../shared_utils/shared_utils.star")

el_cl_genesis_data = import_module("./el_cl_genesis_data.star")

constants = import_module("../../package_io/constants.star")

GENESIS_VALUES_PATH = "/opt"
GENESIS_VALUES_FILENAME = "values.env"


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
    capella_fork_epoch,
    deneb_fork_epoch,
    electra_fork_epoch,
):
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
        capella_fork_epoch,
        deneb_fork_epoch,
        electra_fork_epoch,
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

    genesis = plan.run_sh(
        run="cp /opt/values.env /config/values.env && ./entrypoint.sh all",
        image=image,
        files={GENESIS_VALUES_PATH: genesis_generation_config_artifact_name},
        store=[StoreSpec(src="/data", name="el-cl-genesis-data")],
        wait=None,
    )

    # this is super hacky lmao
    genesis_validators_root = plan.run_python(
        run="""
with open("/data/data/custom_config_data/genesis_validators_root.txt") as genesis_root:
    print(genesis_root.read().strip(), end="")
""",
        files={"/data": genesis.files_artifacts[0]},
        store=[StoreSpec(src="/tmp", name="genesis-validators-root")],
        wait=None,
    )
    result = el_cl_genesis_data.new_el_cl_genesis_data(
        genesis.files_artifacts[0], genesis_validators_root.output
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
    capella_fork_epoch,
    deneb_fork_epoch,
    electra_fork_epoch,
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
        "CapellaForkEpoch": capella_fork_epoch,
        "DenebForkEpoch": deneb_fork_epoch,
        "ElectraForkEpoch": electra_fork_epoch,
        "GenesisForkVersion": constants.GENESIS_FORK_VERSION,
        "BellatrixForkVersion": constants.BELLATRIX_FORK_VERSION,
        "CapellaForkVersion": constants.CAPELLA_FORK_VERSION,
        "DenebForkVersion": constants.DENEB_FORK_VERSION,
    }
