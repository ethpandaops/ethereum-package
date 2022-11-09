load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/cl_validator_keystores/cl_validator_keystore_generator.star", "generate_cl_validator_keystores")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/el_genesis/el_genesis_data_generator.star", "generate_el_genesis_data")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/cl_genesis/cl_genesis_data_generator.star", "generate_cl_genesis_data")

load("github.com/kurtosis-tech/eth2-module/src/participant_network/mev_boost/mev_boost_context.star", "mev_boost_endpoint")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/mev_boost/mev_boost_launcher.star", launch_mevboost="launch", "new_mev_boost_launcher")

load("github.com/kurtosis-tech/eth2-module/src/static_files/static_files.star", "GETH_PREFUNDED_KEYS_DIRPATH")

load("github.com/kurtosis-tech/eth2-module/src/participant_network/el/geth/geth_launcher.star", launch_geth="launch", "new_geth_launcher")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/cl/lighthouse/lighthouse_launcher.star", launch_lighthouse="launch", "new_lighthouse_launcher")

load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/genesis_constants/genesis_constants.star", "PRE_FUNDED_ACCOUNTS")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/participant.star", "new_participant")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

CL_CLIENT_SERVICE_ID_PREFIX = "cl-client-"
EL_CLIENT_SERVICE_ID_PREFIX = "el-client-"
MEV_BOOST_SERVICE_ID_PREFIX = "mev-boost-"

BOOT_PARTICIPANT_INDEX = 0

# The time that the CL genesis generation step takes to complete, based off what we've seen
CL_GENESIS_DATA_GENERATION_TIME = 2 * time.minute

# Each CL node takes about this time to start up and start processing blocks, so when we create the CL
#  genesis data we need to set the genesis timestamp in the future so that nodes don't miss important slots
# (e.g. Altair fork)
# TODO Make this client-specific (currently this is Nimbus)
CL_NODE_STARTUP_TIME = 45 * time.second

MEV_BOOST_SHOULD_CHECK_RELAY = True


CL_CLIENT_CONTEXT_BOOTNODE = None

