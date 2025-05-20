shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "grafana"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER_UINT16 = 3000

DATASOURCE_CONFIG_REL_FILEPATH = "datasources/datasource.yml"

# this is relative to the files artifact root
DASHBOARD_PROVIDERS_CONFIG_REL_FILEPATH = "dashboards/dashboard-providers.yml"

CONFIG_DIRPATH_ENV_VAR = "GF_PATHS_PROVISIONING"

GRAFANA_CONFIG_DIRPATH_ON_SERVICE = "/config"
GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE = "/dashboards"
GRAFANA_DASHBOARDS_FILEPATH_ON_SERVICE = GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE

GRAFANA_ADDITIONAL_DASHBOARDS_FOLDER_NAME = "grafana-additional-dashboards-{0}"
GRAFANA_ADDITIONAL_DASHBOARDS_MERGED_STORED_PATH_FORMAT = (
    GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE + "/*"
)
GRAFANA_ADDITIONAL_DASHBOARDS_FILEPATH_ON_SERVICE = "/additional-dashobards"
GRAFANA_ADDITIONAL_DASHBOARDS_FILEPATH_ON_SERVICE_FORMAT = (
    GRAFANA_ADDITIONAL_DASHBOARDS_FILEPATH_ON_SERVICE + "/{0}"
)
GRAFANA_ADDITIONAL_DASHBOARDS_SERVICE_PATH_KEY = "ServicePath"
GRANAFA_ADDITIONAL_DASHBOARDS_ARTIFACT_NAME_KEY = "ArtifactName"

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
    global_node_selectors,
    grafana_params,
    port_publisher,
    index,
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
        additional_dashboards=grafana_params.additional_dashboards,
    )

    merged_dashboards_artifact_name = merge_dashboards_artifacts(
        plan,
        grafana_dashboards_artifacts_uuid,
        grafana_additional_dashboards_data,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        HTTP_PORT_ID,
        index,
        1,
    )

    config = get_config(
        grafana_config_artifacts_uuid,
        merged_dashboards_artifact_name,
        global_node_selectors,
        grafana_params,
        public_ports,
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

    grafana_additional_dashboards_data = upload_additional_dashboards(
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
    node_selectors,
    grafana_params,
    public_ports,
):
    return ServiceConfig(
        image=grafana_params.image,
        ports=USED_PORTS,
        env_vars={
            CONFIG_DIRPATH_ENV_VAR: GRAFANA_CONFIG_DIRPATH_ON_SERVICE,
            "GF_AUTH_ANONYMOUS_ENABLED": "true",
            "GF_AUTH_ANONYMOUS_ORG_ROLE": "Admin",
            "GF_AUTH_ANONYMOUS_ORG_NAME": "Main Org.",
            "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH": "/dashboards/default.json",
        },
        files={
            GRAFANA_CONFIG_DIRPATH_ON_SERVICE: grafana_config_artifacts_name,
            GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE: grafana_dashboards_artifacts_name,
        },
        min_cpu=grafana_params.min_cpu,
        max_cpu=grafana_params.max_cpu,
        min_memory=grafana_params.min_mem,
        max_memory=grafana_params.max_mem,
        node_selectors=node_selectors,
        public_ports=public_ports,
    )


def new_datasource_config_template_data(prometheus_url):
    return {"PrometheusURL": prometheus_url}


def new_dashboard_providers_config_template_data(dashboards_dirpath):
    return {"DashboardsDirpath": dashboards_dirpath}


def upload_additional_dashboards(plan, additional_dashboards):
    data = []
    for index, dashboard_src in enumerate(additional_dashboards):
        additional_dashboard_folder_name = (
            GRAFANA_ADDITIONAL_DASHBOARDS_FOLDER_NAME.format(index)
        )
        additional_dashboard_service_path = (
            GRAFANA_ADDITIONAL_DASHBOARDS_FILEPATH_ON_SERVICE_FORMAT.format(
                additional_dashboard_folder_name,
            )
        )
        additional_dashboard_artifact_name = plan.upload_files(
            dashboard_src, name="additional-grafana-dashboard-{0}".format(index)
        )
        data.append(
            {
                GRAFANA_ADDITIONAL_DASHBOARDS_SERVICE_PATH_KEY: additional_dashboard_service_path,
                GRANAFA_ADDITIONAL_DASHBOARDS_ARTIFACT_NAME_KEY: additional_dashboard_artifact_name,
            }
        )
    return data


def merge_dashboards_artifacts(
    plan,
    grafana_dashboards_artifacts_name,
    grafana_additional_dashboards_data=[],
):
    if len(grafana_additional_dashboards_data) == 0:
        return grafana_dashboards_artifacts_name

    files = {
        GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE: grafana_dashboards_artifacts_name,
    }

    for additional_dashboard_data in grafana_additional_dashboards_data:
        files[
            additional_dashboard_data[GRAFANA_ADDITIONAL_DASHBOARDS_SERVICE_PATH_KEY]
        ] = additional_dashboard_data[GRANAFA_ADDITIONAL_DASHBOARDS_ARTIFACT_NAME_KEY]

    result = plan.run_sh(
        name="merge-grafana-dashboards",
        description="Merging grafana dashboards artifacts",
        run="find "
        + GRAFANA_ADDITIONAL_DASHBOARDS_FILEPATH_ON_SERVICE
        + " -type f -exec cp {} "
        + GRAFANA_DASHBOARDS_DIRPATH_ON_SERVICE
        + " \\;",
        files=files,
        store=[
            GRAFANA_ADDITIONAL_DASHBOARDS_MERGED_STORED_PATH_FORMAT,
        ],
    )

    return result.files_artifacts[0]
