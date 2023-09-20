shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")

SERVICE_NAME = "prometheus"

# TODO(old) I'm not sure if we should use latest version or ping an specific version instead
IMAGE_NAME = "prom/prometheus:latest"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 9090
CONFIG_FILENAME = "prometheus-config.yml"

CONFIG_DIR_MOUNTPOINT_ON_PROMETHEUS = "/config"

USED_PORTS = {
	HTTP_PORT_ID: shared_utils.new_port_spec(HTTP_PORT_NUMBER, shared_utils.TCP_PROTOCOL, shared_utils.HTTP_APPLICATION_PROTOCOL)
}

def launch_prometheus(plan, config_template, cl_client_contexts, el_client_contexts):
	all_nodes_metrics_info = []
	for client in cl_client_contexts:
		all_nodes_metrics_info.extend(client.cl_nodes_metrics_info)

	for client in el_client_contexts:
		all_nodes_metrics_info.extend(client.el_metrics_info)

	template_data = new_config_template_data(all_nodes_metrics_info)
	template_and_data = shared_utils.new_template_and_data(config_template, template_data)
	template_and_data_by_rel_dest_filepath = {}
	template_and_data_by_rel_dest_filepath[CONFIG_FILENAME] = template_and_data

	config_files_artifact_name = plan.render_templates(template_and_data_by_rel_dest_filepath, "prometheus-config")

	config = get_config(config_files_artifact_name)
	prometheus_service = plan.add_service(SERVICE_NAME, config)

	private_ip_address = prometheus_service.ip_address
	prometheus_service_http_port = prometheus_service.ports[HTTP_PORT_ID].number

	return "http://{0}:{1}".format(private_ip_address, prometheus_service_http_port)


def get_config(config_files_artifact_name):
	config_file_path = shared_utils.path_join(CONFIG_DIR_MOUNTPOINT_ON_PROMETHEUS, shared_utils.path_base(CONFIG_FILENAME))
	return ServiceConfig(
		image = IMAGE_NAME,
		ports = USED_PORTS,
		files = {
			CONFIG_DIR_MOUNTPOINT_ON_PROMETHEUS: config_files_artifact_name
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
