load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_template_and_data", "path_join", "path_base")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/cl_genesis/cl_genesis_data.star", "new_cl_genesis_data")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/prelaunch_data_generator_launcher/prelaunch_data_generator_launcher.star", "launch_prelaunch_data_generator")


# Needed to copy the JWT secret and the EL genesis.json file
EL_GENESIS_DIRPATH_ON_GENERATOR = "/el-genesis"

CONFIG_DIRPATH_ON_GENERATOR = "/config"
GENESIS_CONFIG_YML_FILENAME = "config.yaml" # WARNING: Do not change this! It will get copied to the CL genesis data, and the CL clients are hardcoded to look for this filename
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
		el_genesis_data,
		genesis_unix_timestamp,
		network_id,
		deposit_contract_address,
		seconds_per_slot,
		preregistered_validator_keys_mnemonic,
		total_num_validator_keys_to_preregister):

	template_data = json.encode(new_cl_genesis_config_template_data(
		network_id,
		seconds_per_slot,
		genesis_unix_timestamp,
		total_num_validator_keys_to_preregister,
		preregistered_validator_keys_mnemonic,
		deposit_contract_address,
	))

	genesis_generation_mnemonics_template_and_data = new_template_and_data(genesis_generation_mnemonics_yml_template, template_data)
	genesis_generation_config_template_and_data = new_template_and_data(genesis_generation_config_yml_template, template_data)

	template_and_data_by_rel_dest_filepath = {}
	template_and_data_by_rel_dest_filepath[MNEMONICS_YML_FILENAME] = genesis_generation_mnemonics_template_and_data
	template_and_data_by_rel_dest_filepath[GENESIS_CONFIG_YML_FILENAME] = genesis_generation_config_template_and_data

	genesis_generation_config_artifact_uuid = render_templates(template_and_data_by_rel_dest_filepath)

	# TODO Make this the actual data generator - comment copied from the original module
	launcher_service_id = launch_prelaunch_data_generator(
		{
			genesis_generation_config_artifact_uuid:  CONFIG_DIRPATH_ON_GENERATOR,
			el_genesis_data.files_artifact_uuid: EL_GENESIS_DIRPATH_ON_GENERATOR,
		},
	)

	all_dirpaths_to_create_on_generator = [
		CONFIG_DIRPATH_ON_GENERATOR,
		OUTPUT_DIRPATH_ON_GENERATOR,
	]

	all_dirpath_creation_commands = []
	for dirpath_to_create_on_generator in all_dirpaths_to_create_on_generator:
		all_dirpath_creation_commands.append(
			"mkdir -p {0}".format(dirpath_to_create_on_generator))

	dir_creation_cmd = [
		"bash",
		"-c",
		(" && ").join(all_dirpath_creation_commands),
	]

	exec(launcher_service_id, dir_creation_cmd, SUCCESSFUL_EXEC_CMD_EXIT_CODE)


	# Copy files to output
	all_filepaths_to_copy_to_ouptut_directory = [
		path_join(CONFIG_DIRPATH_ON_GENERATOR, GENESIS_CONFIG_YML_FILENAME),
		path_join(CONFIG_DIRPATH_ON_GENERATOR, MNEMONICS_YML_FILENAME),
		path_join(EL_GENESIS_DIRPATH_ON_GENERATOR, el_genesis_data.jwt_secret_relative_filepath),
	]

	for filepath_on_generator in all_filepaths_to_copy_to_ouptut_directory:
		cmd = [
			"cp",
			filepath_on_generator,
			OUTPUT_DIRPATH_ON_GENERATOR,
		]
		exec(launcher_service_id, cmd, SUCCESSFUL_EXEC_CMD_EXIT_CODE)

	# Generate files that need dynamic content
	content_to_write_to_output_filename = {
		DEPLOY_BLOCK:            DEPLOY_BLOCK_FILENAME,
		deposit_contract_address: DEPOSIT_CONTRACT_FILENAME,
	}
	for content, destFilename in content_to_write_to_output_filename.items():
		destFilepath = path_join(OUTPUT_DIRPATH_ON_GENERATOR, destFilename)
		cmd = [
			"sh",
			"-c",
			"echo {0} > {1}".format(
				content,
				destFilepath,
			)
		]
		exec(launcher_service_id, cmd, SUCCESSFUL_EXEC_CMD_EXIT_CODE)
		

	cl_genesis_generation_cmd_args = [
		CL_GENESIS_GENERATION_BINARY_FILEPATH_ON_CONTAINER,
		"merge",
		"--config", path_join(OUTPUT_DIRPATH_ON_GENERATOR, GENESIS_CONFIG_YML_FILENAME),
		"--mnemonics", path_join(OUTPUT_DIRPATH_ON_GENERATOR, MNEMONICS_YML_FILENAME),
		"--eth1-config", path_join(EL_GENESIS_DIRPATH_ON_GENERATOR, el_genesis_data.geth_genesis_json_relative_filepath),
		"--tranches-dir", path_join(OUTPUT_DIRPATH_ON_GENERATOR, TRANCHES_DIRANME),
		"--state-output", path_join(OUTPUT_DIRPATH_ON_GENERATOR, GENESIS_STATE_FILENAME)
	]

	exec(launcher_service_id, cl_genesis_generation_cmd_args, SUCCESSFUL_EXEC_CMD_EXIT_CODE)

	cl_genesis_data_artifact_uuid = store_file_from_service(launcher_service_id, OUTPUT_DIRPATH_ON_GENERATOR)

	jwt_secret_rel_filepath = path_join(
		path_base(OUTPUT_DIRPATH_ON_GENERATOR),
		path_base(el_genesis_data.jwt_secret_relative_filepath),
	)
	genesis_config_rel_filepath = path_join(
		path_base(OUTPUT_DIRPATH_ON_GENERATOR),
		GENESIS_CONFIG_YML_FILENAME,
	)
	genesis_ssz_rel_filepath = path_join(
		path_base(OUTPUT_DIRPATH_ON_GENERATOR),
		GENESIS_STATE_FILENAME,
	)
	result = new_cl_genesis_data(
		cl_genesis_data_artifact_uuid,
		jwt_secret_rel_filepath,
		genesis_config_rel_filepath,
		genesis_ssz_rel_filepath,
	)

	# we cleanup as the data generation is done
	remove_service(launcher_service_id)
	return result



def new_cl_genesis_config_template_data(network_id, seconds_per_slot, unix_timestamp, num_validator_keys_to_preregister, preregistered_validator_keys_mnemonic, deposit_contract_address):
	return {
		"NetworkId": network_id,
		"SecondsPerSlot": seconds_per_slot,
		"UnixTimestamp": unix_timestamp,
		"NumValidatorKeysToPreregister": num_validator_keys_to_preregister,
		"PreregisteredValidatorKeysMnemonic": preregistered_validator_keys_mnemonic,
		"DepositContractAddress": deposit_contract_address,
	}
