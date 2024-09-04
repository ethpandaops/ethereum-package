shared_utils = import_module("../shared_utils/shared_utils.star")
postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")
redis = import_module("github.com/kurtosis-tech/redis-package/main.star")
constants = import_module("../package_io/constants.star")

WEB_SERVICE_NAME = "blobscan-web"
API_SERVICE_NAME = "blobscan-api"
INDEXER_SERVICE_NAME = "blobscan-indexer"
SECRET_KEY = "supersecure"
WEB_HTTP_PORT_NUMBER = 3000
API_HTTP_PORT_NUMBER = 3001

WEB_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        WEB_HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

API_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        API_HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

ENTRYPOINT_ARGS = ["/bin/sh", "-c"]

# The min/max CPU/memory that blobscan-indexer can use
INDEX_MIN_CPU = 10
INDEX_MAX_CPU = 1000
INDEX_MIN_MEMORY = 32
INDEX_MAX_MEMORY = 1024

# The min/max CPU/memory that blobscan-api can use
API_MIN_CPU = 100
API_MAX_CPU = 1000
API_MIN_MEMORY = 1024
API_MAX_MEMORY = 2048

# The min/max CPU/memory that blobscan-web can use
WEB_MIN_CPU = 100
WEB_MAX_CPU = 1000
WEB_MIN_MEMORY = 512
WEB_MAX_MEMORY = 2048

# The min/max CPU/memory that postgres can use
POSTGRES_MIN_CPU = 10
POSTGRES_MAX_CPU = 1000
POSTGRES_MIN_MEMORY = 32
POSTGRES_MAX_MEMORY = 1024

# The min/max CPU/memory that redis can use
REDIS_MIN_CPU = 10
REDIS_MAX_CPU = 1000
REDIS_MIN_MEMORY = 32
REDIS_MAX_MEMORY = 1024


def launch_blobscan(
    plan,
    cl_contexts,
    el_contexts,
    network_id,
    network_params,
    persistent,
    global_node_selectors,
    port_publisher,
    additional_service_index,
):
    node_selectors = global_node_selectors
    beacon_node_rpc_uri = "{0}".format(cl_contexts[0].beacon_http_url)
    execution_node_rpc_uri = "{0}".format(el_contexts[0].rpc_http_url)

    postgres_output = postgres.run(
        plan,
        service_name="blobscan-postgres",
        min_cpu=POSTGRES_MIN_CPU,
        max_cpu=POSTGRES_MAX_CPU,
        min_memory=POSTGRES_MIN_MEMORY,
        max_memory=POSTGRES_MAX_MEMORY,
        persistent=persistent,
        node_selectors=node_selectors,
    )

    redis_output = redis.run(
        plan,
        service_name="blobscan-redis",
        min_cpu=REDIS_MIN_CPU,
        max_cpu=REDIS_MAX_CPU,
        min_memory=REDIS_MIN_MEMORY,
        max_memory=REDIS_MAX_MEMORY,
        persistent=persistent,
        node_selectors=node_selectors,
    )

    api_config = get_api_config(
        network_id,
        postgres_output.url,
        network_params.network,
        redis_output.url,
        node_selectors,
        port_publisher,
        additional_service_index,
    )
    blobscan_config = plan.add_service(API_SERVICE_NAME, api_config)

    blobscan_api_url = "http://{0}:{1}".format(
        blobscan_config.ip_address, blobscan_config.ports[constants.HTTP_PORT_ID].number
    )

    web_config = get_web_config(
        postgres_output.url,
        network_params.network,
        beacon_node_rpc_uri,
        execution_node_rpc_uri,
        node_selectors,
        port_publisher,
        additional_service_index,
    )
    plan.add_service(WEB_SERVICE_NAME, web_config)

    indexer_config = get_indexer_config(
        beacon_node_rpc_uri,
        blobscan_api_url,
        execution_node_rpc_uri,
        network_params.network,
        node_selectors,
    )
    plan.add_service(INDEXER_SERVICE_NAME, indexer_config)


def get_api_config(
    network_id,
    postgres_url,
    network_name,
    redis_url,
    node_selectors,
    port_publisher,
    additional_service_index,
):
    IMAGE_NAME = "blossomlabs/blobscan-api:latest"

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=API_PORTS,
        public_ports=public_ports,
        env_vars={
            "CHAIN_ID": network_id,
            "DATABASE_URL": postgres_url,
            "REDIS_URI": redis_url,
            "SECRET_KEY": SECRET_KEY,
            "BLOBSCAN_API_PORT": str(API_HTTP_PORT_NUMBER),
            "POSTGRES_STORAGE_ENABLED": "true",
            "NETWORK_NAME": network_name
            if network_name in constants.PUBLIC_NETWORKS
            else "devnet",
        },
        ready_conditions=ReadyCondition(
            recipe=GetHttpRequestRecipe(
                port_id="http",
                endpoint="/healthcheck",
            ),
            field="code",
            assertion="==",
            target_value=200,
            interval="5s",
            timeout="120s",
        ),
        min_cpu=API_MIN_CPU,
        max_cpu=API_MAX_CPU,
        min_memory=API_MIN_MEMORY,
        max_memory=API_MAX_MEMORY,
        node_selectors=node_selectors,
    )


def get_web_config(
    postgres_url,
    network_name,
    beacon_node_rpc,
    execution_node_rpc,
    node_selectors,
    port_publisher,
    additional_service_index,
):
    # TODO: https://github.com/kurtosis-tech/kurtosis/issues/1861
    # Configure NEXT_PUBLIC_BEACON_BASE_URL and NEXT_PUBLIC_EXPLORER_BASE env vars
    # once retrieving external URLs from services are supported in Kurtosis.
    IMAGE_NAME = "blossomlabs/blobscan-web:latest"

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        1,
    )

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=WEB_PORTS,
        public_ports=public_ports,
        env_vars={
            "DATABASE_URL": postgres_url,
            "NEXT_PUBLIC_NETWORK_NAME": network_name
            if network_name in constants.PUBLIC_NETWORKS
            else "devnet",
            "SECRET_KEY": SECRET_KEY,
            "POSTGRES_STORAGE_ENABLED": "true",
        },
        min_cpu=WEB_MIN_CPU,
        max_cpu=WEB_MAX_CPU,
        min_memory=WEB_MIN_MEMORY,
        max_memory=WEB_MAX_MEMORY,
        node_selectors=node_selectors,
    )


def get_indexer_config(
    beacon_node_rpc,
    blobscan_api_url,
    execution_node_rpc,
    network_name,
    node_selectors,
):
    IMAGE_NAME = "blossomlabs/blobscan-indexer:master"

    return ServiceConfig(
        image=IMAGE_NAME,
        env_vars={
            "BEACON_NODE_ENDPOINT": beacon_node_rpc,
            "BLOBSCAN_API_ENDPOINT": blobscan_api_url,
            "EXECUTION_NODE_ENDPOINT": execution_node_rpc,
            "NETWORK_NAME": network_name
            if network_name in constants.PUBLIC_NETWORKS
            else "devnet",
            "SECRET_KEY": SECRET_KEY,
        },
        entrypoint=ENTRYPOINT_ARGS,
        cmd=[" && ".join(["sleep 90", "/app/blob-indexer"])],
        min_cpu=INDEX_MIN_CPU,
        max_cpu=INDEX_MAX_CPU,
        min_memory=INDEX_MIN_MEMORY,
        max_memory=INDEX_MAX_MEMORY,
        node_selectors=node_selectors,
    )
