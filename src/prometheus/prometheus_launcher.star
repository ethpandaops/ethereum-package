shared_utils = import_module("../shared_utils/shared_utils.star")

SERVICE_NAME = "prometheus"

EXECUTION_CLIENT_TYPE = "execution"
BEACON_CLIENT_TYPE = "beacon"
VALIDATOR_CLIENT_TYPE = "validator"

METRICS_INFO_NAME_KEY = "name"
METRICS_INFO_URL_KEY = "url"
METRICS_INFO_PATH_KEY = "path"

# TODO(old) I'm not sure if we should use latest version or ping an specific version instead
IMAGE_NAME = "prom/prometheus:latest"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 9090
CONFIG_FILENAME = "prometheus-config.yml"

CONFIG_DIR_MOUNTPOINT_ON_PROMETHEUS = "/config"

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_prometheus(
    plan,
    config_template,
    el_client_contexts,
    cl_client_contexts,
    additional_metrics_jobs,
):
    template_data = new_config_template_data(
        el_client_contexts,
        cl_client_contexts,
        additional_metrics_jobs,
    )
    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "prometheus-config"
    )

    config = get_config(config_files_artifact_name)
    prometheus_service = plan.add_service(SERVICE_NAME, config)

    private_ip_address = prometheus_service.ip_address
    prometheus_service_http_port = prometheus_service.ports[HTTP_PORT_ID].number

    return "http://{0}:{1}".format(private_ip_address, prometheus_service_http_port)


def get_config(config_files_artifact_name):
    config_file_path = shared_utils.path_join(
        CONFIG_DIR_MOUNTPOINT_ON_PROMETHEUS, shared_utils.path_base(CONFIG_FILENAME)
    )
    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        files={CONFIG_DIR_MOUNTPOINT_ON_PROMETHEUS: config_files_artifact_name},
        cmd=[
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
        ],
    )


def new_config_template_data(
    el_client_contexts,
    cl_client_contexts,
    additional_metrics_jobs,
):
    metrics_jobs = []
    # Adding execution clients metrics jobs
    for context in el_client_contexts:
        if len(context.el_metrics_info) >= 1 and context.el_metrics_info[0] != None:
            execution_metrics_info = context.el_metrics_info[0]
            metrics_jobs.append(
                new_metrics_job(
                    job_name=execution_metrics_info[METRICS_INFO_NAME_KEY],
                    endpoint=execution_metrics_info[METRICS_INFO_URL_KEY],
                    metrics_path=execution_metrics_info[METRICS_INFO_PATH_KEY],
                    labels={
                        "service": context.service_name,
                        "client_type": EXECUTION_CLIENT_TYPE,
                        "client_name": context.client_name,
                    },
                )
            )
    # Adding consensus clients metrics jobs
    for context in cl_client_contexts:
        if (
            len(context.cl_nodes_metrics_info) >= 1
            and context.cl_nodes_metrics_info[0] != None
        ):
            # Adding beacon node metrics
            beacon_metrics_info = context.cl_nodes_metrics_info[0]
            metrics_jobs.append(
                new_metrics_job(
                    job_name=beacon_metrics_info[METRICS_INFO_NAME_KEY],
                    endpoint=beacon_metrics_info[METRICS_INFO_URL_KEY],
                    metrics_path=beacon_metrics_info[METRICS_INFO_PATH_KEY],
                    labels={
                        "service": context.beacon_service_name,
                        "client_type": BEACON_CLIENT_TYPE,
                        "client_name": context.client_name,
                    },
                )
            )
        if (
            len(context.cl_nodes_metrics_info) >= 2
            and context.cl_nodes_metrics_info[1] != None
        ):
            # Adding validator node metrics
            validator_metrics_info = context.cl_nodes_metrics_info[1]
            metrics_jobs.append(
                new_metrics_job(
                    job_name=validator_metrics_info[METRICS_INFO_NAME_KEY],
                    endpoint=validator_metrics_info[METRICS_INFO_URL_KEY],
                    metrics_path=validator_metrics_info[METRICS_INFO_PATH_KEY],
                    labels={
                        "service": context.validator_service_name,
                        "client_type": VALIDATOR_CLIENT_TYPE,
                        "client_name": context.client_name,
                    },
                )
            )
    # Adding additional metrics jobs
    for job in additional_metrics_jobs:
        if job == None:
            continue
        metrics_jobs.append(job)
    return {
        "MetricsJobs": metrics_jobs,
    }


def new_metrics_job(
    job_name,
    endpoint,
    metrics_path,
    labels,
    scrape_interval="15s",
):
    return {
        "Name": job_name,
        "Endpoint": endpoint,
        "MetricsPath": metrics_path,
        "Labels": labels,
        "ScrapeInterval": scrape_interval,
    }
