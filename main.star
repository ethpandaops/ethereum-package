load("github.com/kurtosis-tech/eth2-module/src/participant_network/participant_network.star", "launch_participant_network")
load("github.com/kurtosis-tech/eth2-module/src/module_io/parse_input.star", "parse_input")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

def main(input_args):
	input_args_with_right_defaults = module_io.ModuleInput(parse_input(input_args))
	num_participants = len(input_args_with_right_defaults.participants)
	print("Launching participant network with {0} participants and the following network params {1}".format(num_participants, input_args_with_right_defaults.network_params))
	all_participants, cl_gensis_timestamp = launch_participant_network(input_args_with_right_defaults.participants, input_args_with_right_defaults.network_params, input_args_with_right_defaults.global_client_log_level)
	print(all_participants)
	print(cl_gensis_timestamp)
	grafana_info = module_io.GrafanaInfo(
		dashboard_path = "dummy_path",
		user = "user",
		password = "password"
	)
	output = module_io.ModuleOutput({"grafana_info": grafana_info})
	return output


