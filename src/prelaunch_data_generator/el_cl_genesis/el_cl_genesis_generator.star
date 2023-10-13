shared_utils = import_module("../../shared_utils/shared_utils.star")

prelaunch_data_generator_launcher = import_module(
    "../../prelaunch_data_generator/prelaunch_data_generator_launcher/prelaunch_data_generator_launcher.star"
)

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
        run = "cp /opt/values.env /config/values.env && ./entrypoint.sh all",
        image = image,
        files = {
           GENESIS_VALUES_PATH : genesis_generation_config_artifact_name
        },
        store = [
            "/data",
        ],
        wait= None
    )

    # this is super hacky lmao
    genesis_validators_root = plan.run_sh(
        run = "cat /data/data/custom_config_data/genesis_validators_root.txt",
        image = "busybox",
        files = {
              "/data" : genesis.files_artifacts[0]
          },
        wait = None
    )

    return genesis.files_artifacts[0], genesis_validators_root.output



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
    }


