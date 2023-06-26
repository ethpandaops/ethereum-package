# The path on the module container where static files are housed
STATIC_FILES_DIRPATH = "github.com/kurtosis-tech/eth2-package/static_files"

# Forkmon config
FORKMON_CONFIG_TEMPLATE_FILEPATH = STATIC_FILES_DIRPATH + \
    "/forkmon-config/config.toml.tmpl"

# Prometheus config
PROMETHEUS_CONFIG_TEMPLATE_FILEPATH = STATIC_FILES_DIRPATH + \
    "/prometheus-config/prometheus.yml.tmpl"

# Grafana config
GRAFANA_CONFIG_DIRPATH = "/grafana-config"
GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILEPATH = STATIC_FILES_DIRPATH + \
    GRAFANA_CONFIG_DIRPATH + "/templates/datasource.yml.tmpl"
GRAFANA_DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH = STATIC_FILES_DIRPATH + \
    GRAFANA_CONFIG_DIRPATH + "/templates/dashboard-providers.yml.tmpl"
GRAFANA_DASHBOARDS_CONFIG_DIRPATH = STATIC_FILES_DIRPATH + \
    GRAFANA_CONFIG_DIRPATH + "/dashboards/dashboard.json"
