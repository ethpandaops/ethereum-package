parse_input = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/parse_input.star")

static_files = import_module("github.com/kurtosis-tech/eth2-package/src/static_files/static_files.star")
genesis_constants = import_module("github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/genesis_constants/genesis_constants.star")

eth_network_module = import_module("github.com/kurtosis-tech/eth-network-package/main.star")
transaction_spammer = import_module("github.com/kurtosis-tech/eth2-package/src/transaction_spammer/transaction_spammer.star")
forkmon = import_module("github.com/kurtosis-tech/eth2-package/src/forkmon/forkmon_launcher.star")
prometheus = import_module("github.com/kurtosis-tech/eth2-package/src/prometheus/prometheus_launcher.star")
grafana =import_module("github.com/kurtosis-tech/eth2-package/src/grafana/grafana_launcher.star")
testnet_verifier = import_module("github.com/kurtosis-tech/eth2-package/src/testnet_verifier/testnet_verifier.star")
mev_boost_launcher_module = import_module("github.com/kurtosis-tech/eth2-package/src/mev_boost/mev_boost_launcher.star")
mock_mev_launcher_module = import_module("github.com/kurtosis-tech/eth2-package/src/mock_mev/mock_mev_launcher.star")

GRAFANA_USER             = "admin"
GRAFANA_PASSWORD         = "admin"
GRAFANA_DASHBOARD_PATH_URL = "/d/QdTOwy-nz/eth2-merge-kurtosis-module-dashboard?orgId=1"

FIRST_NODE_FINALIZATION_FACT = "cl-boot-finalization-fact"
HTTP_PORT_ID_FOR_FACT = "http"

MEV_BOOST_SHOULD_CHECK_RELAY = True
MOCK_MEV_TYPE = "mock"

def run(plan, args):
	args_with_right_defaults, args_with_defaults_dict = parse_input.parse_input(args)

	num_participants = len(args_with_right_defaults.participants)
	network_params = args_with_right_defaults.network_params

	grafana_datasource_config_template = read_file(static_files.GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILEPATH)
	grafana_dashboards_config_template = read_file(static_files.GRAFANA_DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH)
	prometheus_config_template = read_file(static_files.PROMETHEUS_CONFIG_TEMPLATE_FILEPATH)

	plan.print("Read the prometheus, grafana templates")

	plan.print("Launching participant network with {0} participants and the following network params {1}".format(num_participants, network_params))
	all_participants, cl_genesis_timestamp = eth_network_module.run(plan, args_with_defaults_dict)

	all_el_client_contexts = []
	all_cl_client_contexts = []
	for participant in all_participants:
		all_el_client_contexts.append(participant.el_client_context)
		all_cl_client_contexts.append(participant.cl_client_context)


	mev_endpoints = []
	# passed external relays get priority
	# perhaps add mev_type External or remove this
	if hasattr(participant, "builder_network_params") and participant.builder_network_params != None:
		mev_endpoints = participant.builder_network_params.relay_end_points
	# otherwise dummy relays spinup if chosen
	elif args_with_right_defaults.mev_type and args_with_right_defaults.mev_type == MOCK_MEV_TYPE:
		el_uri = "{0}:{1}".format(all_el_client_contexts[0].ip_addr, all_el_client_contexts[0].engine_rpc_port_num)
		beacon_uri = "{0}:{1}".format(all_cl_client_contexts[0].ip_addr, all_cl_client_contexts[0].http_port_num)
		jwt_secret = all_el_client_contexts[0].jwt_secret
		endpoint = mock_mev_launcher_module.launch_mock_mev(plan, el_uri, beacon_uri, jwt_secret)
		mev_endpoints.append(endpoint)

	# spin up the mev boost contexts if some endpoints for relays have been passed
	all_mevboost_contexts = []	
	if mev_endpoints:
		for index, participant in enumerate(args_with_right_defaults.participants):
			mev_boost_launcher = mev_boost_launcher_module.new_mev_boost_launcher(MEV_BOOST_SHOULD_CHECK_RELAY, mev_endpoints)
			mev_boost_service_name = "{0}{1}".format(parse_input.MEV_BOOST_SERVICE_NAME_PREFIX, index)
			mev_boost_context = mev_boost_launcher_module.launch(plan, mev_boost_launcher, mev_boost_service_name, network_params.network_id)
			all_mevboost_contexts.append(mev_boost_context)

	if not args_with_right_defaults.launch_additional_services:
		return

	plan.print("Launching transaction spammer")
	transaction_spammer.launch_transaction_spammer(plan, genesis_constants.PRE_FUNDED_ACCOUNTS, all_el_client_contexts[0])
	plan.print("Succesfully launched transaction spammer")

	# We need a way to do time.sleep
	# TODO add code that waits for CL genesis

	plan.print("Launching forkmon")
	forkmon_config_template = read_file(static_files.FORKMON_CONFIG_TEMPLATE_FILEPATH)
	forkmon.launch_forkmon(plan, forkmon_config_template, all_cl_client_contexts, cl_genesis_timestamp, network_params.seconds_per_slot, network_params.slots_per_epoch)
	plan.print("Succesfully launched forkmon")

	plan.print("Launching prometheus...")
	prometheus_private_url = prometheus.launch_prometheus(
		plan,
		prometheus_config_template,
		all_cl_client_contexts,
	)
	plan.print("Successfully launched Prometheus")

	plan.print("Launching grafana...")
	grafana.launch_grafana(plan, grafana_datasource_config_template, grafana_dashboards_config_template, prometheus_private_url)
	plan.print("Succesfully launched grafana")

	if args_with_right_defaults.wait_for_verifications:
		plan.print("Running synchrnous testnet verifier")
		testnet_verifier.run_synchronous_testnet_verification(plan, args_with_right_defaults, all_el_client_contexts, all_cl_client_contexts)
		plan.print("Verification succeeded")
	else:
		plan.print("Running asynchronous verification")
		testnet_verifier.launch_testnet_verifier(plan, args_with_right_defaults, all_el_client_contexts, all_cl_client_contexts)
		plan.print("Succesfully launched asynchronous verifier")
		if args_with_right_defaults.wait_for_finalization:
			plan.print("Waiting for the first finalized epoch")
			first_cl_client = all_cl_client_contexts[0]
			first_client_beacon_name = first_cl_client.beacon_service_name
			epoch_recipe = GetHttpRequestRecipe(
				endpoint = "/eth/v1/beacon/states/head/finality_checkpoints",
				port_id = HTTP_PORT_ID_FOR_FACT,
				extract = {
					"finalized_epoch": ".data.finalized.epoch"
				}
			)
			plan.wait(recipe = epoch_recipe, field = "extract.finalized_epoch", assertion = "!=", target_value = "0", timeout = "40m", service_name = first_client_beacon_name)
			plan.print("First finalized epoch occurred successfully")


	grafana_info = struct(
		dashboard_path = GRAFANA_DASHBOARD_PATH_URL,
		user = GRAFANA_USER,
		password = GRAFANA_PASSWORD
	)
	output = struct(grafana_info = grafana_info)

	return output
