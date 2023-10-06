shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")

SERVICE_NAME = "grafana"

IMAGE_NAME = "grafana/grafana-enterprise:latest"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER_UINT16 = 3000

DATASOURCE_CONFIG_REL_FILEPATH = "datasources/datasource.yml"

# this is relative to the files artifact root
DASHBOARD_PROVIDERS_CONFIG_REL_FILEPATH = "dashboards/dashboard-providers.yml"

CONFIG_DIRPATH_ENV_VAR = "GF_PATHS_PROVISIONING"

GRAFANA_CONFIG_DIRPATH_ON_SERVICE = "/config"
GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE = "/dashboards"
GRAFANA_DASHBOARDS_FILEPATH_ON_SERVICE = GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE

GRAFANA_ADDITIONAL_DASHBOARDS_NAME = "grafana-additional-dashboard"
GRAFANA_ADDITIONAL_SERVICE_PATH = "ServicePath"
GRAFANA_ADDITIONAL_ARTIFACT_NAME = "ArtifactName"

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER_UINT16,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_grafana(
    plan,
    datasource_config_template,
    dashboard_providers_config_template,
    prometheus_private_url,
    additional_dashboards=[],
):
    (
        grafana_config_artifacts_uuid,
        grafana_dashboards_artifacts_uuid,
        grafana_additional_dashboards_data,
    ) = get_grafana_config_dir_artifact_uuid(
        plan,
        datasource_config_template,
        dashboard_providers_config_template,
        prometheus_private_url,
        additional_dashboards=additional_dashboards,
    )

    config = get_config(
        grafana_config_artifacts_uuid,
        grafana_dashboards_artifacts_uuid,
        grafana_additional_dashboards_data=grafana_additional_dashboards_data,
    )

    plan.add_service(SERVICE_NAME, config)


def get_grafana_config_dir_artifact_uuid(
    plan,
    datasource_config_template,
    dashboard_providers_config_template,
    prometheus_private_url,
    additional_dashboards=[],
):
    datasource_data = new_datasource_config_template_data(prometheus_private_url)
    datasource_template_and_data = shared_utils.new_template_and_data(
        datasource_config_template, datasource_data
    )

    dashboard_providers_data = new_dashboard_providers_config_template_data(
        GRAFANA_DASHBOARDS_FILEPATH_ON_SERVICE
    )
    dashboard_providers_template_and_data = shared_utils.new_template_and_data(
        dashboard_providers_config_template, dashboard_providers_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        DATASOURCE_CONFIG_REL_FILEPATH
    ] = datasource_template_and_data
    template_and_data_by_rel_dest_filepath[
        DASHBOARD_PROVIDERS_CONFIG_REL_FILEPATH
    ] = dashboard_providers_template_and_data

    grafana_config_artifacts_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, name="grafana-config"
    )

    grafana_dashboards_artifacts_name = plan.upload_files(
        static_files.GRAFANA_DASHBOARDS_CONFIG_DIRPATH, name="grafana-dashboards"
    )

    grafana_additional_dashboards_data = new_additional_dashboards_data(
        plan, additional_dashboards
    )

    return (
        grafana_config_artifacts_name,
        grafana_dashboards_artifacts_name,
        grafana_additional_dashboards_data,
    )


def get_config(
    grafana_config_artifacts_name,
    grafana_dashboards_artifacts_name,
    grafana_additional_dashboards_data=[],
):
    files = {
        GRAFANA_CONFIG_DIRPATH_ON_SERVICE: grafana_config_artifacts_name,
        GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE: grafana_dashboards_artifacts_name,
    }
    for additional_dashboard_data in grafana_additional_dashboards_data:
        files[
            additional_dashboard_data[GRAFANA_ADDITIONAL_SERVICE_PATH]
        ] = additional_dashboard_data[GRAFANA_ADDITIONAL_ARTIFACT_NAME]

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        env_vars={
            CONFIG_DIRPATH_ENV_VAR: GRAFANA_CONFIG_DIRPATH_ON_SERVICE,
            "GF_AUTH_ANONYMOUS_ENABLED": "true",
            "GF_AUTH_ANONYMOUS_ORG_ROLE": "Admin",
            "GF_AUTH_ANONYMOUS_ORG_NAME": "Main Org.",
            "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH": "/dashboards/default.json",
        },
        files=files,
    )


def new_datasource_config_template_data(prometheus_url):
    return {"PrometheusURL": prometheus_url}


def new_dashboard_providers_config_template_data(dashboards_dirpath):
    return {"DashboardsDirpath": dashboards_dirpath}


def new_additional_dashboards_data(plan, additional_dashboards):
    data = []
    for index, dashboard_src in enumerate(additional_dashboards):
        additional_dashboard_name = "{}-{}".format(
            GRAFANA_ADDITIONAL_DASHBOARDS_NAME,
            index,
        )
        additional_dashboard_service_path = "{}/{}.json".format(
            GRAFANA_DASHBOARDS_FILEPATH_ON_SERVICE,
            additional_dashboard_name,
        )
        additional_dashboard_artifact_name = plan.upload_files(
            dashboard_src,
            name=additional_dashboard_name,
        )
        data.append(
            {
                GRAFANA_ADDITIONAL_SERVICE_PATH: additional_dashboard_service_path,
                GRAFANA_ADDITIONAL_ARTIFACT_NAME: additional_dashboard_artifact_name,
            }
        )
    return data
