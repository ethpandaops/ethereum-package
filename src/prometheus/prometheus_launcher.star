shared_utils = import_module("../shared_utils/shared_utils.star")
prometheus = import_module("github.com/kurtosis-tech/prometheus-package/main.star")

EXECUTION_CLIENT_TYPE = "execution"
BEACON_CLIENT_TYPE = "beacon"
vc_type = "validator"

METRICS_INFO_NAME_KEY = "name"
METRICS_INFO_URL_KEY = "url"
METRICS_INFO_PATH_KEY = "path"
METRICS_INFO_ADDITIONAL_CONFIG_KEY = "config"

PROMETHEUS_DEFAULT_SCRAPE_INTERVAL = "15s"

# The min/max CPU/memory that prometheus can use
MIN_CPU = 10
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 2048


def launch_prometheus(
    plan,
    el_contexts,
    cl_contexts,
    vc_contexts,
    additional_metrics_jobs,
    ethereum_metrics_exporter_contexts,
    xatu_sentry_contexts,
    global_node_selectors,
    storage_tsdb_retention_time,
    storage_tsdb_retention_size,
):
    metrics_jobs = get_metrics_jobs(
        el_contexts,
        cl_contexts,
        vc_contexts,
        additional_metrics_jobs,
        ethereum_metrics_exporter_contexts,
        xatu_sentry_contexts,
    )
    prometheus_url = prometheus.run(
        plan,
        metrics_jobs,
        "prometheus",
        MIN_CPU,
        MAX_CPU,
        MIN_MEMORY,
        MAX_MEMORY,
        node_selectors=global_node_selectors,
        storage_tsdb_retention_time=storage_tsdb_retention_time,
        storage_tsdb_retention_size=storage_tsdb_retention_size,
    )

    return prometheus_url


def get_metrics_jobs(
    el_contexts,
    cl_contexts,
    vc_contexts,
    additional_metrics_jobs,
    ethereum_metrics_exporter_contexts,
    xatu_sentry_contexts,
):
    metrics_jobs = []
    # Adding execution clients metrics jobs
    for context in el_contexts:
        if len(context.el_metrics_info) >= 1 and context.el_metrics_info[0] != None:
            execution_metrics_info = context.el_metrics_info[0]
            scrape_interval = PROMETHEUS_DEFAULT_SCRAPE_INTERVAL
            labels = {
                "service": context.service_name,
                "client_type": EXECUTION_CLIENT_TYPE,
                "client_name": context.client_name,
            }
            additional_config = execution_metrics_info[
                METRICS_INFO_ADDITIONAL_CONFIG_KEY
            ]
            if additional_config != None:
                if additional_config.labels != None:
                    labels.update(additional_config.labels)
                if (
                    additional_config.scrape_interval != None
                    and additional_config.scrape_interval != ""
                ):
                    scrape_interval = additional_config.scrape_interval
            metrics_jobs.append(
                new_metrics_job(
                    job_name=execution_metrics_info[METRICS_INFO_NAME_KEY],
                    endpoint=execution_metrics_info[METRICS_INFO_URL_KEY],
                    metrics_path=execution_metrics_info[METRICS_INFO_PATH_KEY],
                    labels=labels,
                    scrape_interval=scrape_interval,
                )
            )
    # Adding consensus clients metrics jobs
    for context in cl_contexts:
        if (
            len(context.cl_nodes_metrics_info) >= 1
            and context.cl_nodes_metrics_info[0] != None
        ):
            # Adding beacon node metrics
            beacon_metrics_info = context.cl_nodes_metrics_info[0]
            scrape_interval = PROMETHEUS_DEFAULT_SCRAPE_INTERVAL
            labels = {
                "service": context.beacon_service_name,
                "client_type": BEACON_CLIENT_TYPE,
                "client_name": context.client_name,
            }
            additional_config = beacon_metrics_info[METRICS_INFO_ADDITIONAL_CONFIG_KEY]
            if additional_config != None:
                if additional_config.labels != None:
                    labels.update(additional_config.labels)
                if (
                    additional_config.scrape_interval != None
                    and additional_config.scrape_interval != ""
                ):
                    scrape_interval = additional_config.scrape_interval
            metrics_jobs.append(
                new_metrics_job(
                    job_name=beacon_metrics_info[METRICS_INFO_NAME_KEY],
                    endpoint=beacon_metrics_info[METRICS_INFO_URL_KEY],
                    metrics_path=beacon_metrics_info[METRICS_INFO_PATH_KEY],
                    labels=labels,
                    scrape_interval=scrape_interval,
                )
            )

    # Adding validator clients metrics jobs
    for context in vc_contexts:
        if context == None:
            continue
        metrics_info = context.metrics_info

        scrape_interval = PROMETHEUS_DEFAULT_SCRAPE_INTERVAL
        labels = {
            "service": context.service_name,
            "client_type": vc_type,
            "client_name": context.client_name,
        }

        metrics_jobs.append(
            new_metrics_job(
                job_name=metrics_info[METRICS_INFO_NAME_KEY],
                endpoint=metrics_info[METRICS_INFO_URL_KEY],
                metrics_path=metrics_info[METRICS_INFO_PATH_KEY],
                labels=labels,
                scrape_interval=scrape_interval,
            )
        )

    # Adding ethereum-metrics-exporter metrics jobs
    for context in ethereum_metrics_exporter_contexts:
        if context != None:
            metrics_jobs.append(
                new_metrics_job(
                    job_name="ethereum-metrics-exporter-{0}".format(context.pair_name),
                    endpoint="{}:{}".format(
                        context.ip_addr,
                        context.metrics_port_num,
                    ),
                    metrics_path="/metrics",
                    labels={
                        "instance": context.pair_name,
                        "consensus_client": context.cl_name,
                        "execution_client": context.el_name,
                    },
                )
            )
    # Adding Xatu Sentry metrics jobs
    for context in xatu_sentry_contexts:
        if context != None:
            metrics_jobs.append(
                new_metrics_job(
                    job_name="xatu-sentry-{0}".format(context.pair_name),
                    endpoint="{}:{}".format(
                        context.ip_addr,
                        context.metrics_port_num,
                    ),
                    metrics_path="/metrics",
                    labels={
                        "pair": context.pair_name,
                    },
                )
            )

    # Adding additional metrics jobs
    for job in additional_metrics_jobs:
        if job == None:
            continue
        metrics_jobs.append(job)

    return metrics_jobs


def new_metrics_job(
    job_name,
    endpoint,
    metrics_path,
    labels,
    scrape_interval=PROMETHEUS_DEFAULT_SCRAPE_INTERVAL,
):
    return {
        "Name": job_name,
        "Endpoint": endpoint,
        "MetricsPath": metrics_path,
        "Labels": labels,
        "ScrapeInterval": scrape_interval,
    }
