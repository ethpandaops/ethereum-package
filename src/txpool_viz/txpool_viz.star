redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")
postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

HTTP_PORT_NUMBER= 8080
TXPOOL_VIZ_SERVICE_NAME="txpool-viz"

def launch_txpool_viz(
    plan,
    network_participants,
    txpoolviz_params,
):
    endpoint_list = []
    for index, participant in enumerate(network_participants):
        # Extract the rpc and wss urls
        endpoint_list.append({
            "name": participant.el_context.el_metrics_info[0]["name"],
            "rpc_url": participant.el_context.rpc_http_url,
            "socket": participant.el_context.ws_url
        })

    config = create_config(
        endpoint_list,
        network_participants,
        txpoolviz_params
    )

    # add postgres server
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

    config_json = json.encode(config)

    txpoolviz = plan.add_service(
      name=TXPOOL_VIZ_SERVICE_NAME,
      config=ServiceConfig(
        image="punkhazardlabs/txpool-viz:latest",
        ports= {
            shared_utils.HTTP_APPLICATION_PROTOCOL:  PortSpec(
                number=HTTP_PORT_NUMBER,
                application_protocol=shared_utils.HTTP_APPLICATION_PROTOCOL,
                transport_protocol=shared_utils.TCP_PROTOCOL,
            ),
        },
        env_vars = {
          "POSTGRES_URL": postgres.url,
          "REDIS_URL": redis_url,
          "CONFIG_JSON": config_json,
          "PORT": str(HTTP_PORT_NUMBER),
        },
      )
    )

def create_config(
    endpoint_list,
    network_participants,
    txpoolviz_params
):
    config = {}

    # endpoints list
    config["endpoints"] = endpoint_list

    if txpoolviz_params["focil_enabled"] == "true":
        config["beacon_sse_url"] = network_participants[0].cl_context.beacon_http_url

    # polling config
    polling_config = {}
    polling_config["interval"] = getattr(
        txpoolviz_params, "polling_interval", "3s" # 3s default
    )
    polling_config["timeout"] = getattr(
        txpoolviz_params, "polling_timeout", "3s" # 3s default
    )
    config["polling"] = polling_config

    # filters config
    filters_config = {}
    filters_config["min_gas_price"] = getattr(
        txpoolviz_params, "min_gas_price", "1gwei" # 1gwei default
    )
    config["filters"] = filters_config

    return config
