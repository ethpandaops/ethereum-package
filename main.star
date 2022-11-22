load("github.com/kurtosis-tech/eth2-module/src/participant_network/participant_network.star", "launch_participant_network")
load("github.com/kurtosis-tech/eth2-module/src/module_io/parse_input.star", "parse_input")

load("github.com/kurtosis-tech/eth2-module/src/static_files/static_files.star", "GRAFANA_DASHBOARDS_CONFIG_DIRPATH", "GRAFANA_DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH", "GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILEPATH", "PROMETHEUS_CONFIG_TEMPLATE_FILEPATH", "FORKMON_CONFIG_TEMPLATE_FILEPATH")
load("github.com/kurtosis-tech/eth2-module/src/participant_network/prelaunch_data_generator/genesis_constants/genesis_constants.star", "PRE_FUNDED_ACCOUNTS")

load("github.com/kurtosis-tech/eth2-module/src/transaction_spammer/transaction_spammer.star", "launch_transaction_spammer")
load("github.com/kurtosis-tech/eth2-module/src/forkmon/forkmon_launcher.star", "launch_forkmon")
load("github.com/kurtosis-tech/eth2-module/src/prometheus/prometheus_launcher.star", "launch_prometheus")
load("github.com/kurtosis-tech/eth2-module/src/grafana/grafana_launcher.star", "launch_grafana")
load("github.com/kurtosis-tech/eth2-module/src/testnet_verifier/testnet_verifier.star", "run_synchronous_testnet_verification", "launch_testnet_verifier")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

GRAFANA_USER             = "admin"
GRAFANA_PASSWORD         = "admin"
GRAFANA_DASHBOARD_PATH_URL = "/d/QdTOwy-nz/eth2-merge-kurtosis-module-dashboard?orgId=1"

FIRST_NODE_FINALIZATION_FACT = "cl-boot-finalization-fact"
HTTP_PORT_ID_FOR_FACT = "http"

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

	print("Launching prometheus...")
	prometheus_private_url = launch_prometheus(
		prometheus_config_template,
		all_cl_client_contexts,
	)
	print("Successfully launched Prometheus")

	print("Launching grafana...")
	launch_grafana(grafana_datasource_config_template, grafana_dashboards_config_template, prometheus_private_url)
	print("Succesfully launched grafana")

	if input_args_with_right_defaults.wait_for_verifications:
		print("Running synchrnous testnet verifier")
		run_synchronous_testnet_verification(input_args_with_right_defaults, all_el_client_contexts, all_cl_client_contexts)
		print("Verification succeeded")
	else:
		print("Running asynchronous verification")
		launch_testnet_verifier(input_args_with_right_defaults, all_el_client_contexts, all_cl_client_contexts)
		print("Succesfully launched asynchronous verifier")
		if input_args_with_right_defaults.wait_for_finalization:
			print("Waiting for the first finalized epoch")
			first_cl_client = all_cl_client_contexts[0]
			first_cl_client_id = first_cl_client.beacon_service_id
			define_fact(service_id = first_cl_client_id, fact_name = FIRST_NODE_FINALIZATION_FACT, fact_recipe = struct(method= "GET", endpoint = "/eth/v1/beacon/states/head/finality_checkpoints", content_type = "application/json", port_id = HTTP_PORT_ID_FOR_FACT, field_extractor = ".data.finalized.epoch"))
			finalized_epoch = wait(service_id = first_cl_client_id, fact_name = FIRST_NODE_FINALIZATION_FACT)
			# TODO make an assertion on the finalized_epoch > 0
			print("First finalized epoch occurred successfully")


	grafana_info = module_io.GrafanaInfo(
		dashboard_path = GRAFANA_DASHBOARD_PATH_URL,
		user = GRAFANA_USER,
		password = GRAFANA_PASSWORD
	)
	output = module_io.ModuleOutput(grafana_info = grafana_info)
	print(output)
	return output


