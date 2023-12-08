shared_utils = import_module("../shared_utils/shared_utils.star")
postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")

WEB_SERVICE_NAME = "blobscan-web"
API_SERVICE_NAME = "blobscan-api"
INDEXER_SERVICE_NAME = "blobscan-indexer"

HTTP_PORT_ID = "http"
WEB_HTTP_PORT_NUMBER = 3000
API_HTTP_PORT_NUMBER = 3001

WEB_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        WEB_HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


API_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        API_HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

ENTRYPOINT_ARGS = ["/bin/sh", "-c"]


def launch_blobscan(
    plan,
    cl_client_contexts,
    el_client_contexts,
    chain_id,
):
    beacon_node_rpc_uri = "http://{0}:{1}".format(
        cl_client_contexts[0].ip_addr, cl_client_contexts[0].http_port_num
    )
    execution_node_rpc_uri = "http://{0}:{1}".format(
        el_client_contexts[0].ip_addr, el_client_contexts[0].rpc_port_num
    )

    postgres_output = postgres.run(
        plan, service_name="blobscan-postgres", persistent=False
    )
    api_config = get_api_config(postgres_output.url, beacon_node_rpc_uri, chain_id)
    blobscan_config = plan.add_service(API_SERVICE_NAME, api_config)

    blobscan_api_url = "http://{0}:{1}".format(
        blobscan_config.ip_address, blobscan_config.ports[HTTP_PORT_ID].number
    )

    web_config = get_web_config(postgres_output.url, beacon_node_rpc_uri, chain_id)
    plan.add_service(WEB_SERVICE_NAME, web_config)

    indexer_config = get_indexer_config(
        beacon_node_rpc_uri, execution_node_rpc_uri, blobscan_api_url
    )
    plan.add_service(INDEXER_SERVICE_NAME, indexer_config)


def get_api_config(database_url, beacon_node_rpc, chain_id):
    IMAGE_NAME = "blossomlabs/blobscan:stable"

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=API_PORTS,
        env_vars={
            "BEACON_NODE_ENDPOINT": beacon_node_rpc,
            "CHAIN_ID": chain_id,
            "DATABASE_URL": database_url,
            "SECRET_KEY": "supersecret",
        },
        cmd=["api"],
        ready_conditions=ReadyCondition(
            recipe=GetHttpRequestRecipe(
                port_id="http",
                endpoint="/api/healthcheck",
            ),
            field="code",
            assertion="==",
            target_value=200,
            interval="5s",
            timeout="5s",
        ),
    )


def get_web_config(database_url, beacon_node_rpc, chain_id):
    # TODO: https://github.com/kurtosis-tech/kurtosis/issues/1861
    # Configure NEXT_PUBLIC_BEACON_BASE_URL and NEXT_PUBLIC_EXPLORER_BASE env vars
    # once retrieving external URLs from services are supported in Kurtosis.
    IMAGE_NAME = "blossomlabs/blobscan:stable"

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=WEB_PORTS,
        env_vars={
            "DATABASE_URL": database_url,
            "SECRET_KEY": "supersecret",
            "NEXT_PUBLIC_NETWORK_NAME": "kurtosis-devnet",
            "BEACON_NODE_ENDPOINT": beacon_node_rpc,
            "CHAIN_ID": chain_id,
        },
        cmd=["web"],
    )


def get_indexer_config(beacon_node_rpc, execution_node_rpc, blobscan_api_url):
    IMAGE_NAME = "blossomlabs/blobscan-indexer:master"

    return ServiceConfig(
        image=IMAGE_NAME,
        env_vars={
            "SECRET_KEY": "supersecret",
            "BLOBSCAN_API_ENDPOINT": blobscan_api_url,
            "EXECUTION_NODE_ENDPOINT": execution_node_rpc,
            "BEACON_NODE_ENDPOINT": beacon_node_rpc,
        },
        entrypoint=ENTRYPOINT_ARGS,
        cmd=[" && ".join(["sleep 90", "/app/blob-indexer"])],
    )
