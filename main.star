load("github.com/kurtosis-tech/eth2-module/src/participant_network/participant_network.star", "launch_participant_network")
module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

def main(input_args):
	replace_with_defaults(input_args)
	num_participants = 2
	# print("Launching participant network with {0} participants and the following network params {1}".format(num_participants, json.indent(json.encode(network_params))))
	# launch_participant_network(num_participants, network_params)
	# TODO replace with actual values
	grafana_info = module_io.GrafanaInfo({
		"dashboard_path": "dummy_path",
		"user": "user",
		"password": "password"
	})
	output = module_io.ModuleOutput({"grafana_info": grafana_info})
	return output


default_el_images = {
	"geth": "ethereum/client-go:latest",
	"erigon": "thorax/erigon:devel",
	"nethermind": "nethermind/nethermind:latest",
	"besu": "hyperledger/besu:develop"
}

# TODO check enum values are valid or make sure protobfu does
def replace_with_defaults(input_args):
	default_input = default_module_input()
	result = {}
	for attr in dir(input_args):
		value = getattr(input_args, attr)
		if type(value) == "int" and value == 0:
			result[attr] = default_input[attr]
		elif type(value) == "string" and value == "":
			result[attr] = default_input[attr]
		elif attr == "network_params":
			result["network_params"] = {}
			for attr_ in dir(input_args.network_params):
				value_ = getattr(input_args.network_params, attr_)
				if type(value_) == "int" and value_ == 0:
					result["network_params"][attr_] = default_input["network_params"][attr_]
				elif type(value_) == "string" and value_ == "":
					result["network_params"][attr_] = default_input["network_params"][attr_]
				# if there are some string, int values we assign it
				elif type(value_) in ("int", "string", "bool"):
					result["network_params"][attr_] = value_
				elif type(value) in "proto.EnumValueDescriptor":
					result[attr] = value.name					
		# no participants are assigned at all
		elif attr == "participants" and len(value) == 0:
			result["participants"] = default_input["participants"]
		elif attr == "participants":
			participants = []
			for participant in input_args.participants:
				participant_value = {}
				for attr_ in dir(participant):
					value_ = getattr(participant, attr_)
					if type(attr_) == "int" and value_ == 0:
						participant_value[attr_] = getattr(default_input[participants][0], attr_, 0)
					elif type(attr_) == "str" and value_ == "":
						participant_value[attr_] = getattr(default_input[participants][0], attr_, "")
					elif type(value_) in ("int", "string", "bool"):
						result["participants"][attr_] = value_
					elif type(value_) in "proto.EnumValueDescriptor":
						participant_value[attr_] = value.name
				participants.append(participant_value)
			result["participants"] = participants
		# if there are some string, int values we assign it
		elif type(value) in ("int", "string", "bool"):
			result[attr] = value
		elif type(value) in "proto.EnumValueDescriptor":
			result[attr] = value.name

	for index, participant in enumerate(result["participants"]):
		# this is really ugly we need some primitive to throw an error
		if index == 0 and participant["el_client_type"] in ("besu", "nethermind"):
			fail("besu/nethermind cant be the first participant")		

	encoded_json = json.encode(result)
	print(json.indent(encoded_json))
	return result




def default_module_input():
	network_params = default_network_params()
	participants = default_partitcipants()
	return {
		"participants": participants,
		"network_params": network_params,
		"dont_launch_additional_services": False,
		"wait_for_finalization":      False,
		"wait_for_verifications":     False,
		"verifications_epoch_limit":  5,
		"global_log_level":           "info",

	}



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
	participant = {
			"el_client_type": "geth",
			"el_client_image": "",
			"el_client_log_level": "",
			"cl_client_type": "lighthouse",
			"cl_client_image": "",
			"cl_client_log_level": ""
	}
	return [participant]
