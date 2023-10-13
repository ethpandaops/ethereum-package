# The path on the module container where static files are housed
STATIC_FILES_DIRPATH = "/static_files"

# EL_CL Genesis config
EL_CL_GENESIS_GENERATION_CONFIG_TEMPLATE_FILEPATH = (
    STATIC_FILES_DIRPATH + "/genesis-generation-config/el-cl/values.env.tmpl"
)

# EL Forkmon config
EL_FORKMON_CONFIG_TEMPLATE_FILEPATH = (
    STATIC_FILES_DIRPATH + "/el-forkmon-config/config.toml.tmpl"
)

# Prometheus config
PROMETHEUS_CONFIG_TEMPLATE_FILEPATH = (
    STATIC_FILES_DIRPATH + "/prometheus-config/prometheus.yml.tmpl"
)

# Beacon Metrics Gazer config
BEACON_METRICS_GAZER_CONFIG_TEMPLATE_FILEPATH = (
    STATIC_FILES_DIRPATH + "/beacon-metrics-gazer-config/config.yaml.tmpl"
)

DORA_CONFIG_TEMPLATE_FILEPATH = STATIC_FILES_DIRPATH + "/dora-config/config.yaml.tmpl"

FULL_BEACONCHAIN_CONFIG_TEMPLATE_FILEPATH = (
    STATIC_FILES_DIRPATH + "/full-beaconchain-config/config.yaml.tmpl"
)

# Grafana config
GRAFANA_CONFIG_DIRPATH = "/grafana-config"
GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILEPATH = (
    STATIC_FILES_DIRPATH + GRAFANA_CONFIG_DIRPATH + "/templates/datasource.yml.tmpl"
)
GRAFANA_DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH = (
    STATIC_FILES_DIRPATH
    + GRAFANA_CONFIG_DIRPATH
    + "/templates/dashboard-providers.yml.tmpl"
)
GRAFANA_DASHBOARDS_CONFIG_DIRPATH = (
    STATIC_FILES_DIRPATH + GRAFANA_CONFIG_DIRPATH + "/dashboards"
)

# Geth + CL genesis generation
GENESIS_GENERATION_CONFIG_DIRPATH = STATIC_FILES_DIRPATH + "/genesis-generation-config"

EL_GENESIS_GENERATION_CONFIG_DIRPATH = GENESIS_GENERATION_CONFIG_DIRPATH + "/el"
EL_GENESIS_GENERATION_CONFIG_TEMPLATE_FILEPATH = (
    EL_GENESIS_GENERATION_CONFIG_DIRPATH + "/genesis-config.yaml.tmpl"
)

CL_GENESIS_GENERATION_CONFIG_DIRPATH = GENESIS_GENERATION_CONFIG_DIRPATH + "/cl"
CL_GENESIS_GENERATION_CONFIG_TEMPLATE_FILEPATH = (
    CL_GENESIS_GENERATION_CONFIG_DIRPATH + "/config.yaml.tmpl"
)
CL_GENESIS_GENERATION_MNEMONICS_TEMPLATE_FILEPATH = (
    CL_GENESIS_GENERATION_CONFIG_DIRPATH + "/mnemonics.yaml.tmpl"
)
