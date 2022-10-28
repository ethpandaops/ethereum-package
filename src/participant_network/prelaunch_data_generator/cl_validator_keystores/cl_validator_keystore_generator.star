load("github.com/kurtosis-tech/eth2-merge-startosis-module/src/participant_network/prelaunch_data_generator/prelaunch_data_generator_launcher", "launch_prelaunch_data_generator")
load("github.com/kurtosis-tech/eth2-merge-startosis-module/src/shared_utils/shared_utils.star", "path_join", "path_base")
load("github.com/kurtosis-tech/eth2-merge-startosis-module/src/participant_network/prelaunch_data_generator/cl_validator_keystores/keystore_files.star", "new_keystore_files")
load("github.com/kurtosis-tech/eth2-merge-startosis-module/src/participant_network/prelaunch_data_generator/cl_validator_keystores/generate_keystores_result.star", "new_generate_keystores_result")


NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR = "/node-{0}-keystores"

# Prysm keystores are encrypted with a password
PRYSM_PASSWORD                    = "password"
PRYSM_PASSWORD_FILEPATH_ON_GENERATOR = "/tmp/prysm-password.txt"

KEYSTORES_GENERATION_TOOL_NAME = "eth2-val-tools"

SUCCESSFUL_EXEC_CMD_EXIT_CODE = 0

RAW_KEYS_DIRNAME    = "keys"
RAW_SECRETS_DIRNAME = "secrets"

NIMBUS_KEYS_DIRNAME = "nimbus-keys"
PRYSM_DIRNAME      = "prysm"

TEKU_KEYS_DIRNAME    = "teku-keys"
TEKU_SECRETS_DIRNAME = "teku-secrets"


# Generates keystores for the given number of nodes from the given mnemonic, where each keystore contains approximately
#
#	num_keys / num_nodes keys
def generate_cl_validator_keystores(
	mnemonic,
	num_nodes,
	num_validators_per_node,
):
	service_id = launch_prelaunch_data_generator(
		{},
	)

	# TODO remove the service added above


	all_output_dirpaths = []
	all_sub_command_strs = []

	# TODO Parallelize this to increase perf, which will require Docker exec operations not holding the Kurtosis mutex!
	start_index = 0
	stop_index = num_validators_per_node

	for i in range(0, num_nodes):
		output_dirpath = NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(
			i,
		)

		generate_keystores_cmd = "{0} keystores --insecure --prysm-pass {1} --out-loc {2} --source-mnemonic \"{3}\" --source-min {4} --source-max {5}".format(
			KEYSTORES_GENERATION_TOOL_NAME,
			PRYSM_PASSWORD,
			output_dirpath,
			mnemonic,
			start_index,
			stop_index,
		)

		all_sub_command_strs.append(generate_keystores_cmd)
		all_output_dirpaths.append(output_dirpath)

		start_index = stop_index
		stop_index = stop_index + num_validators_per_node


	command_str = " && ".Join(all_sub_command_strs)

	exec(service_id, ["sh", "-c", command_str], SUCCESSFUL_EXEC_CMD_EXIT_CODE)

	# Store outputs into files artifacts
	keystore_files = []
	for idx, output_dirpath in enumerate(all_output_dirpaths):
		artifact_uuid = store_files_from_service(service_id, output_dirpath)

		# This is necessary because the way Kurtosis currently implements artifact-storing is
		base_dirname_in_artifact = path_base(output_dirpath)
		to_add = new_keystore_files(
			artifact_uuid,
			path_join(base_dirname_in_artifact, RAW_KEYS_DIRNAME),
			path_join(base_dirname_in_artifact, RAW_SECRETS_DIRNAME),
			path_join(base_dirname_in_artifact, NIMBUS_KEYS_DIRNAME),
			path_join(base_dirname_in_artifact, PRYSM_DIRNAME),
			path_join(base_dirname_in_artifact, TEKU_KEYS_DIRNAME),
			path_join(base_dirname_in_artifact, TEKU_SECRETS_DIRNAME),
		)

		keystore_files.append(to_add)


	write_prysm_password_file_cmd = [
		"sh",
		"-c",
		"echo '{0}' > {1}".format(
			prysmPassword,
			PRYSM_PASSWORD_FILEPATH_ON_GENERATOR,
		),
	]
	exec(service_id, write_prysm_password_file_cmd, SUCCESSFUL_EXEC_CMD_EXIT_CODE)

	prysm_password_artifact_uuid = store_files_from_service(service_id, PRYSM_PASSWORD_FILEPATH_ON_GENERATOR)

	result = new_generate_keystores_result(
		prysm_password_artifact_uuid,
		path_base(PRYSM_PASSWORD_FILEPATH_ON_GENERATOR),
		keystore_files,
	)

	return result