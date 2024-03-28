shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
xatu_sentry_context = import_module("../xatu_sentry/xatu_sentry_context.star")

HTTP_PORT_ID = "http"
METRICS_PORT_NUMBER = 9090

XATU_SENTRY_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"
XATU_SENTRY_CONFIG_FILENAME = "config.yaml"

# The min/max CPU/memory that xatu-sentry can use
MIN_CPU = 10
MAX_CPU = 1000
MIN_MEMORY = 16
MAX_MEMORY = 1024


def launch(
    plan,
    xatu_sentry_service_name,
    cl_context,
    xatu_sentry_params,
    network_params,
    pair_name,
    node_selectors,
):
    config_template = read_file(static_files.XATU_SENTRY_CONFIG_TEMPLATE_FILEPATH)

    template_data = new_config_template_data(
        str(METRICS_PORT_NUMBER),
        pair_name,
        "{0}".format(cl_context.beacon_http_url),
        xatu_sentry_params.xatu_server_addr,
        network_params.network,
        xatu_sentry_params.beacon_subscriptions,
        xatu_sentry_params.xatu_server_headers,
        xatu_sentry_params.xatu_server_tls,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}

    config_name = "{}-{}".format(xatu_sentry_service_name, XATU_SENTRY_CONFIG_FILENAME)

    template_and_data_by_rel_dest_filepath[config_name] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, config_name
    )

    config_file_path = shared_utils.path_join(
        XATU_SENTRY_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        config_name,
    )

    xatu_sentry_service = plan.add_service(
        xatu_sentry_service_name,
        ServiceConfig(
            image=xatu_sentry_params.xatu_sentry_image,
            ports={
                HTTP_PORT_ID: shared_utils.new_port_spec(
                    METRICS_PORT_NUMBER,
                    shared_utils.TCP_PROTOCOL,
                    shared_utils.HTTP_APPLICATION_PROTOCOL,
                )
            },
            files={
                XATU_SENTRY_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
            },
            cmd=[
                "sentry",
                "--config",
                config_file_path,
            ],
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    return xatu_sentry_context.new_xatu_sentry_context(
        xatu_sentry_service.ip_address,
        METRICS_PORT_NUMBER,
        pair_name,
    )


def new_config_template_data(
    metrics_port,
    beacon_node_name,
    beacon_node_addr,
    xatu_server_addr,
    network_name,
    beacon_subscriptions,
    xatu_server_headers,
    xatu_server_tls,
):
    return {
        "MetricsPort": metrics_port,
        "BeaconNodeName": beacon_node_name,
        "BeaconNodeAddress": beacon_node_addr,
        "XatuServerAddress": xatu_server_addr,
        "EthereumNetworkName": network_name,
        "BeaconSubscriptions": beacon_subscriptions,
        "XatuServerHeaders": xatu_server_headers,
        "XatuServerTLS": xatu_server_tls,
    }
