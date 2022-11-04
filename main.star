load("github.com/kurtosis-tech/eth2-module/src/participant_network/participant_network.star", "launch_participant_network")
module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

def main(input_args):
	print(input_args)
	print(input_args.wait_for_verifications)
	module_input = default_module_input()
	print(module_input)
	network_params = module_input.network_params
	num_participants = 2
	print("Launching participant network with {0} participants and the following network params {1}".format(num_participants, json.indent(json.encode(network_params))))
	launch_participant_network(num_participants, network_params)
	# TODO replace with actual values
	grafana_info = module_io.GrafanaInfo({
		"dashboard_path": "dummy_path",
		"user": "user",
		"password": "password"
	})
	output = module_io.ModuleOutput({"grafana_info": grafana_info})
	print(output)	
	return output


def default_module_input():
	network_params = default_network_params()
	participants = default_partitcipants()
	return module_io.ModuleInput({
		"participants": participants,
		"network_params": network_params,
		"launch_additional_services": True,
		"wait_for_finalization":      False,
		"wait_for_verifications":     False,
		"verifications_epoch_limit":  5,
		"global_log_level":           "info",

	})



def default_network_params():
	# this is temporary till we get params working
	return {
		"preregistered_validator_keys_mnemonic" :  "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete",
		"num_validators_per_keynode" : 64,
		"network_id" : "3151908",
		"deposit_contract_address" : "0x4242424242424242424242424242424242424242",
		"seconds_per_slot" : 12,
		"slots_per_epoch" : 32,
	}

def default_partitcipants():
	return [
		{
			"el_client_type": "geth",
			"el_client_image": "",
			"el_client_log_level": "",
			"cl_client_type": "lighthouse",
			"cl_client_image": "",
			"cl_client_log_level": ""
		}
	]
