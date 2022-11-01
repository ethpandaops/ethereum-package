load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/genesis_constants/genesis_constants.star", "PRE_FUNDED_ACCOUNTS")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/participant_network.star", "launch_participant_network")


def main():
	print("This should work if CI is running correctly")
	network_params = new_network_params()
	print("Launch participant network")
	launch_participant_network(network_params)

def new_network_params():
	# this is temporary till we get params working
	return struct(
		preregistered_validator_keys_mnemonic =  "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete",
		num_validator_keys_per_node = 64,
		network_id = "3151908",
		deposit_contract_address = "0x4242424242424242424242424242424242424242",
		seconds_per_slot = 12,
	)