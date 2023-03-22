shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")
cl_genesis_data = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/prelaunch_data_generator/cl_genesis/cl_genesis_data.star")
prelaunch_data_generator_launcher = import_module("github.com/kurtosis-tech/eth2-package/src/participant_network/prelaunch_data_generator/prelaunch_data_generator_launcher/prelaunch_data_generator_launcher.star")


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
		plan,
		genesis_generation_config_yml_template,
		genesis_generation_mnemonics_yml_template,
		el_genesis_data,
		genesis_unix_timestamp,
		network_id,
		deposit_contract_address,
		seconds_per_slot,
		preregistered_validator_keys_mnemonic,
		total_num_validator_keys_to_preregister,
		genesis_delay,
		capella_fork_epoch
	):

	template_data = new_cl_genesis_config_template_data(
		network_id,
		seconds_per_slot,
		genesis_unix_timestamp,
		total_num_validator_keys_to_preregister,
		preregistered_validator_keys_mnemonic,
		deposit_contract_address,
		genesis_delay,
		capella_fork_epoch
	)

	genesis_generation_mnemonics_template_and_data = shared_utils.new_template_and_data(genesis_generation_mnemonics_yml_template, template_data)
	genesis_generation_config_template_and_data = shared_utils.new_template_and_data(genesis_generation_config_yml_template, template_data)

	template_and_data_by_rel_dest_filepath = {}
	template_and_data_by_rel_dest_filepath[MNEMONICS_YML_FILENAME] = genesis_generation_mnemonics_template_and_data
	template_and_data_by_rel_dest_filepath[GENESIS_CONFIG_YML_FILENAME] = genesis_generation_config_template_and_data

	genesis_generation_config_artifact_name = plan.render_templates(template_and_data_by_rel_dest_filepath, "genesis-generation-config-cl")

	# TODO(old) Make this the actual data generator - comment copied from the original module
	launcher_service_name = prelaunch_data_generator_launcher.launch_prelaunch_data_generator(
		plan,
		{
			CONFIG_DIRPATH_ON_GENERATOR: genesis_generation_config_artifact_name,
			EL_GENESIS_DIRPATH_ON_GENERATOR: el_genesis_data.files_artifact_uuid,
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

	dir_creation_cmd_result = plan.exec(ExecRecipe(command=dir_creation_cmd), service_name=launcher_service_name)
	plan.assert(dir_creation_cmd_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)


	# Copy files to output
	all_filepaths_to_copy_to_ouptut_directory = [
		shared_utils.path_join(CONFIG_DIRPATH_ON_GENERATOR, GENESIS_CONFIG_YML_FILENAME),
		shared_utils.path_join(CONFIG_DIRPATH_ON_GENERATOR, MNEMONICS_YML_FILENAME),
		shared_utils.path_join(EL_GENESIS_DIRPATH_ON_GENERATOR, el_genesis_data.jwt_secret_relative_filepath),
	]

	for filepath_on_generator in all_filepaths_to_copy_to_ouptut_directory:
		cmd = [
			"cp",
			filepath_on_generator,
			OUTPUT_DIRPATH_ON_GENERATOR,
		]
		cmd_result = plan.exec(ExecRecipe( command=cmd), service_name=launcher_service_name)
		plan.assert(cmd_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)

	# Generate files that need dynamic content
	content_to_write_to_output_filename = {
		DEPLOY_BLOCK:            DEPLOY_BLOCK_FILENAME,
		deposit_contract_address: DEPOSIT_CONTRACT_FILENAME,
	}
	for content, destFilename in content_to_write_to_output_filename.items():
		destFilepath = shared_utils.path_join(OUTPUT_DIRPATH_ON_GENERATOR, destFilename)
		cmd = [
			"sh",
			"-c",
			"echo {0} > {1}".format(
				content,
				destFilepath,
			)
		]
		cmd_result = plan.exec(ExecRecipe( command=cmd), service_name=launcher_service_name)
		plan.assert(cmd_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)
		

	cl_genesis_generation_cmd = [
		CL_GENESIS_GENERATION_BINARY_FILEPATH_ON_CONTAINER,
		"merge",
		"--config", shared_utils.path_join(OUTPUT_DIRPATH_ON_GENERATOR, GENESIS_CONFIG_YML_FILENAME),
		"--mnemonics", shared_utils.path_join(OUTPUT_DIRPATH_ON_GENERATOR, MNEMONICS_YML_FILENAME),
		"--eth1-config", shared_utils.path_join(EL_GENESIS_DIRPATH_ON_GENERATOR, el_genesis_data.geth_genesis_json_relative_filepath),
		"--tranches-dir", shared_utils.path_join(OUTPUT_DIRPATH_ON_GENERATOR, TRANCHES_DIRANME),
		"--state-output", shared_utils.path_join(OUTPUT_DIRPATH_ON_GENERATOR, GENESIS_STATE_FILENAME)
	]

	genesis_generation_result = plan.exec(ExecRecipe(command=cl_genesis_generation_cmd), service_name=launcher_service_name)
	plan.assert(genesis_generation_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)

	cl_genesis_data_artifact_name = plan.store_service_files(launcher_service_name, OUTPUT_DIRPATH_ON_GENERATOR, name = "cl-genesis-data")

	jwt_secret_rel_filepath = shared_utils.path_join(
		shared_utils.path_base(OUTPUT_DIRPATH_ON_GENERATOR),
		shared_utils.path_base(el_genesis_data.jwt_secret_relative_filepath),
	)
	genesis_config_rel_filepath = shared_utils.path_join(
		shared_utils.path_base(OUTPUT_DIRPATH_ON_GENERATOR),
		GENESIS_CONFIG_YML_FILENAME,
	)
	genesis_ssz_rel_filepath = shared_utils.path_join(
		shared_utils.path_base(OUTPUT_DIRPATH_ON_GENERATOR),
		GENESIS_STATE_FILENAME,
	)
	result = cl_genesis_data.new_cl_genesis_data(
		cl_genesis_data_artifact_name,
		jwt_secret_rel_filepath,
		genesis_config_rel_filepath,
		genesis_ssz_rel_filepath,
	)

	# we cleanup as the data generation is done
	plan.remove_service(launcher_service_name)
	return result



def new_cl_genesis_config_template_data(network_id, seconds_per_slot, unix_timestamp, num_validator_keys_to_preregister, preregistered_validator_keys_mnemonic, deposit_contract_address, genesis_delay, capella_fork_epoch):
	return {
		"NetworkId": network_id,
		"SecondsPerSlot": seconds_per_slot,
		"UnixTimestamp": unix_timestamp,
		"NumValidatorKeysToPreregister": num_validator_keys_to_preregister,
		"PreregisteredValidatorKeysMnemonic": preregistered_validator_keys_mnemonic,
		"DepositContractAddress": deposit_contract_address,
		"GenesisDelay": genesis_delay,
		"CapellaForkEpoch": capella_fork_epoch
	}
