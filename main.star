load("github.com/kurtosis-tech/eth2-module/src/participant_network/participant_network.star", "launch_participant_network")


def main():
	network_params = new_network_params()
	num_participants = 2
	print("Launching participant network with {0} participants and the following network params {1}".format(num_participants, json.indent(json.encode(network_params))))
	launch_participant_network(num_participants, network_params)

def new_network_params():
	# this is temporary till we get params working
	return struct(
		preregistered_validator_keys_mnemonic =  "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete",
		num_validator_keys_per_node = 64,
		network_id = "3151908",
		deposit_contract_address = "0x4242424242424242424242424242424242424242",
		seconds_per_slot = 12,
		mev_boost_relay_endpoints = []
	)
