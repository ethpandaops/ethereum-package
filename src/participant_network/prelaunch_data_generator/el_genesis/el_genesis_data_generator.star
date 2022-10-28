load("github.com/kurtosis-tech/eth2-merge-startosis-module/src/shared_utils/shared_utils.star", "new_template_and_data", "path_join", "path_base")
load("github.com/kurtosis-tech/eth2-merge-startosis-module/src/participant_network/prelaunch_data_generator/el_genesis/el_genesis_data.star", "new_el_genesis_data")

CONFIG_DIRPATH_ON_GENERATOR = "/config"
GENESIS_CONFIG_FILENAME    = "genesis-config.yaml"

OUTPUT_DIRPATH_ON_GENERATOR = "/output"

GETH_GENESIS_FILENAME       = "geth.json"
ERIGON_GENESIS_FILENAME     = "erigon.json"
NETHERMIND_GENESIS_FILENAME = "nethermind.json"
BESU_GENESIS_FILENAME       = "besu.json"

JWT_SECRET_FILENAME = "jwtsecret"

SUCCESSFUL_EXEC_CMD_EXIT_CODE = 0


# Mapping of output genesis filename -> generator to create the file
all_genesis_generation_cmds =  {
	GETH_GENESIS_FILENAME: lambda genesis_config_filepath_on_generator: ["python3", "/apps/el-gen/genesis_geth.py", genesis_config_filepath_on_generator],
	ERIGON_GENESIS_FILENAME: lambda genesis_config_filepath_on_generator: ["python3", "/apps/el-gen/genesis_geth.py",genesis_config_filepath_on_generator],
	NETHERMIND_GENESIS_FILENAME: lambda genesis_config_filepath_on_generator: ["python3", "/apps/el-gen/genesis_chainspec.py", genesis_config_filepath_on_generator],
	BESU_GENESIS_FILENAME: lambda genesis_config_filepath_on_generator :["python3", "/apps/el-gen/genesis_besu.py", genesis_config_filepath_on_generator]
}

def generate_el_genesis_data(
	genesis_generation_config_template,
	genesis_unix_timestamp,
	network_id,
	deposit_contract_address):

	template_data = genesis_generation_config_template_data(
		network_id,
		deposit_contract_address,
		genesis_unix_timestamp,
		0 # set terminal difficulty to 0
	)

	genesis_config_file_template_and_data = new_template_and_data(genesis_generation_config_template, template_data)

	template_and_data_by_rel_dest_filepath ={}
	template_and_data_by_rel_dest_filepath[GENESIS_CONFIG_FILENAME] = genesis_config_file_template_and_data

	genesis_generation_config_artifact_uuid = render_templates(template_and_data_by_rel_dest_filepath)


	# TODO Make this the actual data generator
	launcher_service_id = launch_prelaunch_data_generator(
		{
			genesis_generation_config_artifact_uuid: CONFIG_DIRPATH_ON_GENERATOR,
		},
	)

	# TODO defer remove the above generated service


	all_dirpaths_to_create_on_generator = [
		CONFIG_DIRPATH_ON_GENERATOR,
		OUTPUT_DIRPATH_ON_GENERATOR,
	]

	all_dirpath_creation_commands = []
	
	for dirpath_to_create_on_generator in all_dirpaths_to_create_on_generator:
		all_dirpath_creation_commands.append(
			"mkdir -p {0}".format(dirpath_to_create_on_generator),
		)


	dir_creation_cmd = [
		"bash",
		"-c",
		" && ".join(all_dirpath_creation_commands),
	]


	exec(launcher_service_id, dir_creation_cmd, SUCCESSFUL_EXEC_CMD_EXIT_CODE)

	genesis_config_filepath_on_generator = path_join(CONFIG_DIRPATH_ON_GENERATOR, GENESIS_CONFIG_FILENAME)
	genesis_filename_to_relative_filepath_in_artifact = map[string]string{}
	for output_filename, generation_cmd in all_genesis_generation_cmds.items():
		cmd = generation_cmd(genesis_config_filepath_on_generator)
		output_filepath_on_generator = path_join(OUTPUT_DIRPATH_ON_GENERATOR, output_filename)
		cmd.append(">", output_filepath_on_generator)
		cmd_to_execute = [
			"bash",
			"-c",
			" ".join(all_genesis_generation_cmds)
		]

		exec(launcher_service_id, cmd_to_execute, SUCCESSFUL_EXEC_CMD_EXIT_CODE)

		genesis_filename_to_relative_filepath_in_artifact[output_filename] = path_join(
			path_base(OUTPUT_DIRPATH_ON_GENERATOR),
			output_filename,
		)


	jwt_secret_filepath_on_generator = path_join(OUTPUT_DIRPATH_ON_GENERATOR, JWT_SECRET_FILENAME)
	jwt_secret_generation_cmd_args = [
		"bash",
		"-c",
		"openssl rand -hex 32 | tr -d \"\\n\" | sed 's/^/0x/' > {0}".format(
			jwt_secret_filepath_on_generator,
		)
	]

	exec(launcher_service_id, jwt_secret_filepath_on_generator, SUCCESSFUL_EXEC_CMD_EXIT_CODE)

	elGenesisDataArtifactUuid = store_files_from_service(launcher_service_id, OUTPUT_DIRPATH_ON_GENERATOR)

	result = new_el_genesis_data(
		elGenesisDataArtifactUuid,
		path_join(path_base(OUTPUT_DIRPATH_ON_GENERATOR), JWT_SECRET_FILENAME),
		genesis_filename_to_relative_filepath_in_artifact[GETH_GENESIS_FILENAME],
		genesis_filename_to_relative_filepath_in_artifact[ERIGON_GENESIS_FILENAME],
		genesis_filename_to_relative_filepath_in_artifact[NETHERMIND_GENESIS_FILENAME],
		genesis_filename_to_relative_filepath_in_artifact[BESU_GENESIS_FILENAME],
	)
	
	return result


def genesis_generation_config_template_data(network_id, deposit_contract_address, unix_timestamp, total_terminal_difficulty):
	return {
		"NetworkId": network_id,
		"DepositContractAddress": deposit_contract_address,
		"UnixTimestamp": unix_timestamp,
		"TotalTerminalDifficulty": total_terminal_difficulty,
	}