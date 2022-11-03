load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/cl_validator_keystores/cl_validator_keystore_generator.star", "generate_cl_validator_keystores")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/el_genesis/el_genesis_data_generator.star", "generate_el_genesis_data")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/cl_genesis/cl_genesis_data_generator.star", "generate_cl_genesis_data")

load("github.com/kurtosis-tech/eth2-module/src/participant_network/mev_boost/mev_boost_context.star", "mev_boost_endpoint")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/mev_boost/mev_boost_launcher.star", launch_mevboost="launch", "new_mev_boost_launcher")


MEV_BOOST_SERVICE_ID_PREFIX = "mev-boost-"
MEV_BOOST_SHOULD_RELAY = True

def launch_participant_network(num_participants, network_params):

	print("Generating cl validator key stores")	
	keystore_result = generate_cl_validator_keystores(
		network_params.preregistered_validator_keys_mnemonic,
		num_participants,
		network_params.num_validator_keys_per_node
	)

	
	print(json.indent(json.encode(keystore_result)))

	genesis_timestamp = time.now().unix

	print("Generating EL data")
	el_genesis_generation_config_template = read_file("github.com/kurtosis-tech/eth2-module/static_files/genesis-generation-config/el/genesis-config.yaml.tmpl")
	el_genesis_data = generate_el_genesis_data(
		el_genesis_generation_config_template,
		genesis_timestamp,
		network_params.network_id,
		network_params.deposit_contract_address
	)


	print(json.indent(json.encode(el_genesis_data)))

	print("Generating CL data")
	genesis_generation_config_yml_template = read_file("github.com/kurtosis-tech/eth2-module/static_files/genesis-generation-config/cl/config.yaml.tmpl")
	genesis_generation_mnemonics_yml_template = read_file("github.com/kurtosis-tech/eth2-module/static_files/genesis-generation-config/cl/mnemonics.yaml.tmpl")
	total_number_of_validator_keys = network_params.num_validator_keys_per_node * num_participants
	cl_data = generate_cl_genesis_data(
		genesis_generation_config_yml_template,
		genesis_generation_mnemonics_yml_template,
		el_genesis_data,
		genesis_timestamp,
		network_params.network_id,
		network_params.deposit_contract_address,
		network_params.seconds_per_slot,
		network_params.preregistered_validator_keys_mnemonic,
		total_number_of_validator_keys

	)

	print(json.indent(json.encode(cl_data)))

	print("launching mev boost")
	# TODO make this launch only for participants that have the participants[i].builderNetworkParams.relayEndpoints defined
	# At the moment this lies here just to test, and the relay end points is an empty list
	mev_boost_launcher = new_mev_boost_launcher(MEV_BOOST_SHOULD_RELAY, network_params.mev_boost_relay_endpoints)
	mev_boost_service_id = MEV_BOOST_SERVICE_ID_PREFIX.format(1)
	mev_boost_context = launch_mevboost(mev_boost_launcher, mev_boost_service_id, network_params.network_id)
	print(mev_boost_endpoint(mev_boost_context))
