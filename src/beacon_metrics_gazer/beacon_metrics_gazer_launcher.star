shared_utils = import_module("../shared_utils/shared_utils.star")
prometheus = import_module("../prometheus/prometheus_launcher.star")


SERVICE_NAME = "beacon-metrics-gazer"
IMAGE_NAME = "ethpandaops/beacon-metrics-gazer:master"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 8080

METRICS_PATH = "/metrics"

BEACON_METRICS_GAZER_CONFIG_FILENAME = "validator-ranges.yaml"

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
    data = []
    running_total_validator_count = 0
    for index, client in enumerate(cl_client_contexts):
        participant = participants[index]
        if participant.validator_count == 0:
            continue
        start_index = running_total_validator_count
        running_total_validator_count += participant.validator_count
        end_index = start_index + participant.validator_count
        service_name = client.beacon_service_name
        data.append(
            {
                "ClientName": service_name,
                "Range": "{0}-{1}".format(start_index, end_index),
            }
        )

    template_data = {"Data": data}

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        BEACON_METRICS_GAZER_CONFIG_FILENAME
    ] = shared_utils.new_template_and_data(config_template, template_data)

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "validator-ranges"
    )

    config = get_config(
        config_files_artifact_name,
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


def get_config(config_files_artifact_name, ip_addr, http_port_num):
    config_file_path = shared_utils.path_join(
        BEACON_METRICS_GAZER_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        BEACON_METRICS_GAZER_CONFIG_FILENAME,
    )
    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        files={
            BEACON_METRICS_GAZER_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
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
