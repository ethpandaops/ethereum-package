load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/cl_validator_keystores/cl_validator_keystore_generator.star", "generate_cl_validator_keystores")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/el_genesis/el_genesis_data_generator.star", "generate_el_genesis_data")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/cl_genesis/cl_genesis_data_generator.star", "generate_cl_genesis_data")

def launch_participant_network(network_params):
	num_participants = 2

	print("Generating cl validator key stores")	
	keystore_result = generate_cl_validator_keystores(
		network_params.preregistered_validator_keys_mnemonic,
		num_participants,
		network_params.num_validator_keys_per_node
	)

	pritn("Success " + keystore_result)

	genesis_timestamp = time.unix()

	print("Generating EL data")
	el_genesis_generation_config_template = read_file("github.com/kurtosis-tech/eth2-module/static_files/genesis-generation-config/el/genesis-config.yaml.tmpl")
	el_genesis_data = generate_el_genesis_data(
		el_genesis_generation_config_template,
		genesis_timestamp,
		network_params.network_id,
		network_params.deposit_contract_address
	)

	print("Success " + el_result)


	print("Generating CL data")
	genesis_generation_config_yml_template = read_file("github.com/kurtosis-tech/eth2-module/static_files/genesis-generation-config/cl/config.yaml.tmpl")
	genesis_generation_mnemonics_yml_template = read_file("github.com/kurtosis-tech/eth2-module/static_files/genesis-generation-config/cl/mnemonics.yaml.tmpl")
	genesis_timestamp = time.unix()
	totalNumberOfValidatorKeys = network_params.num_validator_keys_per_node * num_participants
	cl_data = generate_cl_genesis_data(
		genesis_generation_config_yml_template,
		genesis_generation_mnemonics_yml_template,
		el_genesis_data,
		genesis_timestamp,
		network_params.network_id,
		network_params.deposit_contract_address,
		network_params.seconds_per_slot,
		network_params.preregistered_validator_keys_mnemonic,

	)

	print("Success " + cl_data)
