load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec", "new_template_and_data", "path_join", "path_base")

SERVICE_ID = "prometheus"

# TODO(old) I'm not sure if we should use latest version or ping an specific version instead
IMAGE_NAME = "prom/prometheus:latest"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 9090
HTTP_PORT_PROTOCOL = "TCP"

CONFIG_FILENAME = "prometheus-config.yml"

CONFIG_DIR_MOUNTPOINT_ON_PROMETHEUS = "/config"

USED_PORTS = {
	HTTP_PORT_ID: new_port_spec(HTTP_PORT_NUMBER, HTTP_PORT_PROTOCOL)
}


def launch_prometheus(config_template, cl_client_contexts):
	all_cl_nodes_metrics_info = []
	for client in cl_client_contexts:
		all_cl_nodes_metrics_info.extend(client.cl_nodes_metrics_info)

	template_data = new_config_template_data(all_cl_nodes_metrics_info)
	template_data_json = json.encode(template_data)

	template_and_data = new_template_and_data(config_template, template_data_json)
	template_and_data_by_rel_dest_filepath = {}
	template_and_data_by_rel_dest_filepath[CONFIG_FILENAME] = template_and_data

	config_files_artifact_uuid = render_templates(template_and_data_by_rel_dest_filepath)

	config = get_config(config_files_artifact_uuid)
	prometheus_service = add_service(SERVICE_ID, config)

	private_ip_address = prometheus_service.ip_address
	prometheus_service_http_port = prometheus_service.ports[HTTP_PORT_ID].number

	return "http://{0}:{1}".format(private_ip_address, prometheus_service_http_port)


def get_config(config_files_artifact_uuid):
	config_file_path = path_join(CONFIG_DIR_MOUNTPOINT_ON_PROMETHEUS, path_base(CONFIG_FILENAME))
	return struct(
		image = IMAGE_NAME,
		ports = USED_PORTS,
		files = {
			config_files_artifact_uuid : CONFIG_DIR_MOUNTPOINT_ON_PROMETHEUS
		},
		cmd = [
			# You can check all the cli flags starting the container and going to the flags section
			# in Prometheus admin page "{{prometheusPublicURL}}/flags" section
			"--config.file=" + config_file_path,
			"--storage.tsdb.path=/prometheus",
			"--storage.tsdb.retention.time=1d",
			"--storage.tsdb.retention.size=512MB",
			"--storage.tsdb.wal-compression",
			"--web.console.libraries=/etc/prometheus/console_libraries",
			"--web.console.templates=/etc/prometheus/consoles",
			"--web.enable-lifecycle",
		]
	)


def new_config_template_data(cl_nodes_metrics_info):
	return {
		"CLNodesMetricsInfo": cl_nodes_metrics_info
	}
