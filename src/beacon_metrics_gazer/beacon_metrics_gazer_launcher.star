shared_utils = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/shared_utils/shared_utils.star"
)
prometheus = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/prometheus/prometheus_launcher.star"
)

SERVICE_NAME = "beacon-metrics-gazer"
IMAGE_NAME = "ethpandaops/beacon-metrics-gazer:master"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 8080

METRICS_PATH = "/metrics"

VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"
VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE = "/validator-ranges.yaml"
BEACON_METRICS_GAZER_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_beacon_metrics_gazer(
    plan, config_template, cl_client_contexts, participants, network_params
):
    config = get_config(
        prelaunch_data_generator.validator_ranges_artifact_name,
        cl_client_contexts[0].ip_addr,
        cl_client_contexts[0].http_port_num,
    )

    beacon_metrics_gazer_service = plan.add_service(SERVICE_NAME, config)

    return prometheus.new_metrics_job(
        job_name=SERVICE_NAME,
        endpoint="{0}:{1}".format(
            beacon_metrics_gazer_service.ip_address, HTTP_PORT_NUMBER
        ),
        metrics_path=METRICS_PATH,
        labels={
            "service": SERVICE_NAME,
        },
    )


def get_config(ip_addr, http_port_num):
    config_file_path = shared_utils.path_join(
        BEACON_METRICS_GAZER_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        VALIDATOR_RANGES_CONFIG_FILENAME,
    )
    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        files={
            VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE: VALIDATOR_RANGES_ARTIFACT_NAME,
        },
        cmd=[
            "http://{0}:{1}".format(ip_addr, http_port_num),
            "--ranges-file",
            config_file_path,
            "--port",
            "{0}".format(HTTP_PORT_NUMBER),
            "--address",
            "0.0.0.0",
            "-v",
        ],
    )
