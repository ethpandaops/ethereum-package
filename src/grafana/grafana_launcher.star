load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec", "new_template_and_data", "path_join")


SERVICE_ID = "grafana"

IMAGE_NAME = "grafana/grafana-enterprise:9.2.3"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER_UINT16 = 3000
HTTP_PORT_PROTOCOL= "TCP"

DATASOURCE_CONFIG_REL_FILEPATH = "datasources/datasource.yml"

# this is relative to the files artifact root
DASHBOARD_PROVIDERS_CONFIG_REL_FILEPATH = "dashboards/dashboard-providers.yml"

CONFIG_DIRPATH_ENV_VAR = "GF_PATHS_PROVISIONING"

GRAFANA_CONFIG_DIRPATH_ON_SERVICE = "/config"
GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE = "/dashboards"
GRAFANA_DASHBOARDS_FILEPATH_ON_SERVICE = GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE + "/dashboard.json"

USED_PORTS = {
	HTTP_PORT_ID: new_port_spec(HTTP_PORT_NUMBER_UINT16, HTTP_PORT_PROTOCOL)
}


def launch_grafana(datasource_config_template, dashboard_providers_config_template, prometheus_private_url):	
	grafana_config_artifacts_uuid, grafana_dashboards_uuid = get_grafana_config_dir_artifact_uuid(datasource_config_template, dashboard_providers_config_template, prometheus_private_url)

	service_config = get_service_config(grafana_config_artifacts_uuid, grafana_dashboards_artifacts_uuid)

	add_service(SERVICE_ID, service_config)


def get_grafana_config_dir_artifact_uuid(datasource_config_template, dashboard_providers_config_template, prometheus_private_url):
	datasource_data = new_datasource_config_template_data(prometheus_private_url)
	datasource_data_as_json = json.encode(datasource_data)
	datasource_template_and_data = new_template_and_data(datasource_config_template, datasource_data_as_json)

	dashboard_providers_data = new_dashboard_providers_config_template_data(GRAFANA_DASHBOARDS_FILEPATH_ON_SERVICE)
	dashboard_providers_data_json = json.encode(dashboard_providers_data)
	dashboard_providers_template_and_data = new_template_and_data(dashboard_providers_config_template, dashboard_providers_data_json)

	template_and_data_by_rel_dest_filepath = {}
	template_and_data_by_rel_dest_filepath[DATASOURCE_CONFIG_REL_FILEPATH] = datasource_template_and_data
	template_and_data_by_rel_dest_filepath[DASHBOARD_PROVIDERS_CONFIG_REL_FILEPATH] = dashboard_providers_template_and_data

	grafana_config_artifacts_uuid = render_templates(template_and_data_by_rel_dest_filepath)

	# TODO return actual UUID after upload_files is implemented
	grafana_dashboards_artifacts_uuid = ""

	return grafana_config_artifacts_uuid, grafana_dashboards_artifacts_uuid


def new_datasource_config_template_data(prometheus_url):
	return {
		"PromtehusURL": prometheus_url
	}


def new_dashboard_providers_config_template_data(dashboards_dirpath):
	return {
		"DashboardsDirpath": dashboards_dirpath
	}
