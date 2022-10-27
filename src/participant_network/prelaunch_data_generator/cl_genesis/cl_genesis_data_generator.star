# Needed to copy the JWT secret and the EL genesis.json file
EL_GENESIS_DIRPATH_ON_GENERATOR = "/el-genesis"

CONFIG_DIRPATH_ON_GENERATOR = "/config"
GENESIS_CONFIG_YML_FILENAME = "config.yaml" // WARNING: Do not change this! It will get copied to the CL genesis data, and the CL clients are hardcoded to look for this filename
MNEMONICS_YML_FILENAME = "mnemonics.yaml"
OUTPUT_DIRPATH_ON_GENERATOR = "/output"
TRANCHES_DIRANME = "tranches"
GENESIS_STATE_FILENAME = "genesis.ssz"
DEPLOY_BLOCK_FILENAME = "deploy_block.txt"
DEPOSIT_CONTRACT_FILENAME = "deposit_contract.txt"

# Generation constants
CL_GENESIS_GENERATION_BINARY_FILEPATH_ON_CONTAINER = "/usr/local/bin/eth2-testnet-genesis"
DEPLOY_BLOCK = "0"
ETH1_BLOCK = "0x0000000000000000000000000000000000000000000000000000000000000000"

SUCCESSFUL_EXEC_CMD_EXIT_CODE = 0


def generate_cl_genesis_data(
        genesis_generation_config_yml_template,
        genesis_generation_mnemonics_yml_template,
        el_genesis_data.ELGenesisData,
        genesis_unix_timestamp,
        network_id,
        deposit_contract_address,
        seconds_per_slot,
        preregistered_validator_keys_mnemonic,
        total_num_validator_keys_to_preregister):

    template_data = new_cl_genesis_config_template_data{
        network_id,
        seconds_per_slot,
        genesis_unix_timestamp,
        total_num_validator_keys_to_preregister,
        preregistered_validator_keys_mnemonic,
        deposit_contract_address,
    }


def new_cl_genesis_config_template_data(network_id, seconds_per_slot, unix_timestamp, total_terminal_difficulty, altair_fork_epoch, merge_fork_epoch, num_validator_keys_to_preregister, preregistered_validator_keys_mnemonic, deposit_contract_address):
    return {
        "NetworkId": network_id,
        "SecondsPerSlot": seconds_per_slot,
        "UnixTimestamp": unix_timestamp,
        "TotalTerminalDifficulty": total_terminal_difficulty,
        "AltairForkEpoch": altair_fork_epoch,
        "MergeForkEpoch": merge_fork_epoch,
        "NumValidatorKeysToPreregister": num_validator_keys_to_preregister,
        "PreregisteredValidatorKeysMnemonic": preregistered_validator_keys_mnemonic,
        "DepositContractAddress": deposit_contract_address,
    }
