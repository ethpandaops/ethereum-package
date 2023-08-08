shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")


SERVICE_NAME = "beacon-metrics-gazer"
IMAGE_NAME = "dapplion/beacon-metrics-gazer:v0.1.3"

HTTP_PORT_ID     = "http"
HTTP_PORT_NUMBER = 8080

BEACON_METRICS_GAZER_CONFIG_FILENAME = "beacon-metrics-gazer-config.yaml"

BEACON_METRICS_GAZER_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/ranges.yaml"

USED_PORTS = {
	HTTP_PORT_ID:shared_utils.new_port_spec(HTTP_PORT_NUMBER, shared_utils.TCP_PROTOCOL, shared_utils.HTTP_APPLICATION_PROTOCOL)
}


def launch_beacon_metrics_gazer(
		plan,
		config_template,
		cl_client_contexts,
	):

	all_cl_client_info = []
	for client in cl_client_contexts:
		client_info = new_cl_client_info(client.beacon_service_name)
		all_cl_client_info.append(client_info)

	template_data = new_config_template_data(all_cl_client_info)

	template_and_data = shared_utils.new_template_and_data(config_template, template_data)
	template_and_data_by_rel_dest_filepath = {}
	template_and_data_by_rel_dest_filepath[BEACON_METRICS_GAZER_CONFIG_FILENAME] = template_and_data

	config_files_artifact_name = plan.render_templates(template_and_data_by_rel_dest_filepath, "beacon-metrics-gazer-config")

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
			"/ranges.yaml",
			"--port",
			"{0}".format(HTTP_PORT_NUMBER),
			"--address",
			"0.0.0.0"
		]
	)


def new_config_template_data(cl_client_info):
	return {
		"CLClientInfo": cl_client_info
	}


def new_cl_client_info(beacon_service_name):
	return {
		"beacon_service_name": beacon_service_name,
	}
