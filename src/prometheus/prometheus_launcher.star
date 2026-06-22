shared_utils = import_module("../shared_utils/shared_utils.star")
prometheus = import_module("github.com/kurtosis-tech/prometheus-package/main.star")
constants = import_module("../package_io/constants.star")

EXECUTION_CLIENT_TYPE = "execution"
BEACON_CLIENT_TYPE = "beacon"
VC_TYPE = "validator"
REMOTE_SIGNER_TYPE = "remote-signer"

METRICS_INFO_NAME_KEY = "name"
METRICS_INFO_URL_KEY = "url"
METRICS_INFO_PATH_KEY = "path"
METRICS_INFO_ADDITIONAL_CONFIG_KEY = "config"

PROMETHEUS_DEFAULT_SCRAPE_INTERVAL = "15s"

PROMETHEUS_CONFIG_DIR = "/config"
PROMETHEUS_CONFIG_FILENAME = "prometheus-config.yml"

# Rendered in-package (rather than via the external prometheus-package) so we can
# append an optional remote_write block when a token is supplied. The scrape_config
# section mirrors the upstream prometheus-package template.
PROMETHEUS_CONFIG_TEMPLATE = """global:
  scrape_interval: 15s
scrape_configs:
  {{- range $job := .MetricsJobs }}
  - job_name: "{{ $job.Name }}"
    metrics_path: "{{ $job.MetricsPath }}"
    {{- if $job.ScrapeInterval }}
    scrape_interval: {{ $job.ScrapeInterval }}
    {{- end }}
    static_configs:
      - targets: ['{{ $job.Endpoint }}']
        labels:{{ range $labelName, $labelValue := $job.Labels }}
          {{ $labelName }}: "{{ $labelValue }}"
        {{- end }}
  {{- end }}
{{- if .RemoteWriteToken }}
remote_write:
  - url: {{ .RemoteWriteUrl }}
    authorization:
      credentials: "{{ .RemoteWriteToken }}"
    write_relabel_configs:
      - source_labels: [job]
        regex: '{{ .RemoteWriteJobRegex }}'
        action: keep
      # Charon dashboards query job="charon". Native scrape jobs are named after
      # the service, so rewrite the job label to "charon" for Charon-node series
      # (identified by client_name=charon; VCs keep their own job label).
      - source_labels: [client_name]
        regex: 'charon'
        target_label: job
        replacement: 'charon'
        action: replace
{{- end }}
"""


def launch_prometheus(
    plan,
    el_contexts,
    cl_contexts,
    vc_contexts,
    network_params,
    remote_signer_contexts,
    additional_metrics_jobs,
    ethereum_metrics_exporter_contexts,
    xatu_sentry_contexts,
    global_node_selectors,
    prometheus_params,
    port_publisher,
    index,
):
    metrics_jobs = get_metrics_jobs(
        el_contexts if len(el_contexts) > 0 else None,
        cl_contexts,
        vc_contexts,
        network_params,
        remote_signer_contexts,
        additional_metrics_jobs,
        ethereum_metrics_exporter_contexts,
        xatu_sentry_contexts,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        0,
    )

    # Render the Prometheus config in-package so a remote_write block can be added
    # when prometheus_params.remote_write_token is supplied (e.g. via Kurtosis args
    # for shipping metrics to Obol central monitoring). remote_write stays off when
    # the token is empty.
    config_artifact = plan.render_templates(
        config={
            PROMETHEUS_CONFIG_FILENAME: struct(
                template=PROMETHEUS_CONFIG_TEMPLATE,
                data={
                    "MetricsJobs": metrics_jobs,
                    "RemoteWriteUrl": prometheus_params.remote_write_url,
                    "RemoteWriteToken": prometheus_params.remote_write_token,
                    "RemoteWriteJobRegex": prometheus_params.remote_write_job_regex,
                },
            ),
        },
        name="prometheus-config",
    )

    image = prometheus_params.image
    if image == "":
        image = "prom/prometheus:latest"

    prometheus_service = plan.add_service(
        name="prometheus",
        config=ServiceConfig(
            image=image,
            ports={
                constants.HTTP_PORT_ID: PortSpec(
                    number=9090,
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                PROMETHEUS_CONFIG_DIR: config_artifact,
            },
            cmd=[
                "--config.file="
                + PROMETHEUS_CONFIG_DIR
                + "/"
                + PROMETHEUS_CONFIG_FILENAME,
                "--storage.tsdb.path=/prometheus",
                "--storage.tsdb.retention.time="
                + str(prometheus_params.storage_tsdb_retention_time),
                "--storage.tsdb.retention.size="
                + str(prometheus_params.storage_tsdb_retention_size),
                "--storage.tsdb.wal-compression",
                "--web.console.libraries=/etc/prometheus/console_libraries",
                "--web.console.templates=/etc/prometheus/consoles",
                "--web.enable-lifecycle",
            ],
            min_cpu=prometheus_params.min_cpu,
            max_cpu=prometheus_params.max_cpu,
            min_memory=prometheus_params.min_mem,
            max_memory=prometheus_params.max_mem,
            node_selectors=global_node_selectors,
            public_ports=public_ports,
        ),
    )

    return "http://{0}:{1}".format(
        prometheus_service.ip_address,
        prometheus_service.ports[constants.HTTP_PORT_ID].number,
    )


def get_metrics_jobs(
    el_contexts,
    cl_contexts,
    vc_contexts,
    network_params,
    remote_signer_contexts,
    additional_metrics_jobs,
    ethereum_metrics_exporter_contexts,
    xatu_sentry_contexts,
):
    metrics_jobs = []
    # Adding execution clients metrics jobs
    if el_contexts != None:
        for context in el_contexts:
            if context == None:
                continue
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
        if context == None:
            continue
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
                "supernode": str(context.supernode),
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
            "client_type": VC_TYPE,
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

    # Adding validator clients metrics jobs
    for context in remote_signer_contexts:
        if context == None:
            continue
        metrics_info = context.metrics_info

        scrape_interval = PROMETHEUS_DEFAULT_SCRAPE_INTERVAL
        labels = {
            "service": context.service_name,
            "client_type": REMOTE_SIGNER_TYPE,
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
                        "network": network_params.network,
                        "testnet": network_params.network,
                        "chain_id": "{0}".format(
                            network_params.network_id
                            if network_params.network == constants.NETWORK_NAME.kurtosis
                            else constants.NETWORK_ID[network_params.network]
                        ),
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
