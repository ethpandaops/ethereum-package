load("github.com/kurtosis-tech/eth2-merge-startosis-module/src/participant_network/prelaunch_data_generator/genesis_constants/genesis_constants.star", "PRE_FUNDED_ACCOUNTS")

def main():
	print("This should work if CI is running correctly")
	print(PRE_FUNDED_ACCOUNTS)