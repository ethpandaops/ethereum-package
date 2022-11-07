DEFAULT_EL_IMAGES = {
	"geth": "ethereum/client-go:latest",
	"erigon": "thorax/erigon:devel",
	"nethermind": "nethermind/nethermind:latest",
	"besu": "hyperledger/besu:develop"
}

DEFAULT_CL_IMAGES = {
	"lighthouse": "sigp/lighthouse:latest",
	"teku":       "consensys/teku:latest",
	"nimbus":     "parithoshj/nimbus:merge-a845450",
	"prysm":    "gcr.io/prysmaticlabs/prysm/beacon-chain:latest,gcr.io/prysmaticlabs/prysm/validator:latest",
	"lodestar": "chainsafe/lodestar:next",	
}

BESU_NODE_NAME = "besu"
NETHERMIND_NODE_NAME = "nethermind"

LAUNCH_ADDITIONAL_ATTR = "launch_additional_services"

def parse_input(input_args):
	default_input = default_module_input()
	result = {}
	for attr in dir(input_args):
		value = getattr(input_args, attr)
		print(value, type(value), attr, type(attr))
		# this is a builtin attribute we don't care about
		if attr == "descriptor":
			continue
		# if there's an optional that exists don't change anything just move on
		elif attr == LAUNCH_ADDITIONAL_ATTR:
			if proto.has(input_args, LAUNCH_ADDITIONAL_ATTR):
				result[attr] = value
			else:
				result[attr] = default_input[attr]
		elif type(value) == "bool" and value == False:
			result[attr] = default_input[attr]
		elif type(value) == "int" and value == 0:
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

		if index == 0 and el_client_type in (BESU_NODE_NAME, NETHERMIND_NODE_NAME):
			fail("besu/nethermind cant be the first participant")
		
		el_image = participant["el_client_image"]
		if el_image == "":
			default_image = DEFAULT_EL_IMAGES.get(el_client_type, "")
			if default_image == "":
				fail("{0} received an empty image name and we don't have a default for it".format(el_client_type))
			participant["el_client_image"] = default_image

		cl_image = participant["cl_client_image"]
		if cl_image == "":
			default_image = DEFAULT_CL_IMAGES.get(cl_client_type, "")
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
	if len(result["participants"]) >= 2 and result["participants"][1]["el_client_type"] == NETHERMIND_NODE_NAME:
		fail("nethermind can't be the first or second node")


	encoded_json = json.encode(result)
	return result




def default_module_input():
	network_params = default_network_params()
	participants = default_partitcipants()
	return {
		"participants": participants,
		"network_params": network_params,
		LAUNCH_ADDITIONAL_ATTR: True,
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
