shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")
static_files = import_module("github.com/kurtosis-tech/eth2-package/src/static_files/static_files.star")

SERVICE_NAME = "grafana"

IMAGE_NAME = "grafana/grafana-enterprise:9.2.3"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER_UINT16 = 3000

DATASOURCE_CONFIG_REL_FILEPATH = "datasources/datasource.yml"

# this is relative to the files artifact root
DASHBOARD_PROVIDERS_CONFIG_REL_FILEPATH = "dashboards/dashboard-providers.yml"

CONFIG_DIRPATH_ENV_VAR = "GF_PATHS_PROVISIONING"

GRAFANA_CONFIG_DIRPATH_ON_SERVICE = "/config"
GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE = "/dashboards"
GRAFANA_DASHBOARDS_FILEPATH_ON_SERVICE = GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE + "/dashboard.json"


USED_PORTS = {
	HTTP_PORT_ID: shared_utils.new_port_spec(HTTP_PORT_NUMBER_UINT16, shared_utils.TCP_PROTOCOL,  shared_utils.HTTP_APPLICATION_PROTOCOL)
}


def launch_grafana(plan, datasource_config_template, dashboard_providers_config_template, prometheus_private_url):	
	grafana_config_artifacts_uuid, grafana_dashboards_artifacts_uuid = get_grafana_config_dir_artifact_uuid(plan, datasource_config_template, dashboard_providers_config_template, prometheus_private_url)

	config = get_config(grafana_config_artifacts_uuid, grafana_dashboards_artifacts_uuid)

	plan.add_service(SERVICE_NAME, config)


def get_grafana_config_dir_artifact_uuid(plan, datasource_config_template, dashboard_providers_config_template, prometheus_private_url):
	datasource_data = new_datasource_config_template_data(prometheus_private_url)
	datasource_template_and_data = shared_utils.new_template_and_data(datasource_config_template, datasource_data)

	dashboard_providers_data = new_dashboard_providers_config_template_data(GRAFANA_DASHBOARDS_FILEPATH_ON_SERVICE)
	dashboard_providers_template_and_data = shared_utils.new_template_and_data(dashboard_providers_config_template, dashboard_providers_data)

	template_and_data_by_rel_dest_filepath = {}
	template_and_data_by_rel_dest_filepath[DATASOURCE_CONFIG_REL_FILEPATH] = datasource_template_and_data
	template_and_data_by_rel_dest_filepath[DASHBOARD_PROVIDERS_CONFIG_REL_FILEPATH] = dashboard_providers_template_and_data

	grafana_config_artifacts_name = plan.render_templates(template_and_data_by_rel_dest_filepath, name="grafana-config")

	grafana_dashboards_artifacts_name = plan.upload_files(static_files.GRAFANA_DASHBOARDS_CONFIG_DIRPATH, name="grafana-dashboards")

	return grafana_config_artifacts_name, grafana_dashboards_artifacts_name


def get_config(grafana_config_artifacts_name, grafana_dashboards_artifacts_name):
	return ServiceConfig(
		image = IMAGE_NAME,
		ports = USED_PORTS,
		env_vars = {CONFIG_DIRPATH_ENV_VAR: GRAFANA_CONFIG_DIRPATH_ON_SERVICE},
		files = {
			GRAFANA_CONFIG_DIRPATH_ON_SERVICE: grafana_config_artifacts_name,
			GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE: grafana_dashboards_artifacts_name
		}
	)


def new_datasource_config_template_data(prometheus_url):
	return {
		"PrometheusURL": prometheus_url
	}


def new_dashboard_providers_config_template_data(dashboards_dirpath):
	return {
		"DashboardsDirpath": dashboards_dirpath
	}
