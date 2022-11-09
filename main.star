load("github.com/kurtosis-tech/eth2-module/src/participant_network/participant_network.star", "launch_participant_network")
load("github.com/kurtosis-tech/eth2-module/src/module_io/parse_input.star", "parse_input")

load("github.com/kurtosis-tech/eth2-module/src/static_files/static_files.star", "GRAFANA_DASHBOARDS_CONFIG_DIRPATH", "GRAFANA_DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH", "GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILEPATH", "PROMETHEUS_CONFIG_TEMPLATE_FILEPATH", "FORKMON_CONFIG_TEMPLATE_FILEPATH")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/genesis_constants/genesis_constants.star", "PRE_FUNDED_ACCOUNTS")

load("github.com/kurtosis-tech/eth2-module/src/transaction_spammer/transaction_spammer.star", "launch_transaction_spammer")
load("github.com/kurtosis-tech/eth2-module/src/forkmon/forkmon_launcher.star", "launch_forkmon")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

def main(input_args):
	input_args_with_right_defaults = module_io.ModuleInput(parse_input(input_args))
	num_participants = len(input_args_with_right_defaults.participants)
	network_params = input_args_with_right_defaults.network_params

	grafana_datasource_config_template = read_file(GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILEPATH)
	grafana_dashboards_config_template = read_file(GRAFANA_DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH)
	prometheus_config_template = read_file(PROMETHEUS_CONFIG_TEMPLATE_FILEPATH)

	print("Read the prometheus, grafana templates")

	print("Launching participant network with {0} participants and the following network params {1}".format(num_participants, network_params))
	all_participants, cl_gensis_timestamp = launch_participant_network(input_args_with_right_defaults.participants, network_params, input_args_with_right_defaults.global_client_log_level)

	print(all_participants)
	print(cl_gensis_timestamp)

	all_el_client_contexts = []
	all_cl_client_contexts = []
	for participant in all_participants:
		all_el_client_contexts.append(participant.el_client_context)
		all_cl_client_contexts.append(participant.cl_client_context)


	if not input_args_with_right_defaults.launch_additional_services:
		return

	print("Launching transaction spammer")
	launch_transaction_spammer(PRE_FUNDED_ACCOUNTS, all_el_client_contexts[0])
	print("Succesfully launched transaction spammer")

	# We need a way to do time.sleep
	# TODO add code that waits for CL genesis

	print("Launching forkmon")
	forkmon_config_template = read_file(FORKMON_CONFIG_TEMPLATE_FILEPATH)
	launch_forkmon(forkmon_config_template, all_cl_client_contexts, cl_gensis_timestamp, network_params.seconds_per_slot, network_params.slots_per_epoch)
	print("Succesfully launched forkmon")


	grafana_info = module_io.GrafanaInfo(
		dashboard_path = "dummy_path",
		user = "user",
		password = "password"
	)
	output = module_io.ModuleOutput({"grafana_info": grafana_info})
	return output