def launch_participant_network(participants, network_params, global_log_level):
	num_participants = len(participants)	
	el_genesis_timestamp = time.now().unix



	print("Generating cl validator key stores")	
	cl_validator_data = generate_cl_validator_keystores(
		network_params.preregistered_validator_keys_mnemonic,
		num_participants,
		network_params.num_validators_per_keynode
	)

	
	print(json.indent(json.encode(cl_validator_data)))

	print("Generating EL data")
	el_genesis_generation_config_template = read_file("github.com/kurtosis-tech/eth2-module/static_files/genesis-generation-config/el/genesis-config.yaml.tmpl")
	el_genesis_data = generate_el_genesis_data(
		el_genesis_generation_config_template,
		el_genesis_timestamp,
		network_params.network_id,
		network_params.deposit_contract_address
	)


	print(json.indent(json.encode(el_genesis_data)))

	print("Uploading GETH prefunded keys")

	geth_prefunded_keys_artifact_id = upload_files(GETH_PREFUNDED_KEYS_DIRPATH)

	print("Uploaded GETH files succesfully, launching EL participants")

	el_launchers = {
		# TODO Allow for other types here
		module_io.ELClientType.geth : {"launcher": new_geth_launcher(el_genesis_data, geth_prefunded_keys_artifact_id, PRE_FUNDED_ACCOUNTS, network_params.network_id), "launch_method": launch_geth}
	}

	all_el_client_contexts = []

	for index, participant in enumerate(participants):
		el_client_type = participant.el_client_type

		if el_client_type not in el_launchers:
			fail("Unsupported launcher '{0}', need one of '{1}'".format(el_client_type, ",".join(el_launchers.keys())))
		
		el_launcher, launch_method = el_launchers[el_client_type]["launcher"], el_launchers[el_client_type]["launch_method"]
		el_service_id = "{0}{1}".format(EL_CLIENT_SERVICE_ID_PREFIX, index)

		el_client_context = launch_method(el_launcher, el_service_id, participant.el_client_image, participant.el_client_log_level, global_log_level, all_el_client_contexts, participant.el_extra_params)

		all_el_client_contexts.append(el_client_context)

	print("Succesfully added {0} EL participants".format(num_participants))


	print("Generating CL data")

	# verify that this works
	cl_genesis_timestamp = (time.now() + CL_GENESIS_DATA_GENERATION_TIME + num_participants*CL_NODE_STARTUP_TIME).unix

	genesis_generation_config_yml_template = read_file("github.com/kurtosis-tech/eth2-module/static_files/genesis-generation-config/cl/config.yaml.tmpl")
	genesis_generation_mnemonics_yml_template = read_file("github.com/kurtosis-tech/eth2-module/static_files/genesis-generation-config/cl/mnemonics.yaml.tmpl")
	total_number_of_validator_keys = network_params.num_validators_per_keynode * num_participants
	cl_genesis_data = generate_cl_genesis_data(
		genesis_generation_config_yml_template,
		genesis_generation_mnemonics_yml_template,
		el_genesis_data,
		cl_genesis_timestamp,
		network_params.network_id,
		network_params.deposit_contract_address,
		network_params.seconds_per_slot,
		network_params.preregistered_validator_keys_mnemonic,
		total_number_of_validator_keys

	)

	print(json.indent(json.encode(cl_genesis_data)))

	print("Launching CL network")

	cl_launchers = {
		# TODO Allow for other types here
		module_io.CLClientType.lighthouse : {"launcher": new_lighthouse_launcher(cl_genesis_data), "launch_method": launch_lighthouse}
	}

	all_cl_client_contexts = []
	all_mevboost_contexts = []
	preregistered_validator_keys_for_nodes = cl_validator_data.per_node_keystores

	for index, participant in enumerate(participants):
		cl_client_type = participant.cl_client_type

		if cl_client_type not in cl_launchers:
			fail("Unsupported launcher '{0}', need one of '{1}'".format(cl_client_type, ",".join(cl_launchers.keys())))
		
		cl_launcher, launch_method = cl_launchers[cl_client_type]["launcher"], cl_launchers[cl_client_type]["launch_method"]
		cl_service_id = "{0}{1}".format(CL_CLIENT_SERVICE_ID_PREFIX, index)

		new_cl_node_validator_keystores = preregistered_validator_keys_for_nodes[index]

		el_client_context = all_el_client_contexts[index]

		mev_boost_context = None

		if proto.has(participant, "builder_network_params"):
			mev_boost_launcher = new_mev_boost_launcher(MEV_BOOST_SHOULD_CHECK_RELAY, participant.builder_network_params.relay_endpoints)
			mev_boost_service_id = MEV_BOOST_SERVICE_ID_PREFIX.format(1)
			mev_boost_context = launch_mevboost(mev_boost_launcher, mev_boost_service_id, network_params.network_id)

		all_mevboost_contexts.append(mev_boost_context)

		cl_client_context = None

		if index == 0:
			cl_client_context = launch_method(cl_launcher, cl_service_id, participant.cl_client_image, participant.cl_client_log_level, global_log_level, CL_CLIENT_CONTEXT_BOOTNODE,
              el_client_context, mev_boost_context, new_cl_node_validator_keystores, participant.beacon_extra_params, participant.validator_extra_params)
		else:
			boot_cl_client_ctx = all_cl_client_contexts[0]
			cl_client_context = launch_method(cl_launcher, cl_service_id, participant.cl_client_image, participant.cl_client_log_level, global_log_level, boot_cl_client_ctx,
              el_client_context, mev_boost_context, new_cl_node_validator_keystores, participant.beacon_extra_params, participant.validator_extra_params)

		all_cl_client_contexts.append(el_client_context)

	all_participants = []

	for index, participant in participants:
		el_client_type = participant.el_client_type
		cl_client_type = participant.cl_client_type

		el_client_context = all_el_client_contexts[index]
		cl_client_context = all_cl_client_contexts[index]
		mev_boost_context = all_mevboost_contexts[index]

		participant_entry = new_participant(el_client_type, cl_client_type, el_client_context, cl_client_context, mev_boost_context)

		all_participants.append(participant_entry)


	return all_participants, cl_genesis_timestamp

