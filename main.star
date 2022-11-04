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

default_cl_images = {
	"lighthouse": "sigp/lighthouse:latest",
	"teku":       "consensys/teku:latest",
	"nimbus":     "parithoshj/nimbus:merge-a845450",
	"prysm":    "gcr.io/prysmaticlabs/prysm/beacon-chain:latest,gcr.io/prysmaticlabs/prysm/validator:latest",
	"lodestar": "chainsafe/lodestar:next",	
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
		el_client_type = participant["el_client_type"]
		cl_client_type = participant["cl_client_type"]

		if index == 0 and el_client_type in ("besu", "nethermind"):
			fail("besu/nethermind cant be the first participant")
		
		el_image = participant["el_client_image"]
		if el_image == "":
			default_image = default_el_images.get(el_client_type, "")
			if default_image == "":
				fail("{0} received an empty image name and we don't have a default for it".format(el_client_type))
			participant["el_client_image"] = default_image

		cl_image = participant["cl_client_image"]
		if cl_image == "":
			default_image = default_cl_images.get(cl_client_type, "")
			if default_image == "":
				fail("{0} received an empty image name and we don't have a default for it".format(cl_client_type))
			participant["cl_client_image"] = default_image

		beacon_extra_params = participant.get("beacon_extra_params", [])
		participant["beacon_extra_params"] = beacon_extra_params

		validator_extra_params = participant.get("validator_extra_params", [])
		participant["validator_extra_params"] = validator_extra_params

	if result["network_params"]["network_id"].strip() == "":
		fail("network_id is empty or spaces it needs to be of non zero length")

	if result["network_params"]["deposit_contract_address"].strip() == "":
		fail("deposit_contract_address is empty or spaces it needs to be of non zero length")

	if result["network_params"]["preregistered_validator_keys_mnemonic"].strip() == "":
		fail("preregistered_validator_keys_mnemonic is empty or spaces it needs to be of non zero length")

	if result["network_params"]["slots_per_epoch"] == 0:
		fail("slots_per_epoch is 0 needs to be > 0 ")

	if result["network_params"]["seconds_per_slot"] == 0:
		fail("seconds_per_slot is 0 needs to be > 0 ")

	required_num_validtors = 2 * result["network_params"]["slots_per_epoch"]
	actual_num_validators = len(result["participants"]) * result["network_params"]["num_validators_per_keynode"]
	if required_num_validtors < actual_num_validators:
		fail("required_num_validtors - {0} is greater than actual_num_validators - {1}".format(required_num_validtors, actual_num_validators))

	# Remove if nethermind doesn't break as second node we already test above if its the first node
	if len(result["participants"]) >= 2 and result["participants"][1]["el_client_type"] == "nethermind":
		fail("nethermind can't be the first or second node")


	encoded_json = json.encode(result)
	print(json.indent(encoded_json))
	print(module_io.ModuleInput(result))
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
		"global_log_level": "info"
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
