shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")


SERVICE_NAME = "beacon-metrics-gazer"
IMAGE_NAME = "dapplion/beacon-metrics-gazer:latest"

HTTP_PORT_ID     = "http"
HTTP_PORT_NUMBER = 8080

BEACON_METRICS_GAZER_CONFIG_FILENAME = "validator-ranges.yaml"

BEACON_METRICS_GAZER_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

USED_PORTS = {
	HTTP_PORT_ID:shared_utils.new_port_spec(HTTP_PORT_NUMBER, shared_utils.TCP_PROTOCOL, shared_utils.HTTP_APPLICATION_PROTOCOL)
}


def launch_beacon_metrics_gazer(
		plan,
		config_template,
		cl_client_contexts,
		network_params
	):

	data = []
	for index, client in enumerate(cl_client_contexts):
		start_index = index*network_params.num_validator_keys_per_node
		end_index = ((index+1)*network_params.num_validator_keys_per_node)-1
		service_name = client.beacon_service_name
		data.append({"ClientName": service_name, "Range": "{0}-{1}".format(start_index, end_index)})

	template_data = {"Data": data}

	template_and_data_by_rel_dest_filepath = {}
	template_and_data_by_rel_dest_filepath[BEACON_METRICS_GAZER_CONFIG_FILENAME] = shared_utils.new_template_and_data(config_template, template_data)

	config_files_artifact_name = plan.render_templates(template_and_data_by_rel_dest_filepath, "validator-ranges")

	config = get_config(
		config_files_artifact_name,
		cl_client_contexts[0].ip_addr,
		cl_client_contexts[0].http_port_num)

	plan.add_service(SERVICE_NAME, config)


def get_config(
	config_files_artifact_name,
	ip_addr,
	http_port_num):
	config_file_path = shared_utils.path_join(BEACON_METRICS_GAZER_CONFIG_MOUNT_DIRPATH_ON_SERVICE, BEACON_METRICS_GAZER_CONFIG_FILENAME)
	return ServiceConfig(
		image = IMAGE_NAME,
		ports = USED_PORTS,
		files = {
			BEACON_METRICS_GAZER_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
		},
		cmd = [
			"http://{0}:{1}".format(ip_addr, http_port_num),
			"--ranges-file",
			config_file_path,
			"--port",
			"{0}".format(HTTP_PORT_NUMBER),
			"--address",
			"0.0.0.0",
			"-v"
		]
	)
