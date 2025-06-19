redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")
postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

HTTP_PORT_NUMBER= 8080
TXPOOL_VIZ_SERVICE_NAME="txpool-viz"

TXPOOL_VIZ_CONFIG_FILENAME = "config.yaml"
TXPOOL_VIZ_CONFIG_PATH="/cfg/"

# The min/max CPU/memory that txpool-viz can use
MIN_CPU = 100
MAX_CPU = 10000
MIN_MEMORY = 128
MAX_MEMORY = 8192

def launch_txpool_viz(
    plan,
    config_template,
    network_participants,
    txpoolviz_params,
    global_node_selectors
):
    endpoint_list = []
    for participant in network_participants:
        el_metrics_info = participant.el_context.el_metrics_info
        endpoint_list.append({
            "Name": el_metrics_info[0]["name"] if el_metrics_info else "unknown",
            "RPCUrl": participant.el_context.rpc_http_url,
            "Socket": participant.el_context.ws_url
        })

    beacon_endpoints = []
    for participant in network_participants:
        beacon_endpoints.append({
            "Name": participant.cl_context.beacon_service_name,
            "BeaconUrl": participant.cl_context.beacon_http_url,
        })


    txpoolviz_params["endpoints"] = endpoint_list
    txpoolviz_params["beacon_endpoints"] = beacon_endpoints

    txpoolviz_params["endpoints"] = endpoint_list

    # // config data & template
    template_data = txpool_viz_config_template_data(txpoolviz_params)

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

    # add redis server
    redis = redis_module.run(
        plan,
        service_name="txpool-viz-redis",
    )

    redis_url = "redis://" + redis.hostname + ":" + str(redis.port_number) + "/0"

    environment_variables = {
          "POSTGRES_URL": postgres.url,
          "REDIS_URL": redis_url,
          "PORT": str(HTTP_PORT_NUMBER),
          "ENV": "prod" # Default for Kurtosis
        }

    service_config = get_service_config(environment_variables, txpoolviz_params, global_node_selectors, config_files_artifact_name)

    txpoolviz = plan.add_service(TXPOOL_VIZ_SERVICE_NAME, config=service_config)

def get_service_config(environment_variables, txpool_viz_params, node_selectors, files_artifact):
    return ServiceConfig(
        image="punkhazardlabs/txpool-viz:dev",
        ports= {
            shared_utils.HTTP_APPLICATION_PROTOCOL:  PortSpec(
                number=HTTP_PORT_NUMBER,
                application_protocol=shared_utils.HTTP_APPLICATION_PROTOCOL,
                transport_protocol=shared_utils.TCP_PROTOCOL,
            ),
        },
        env_vars = environment_variables,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        files = {
           TXPOOL_VIZ_CONFIG_PATH : files_artifact
        },
        node_selectors=node_selectors,
      )

def txpool_viz_config_template_data(config):
    cfg = {
        "Endpoints": config["endpoints"],
        "Polling": config["polling"],
        "Filters": config["filters"],
        "LogLevel": config["log_level"],
    }

    if config["focil_enabled"] == "true":
        cfg["FocilEnabled"]= config["focil_enabled"]
        cfg["BeaconEndpoints"] = config["beacon_endpoints"]

    return cfg
