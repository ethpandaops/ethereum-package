redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")
postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

HTTP_PORT_NUMBER = 8080
TXPOOL_VIZ_SERVICE_NAME = "txpool-viz"

TXPOOL_VIZ_CONFIG_FILENAME = "config.yaml"
TXPOOL_VIZ_CONFIG_PATH = "/cfg/"

# The min/max CPU/memory that txpool-viz can use.
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEM = 128
MAX_MEM = 1024


def launch_txpool_viz(
    plan,
    config_template,
    network_participants,
    txpool_viz_params,
    global_node_selectors,
):
    endpoints_list = []
    for participant in network_participants:
        el_metrics_info = participant.el_context.el_metrics_info
        if el_metrics_info and len(el_metrics_info) > 0:
            name = el_metrics_info[0]["name"]
        else:
            name = "unknown"
        endpoints_list.append(
            {
                "Name": name,
                "RPCUrl": participant.el_context.rpc_http_url,
                "Socket": participant.el_context.ws_url,
            }
        )

    beacon_endpoints = []
    for participant in network_participants:
        beacon_endpoints.append(
            {
                "Name": participant.cl_context.beacon_service_name,
                "BeaconUrl": participant.cl_context.beacon_http_url,
            }
        )

    # config data & template
    template_data = txpool_viz_config_template_data(
        txpool_viz_params, endpoints_list, beacon_endpoints
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )

    file_config = {}
    file_config[TXPOOL_VIZ_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        config=file_config,
        name="txpool-viz-config",
    )

    postgres = postgres_module.run(
        plan,
        service_name="txpool-viz-postgres",
    )

    # attaching redis server
    redis = redis_module.run(
        plan,
        service_name="txpool-viz-redis",
    )

    redis_url = "redis://" + redis.hostname + ":" + str(redis.port_number) + "/0"

    environment_variables = dict(txpool_viz_params.env)
    environment_variables.update(
        {
            "POSTGRES_URL": postgres.url,
            "REDIS_URL": redis_url,
            "PORT": str(HTTP_PORT_NUMBER),
            "ENV": "prod",
        }
    )

    service_config = get_service_config(
        environment_variables,
        txpool_viz_params,
        global_node_selectors,
        config_files_artifact_name,
    )

    txpoolviz = plan.add_service(TXPOOL_VIZ_SERVICE_NAME, config=service_config)


def get_service_config(
    environment_variables, txpool_viz_params, node_selectors, files_artifact
):
    return ServiceConfig(
        image=txpool_viz_params.image,
        ports={
            shared_utils.HTTP_APPLICATION_PROTOCOL: PortSpec(
                number=HTTP_PORT_NUMBER,
                application_protocol=shared_utils.HTTP_APPLICATION_PROTOCOL,
                transport_protocol=shared_utils.TCP_PROTOCOL,
            ),
        },
        env_vars=environment_variables,
        min_cpu=txpool_viz_params.min_cpu or MIN_CPU,
        max_cpu=txpool_viz_params.max_cpu or MAX_CPU,
        min_memory=txpool_viz_params.min_mem or MIN_MEM,
        max_memory=txpool_viz_params.max_mem or MAX_MEM,
        files={TXPOOL_VIZ_CONFIG_PATH: files_artifact},
        node_selectors=node_selectors,
    )


def txpool_viz_config_template_data(config, endpoints_list, beacon_endpoints):
    cfg = dict(config.extra_args)
    cfg.update(
        {
            "Endpoints": endpoints_list,
            "Polling": config.polling,
            "Filters": config.filters,
            "LogLevel": config.log_level,
        }
    )

    if config.focil_enabled == "true":
        cfg["FocilEnabled"] = config.focil_enabled
        cfg["BeaconEndpoints"] = beacon_endpoints

    return cfg
