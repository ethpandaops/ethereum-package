shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")

POSTGRES_IMAGE = "library/postgres:alpine"

SERVICE_NAME_BLOCKSCOUT = "blockscout"
SERVICE_NAME_FRONTEND = "blockscout-frontend"
HTTP_PORT_NUMBER = 4000
HTTP_PORT_NUMBER_VERIF = 8050
HTTP_PORT_NUMBER_FRONTEND = 3000
BLOCKSCOUT_MIN_CPU = 100
BLOCKSCOUT_MAX_CPU = 1000
BLOCKSCOUT_MIN_MEMORY = 1024
BLOCKSCOUT_MAX_MEMORY = 2048

BLOCKSCOUT_VERIF_MIN_CPU = 10
BLOCKSCOUT_VERIF_MAX_CPU = 1000
BLOCKSCOUT_VERIF_MIN_MEMORY = 10
BLOCKSCOUT_VERIF_MAX_MEMORY = 1024

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

VERIF_USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER_VERIF,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

FRONTEND_USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER_FRONTEND,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_blockscout(
    plan,
    el_contexts,
    persistent,
    global_node_selectors,
    port_publisher,
    additional_service_index,
    docker_cache_params,
    blockscout_params,
    network_params,
):
    postgres_output = postgres.run(
        plan,
        service_name="{}-postgres".format(SERVICE_NAME_BLOCKSCOUT),
        database="blockscout",
        extra_configs=["max_connections=1000"],
        persistent=persistent,
        node_selectors=global_node_selectors,
        image=shared_utils.docker_cache_image_calc(docker_cache_params, POSTGRES_IMAGE),
    )

    el_context = el_contexts[0]
    el_client_rpc_url = "http://{}:{}/".format(
        el_context.ip_addr, el_context.rpc_port_num
    )
    el_client_name = el_context.client_name

    config_verif = get_config_verif(
        global_node_selectors,
        port_publisher,
        additional_service_index,
        docker_cache_params,
        blockscout_params,
    )
    verif_service_name = "{}-verif".format(SERVICE_NAME_BLOCKSCOUT)
    verif_service = plan.add_service(verif_service_name, config_verif)
    verif_url = "http://{}:{}/".format(
        verif_service.hostname, verif_service.ports["http"].number
    )

    config_backend = get_config_backend(
        postgres_output,
        el_client_rpc_url,
        verif_url,
        el_client_name,
        global_node_selectors,
        port_publisher,
        additional_service_index,
        docker_cache_params,
        blockscout_params,
    )
    blockscout_service = plan.add_service(SERVICE_NAME_BLOCKSCOUT, config_backend)
    plan.print(blockscout_service)

    blockscout_url = "http://{}:{}".format(
        blockscout_service.hostname, blockscout_service.ports["http"].number
    )

    config_frontend = get_config_frontend(
        plan,
        el_client_rpc_url,
        docker_cache_params,
        blockscout_params,
        network_params,
        global_node_selectors,
        blockscout_service,
    )
    plan.add_service(SERVICE_NAME_FRONTEND, config_frontend)
    return blockscout_url


def get_config_verif(
    node_selectors,
    port_publisher,
    additional_service_index,
    docker_cache_params,
    blockscout_params,
):
    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            blockscout_params.verif_image,
        ),
        ports=VERIF_USED_PORTS,
        public_ports=public_ports,
        env_vars={
            "SMART_CONTRACT_VERIFIER__SERVER__HTTP__ADDR": "0.0.0.0:{}".format(
                HTTP_PORT_NUMBER_VERIF
            )
        },
        min_cpu=BLOCKSCOUT_VERIF_MIN_CPU,
        max_cpu=BLOCKSCOUT_VERIF_MAX_CPU,
        min_memory=BLOCKSCOUT_VERIF_MIN_MEMORY,
        max_memory=BLOCKSCOUT_VERIF_MAX_MEMORY,
        node_selectors=node_selectors,
    )


def get_config_backend(
    postgres_output,
    el_client_rpc_url,
    verif_url,
    el_client_name,
    node_selectors,
    port_publisher,
    additional_service_index,
    docker_cache_params,
    blockscout_params,
):
    database_url = "{protocol}://{user}:{password}@{hostname}:{port}/{database}".format(
        protocol="postgresql",
        user=postgres_output.user,
        password=postgres_output.password,
        hostname=postgres_output.service.hostname,
        port=postgres_output.port.number,
        database=postgres_output.database,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        1,
    )

    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            blockscout_params.image,
        ),
        ports=USED_PORTS,
        public_ports=public_ports,
        cmd=[
            "/bin/sh",
            "-c",
            'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()" && bin/blockscout start',
        ],
        env_vars={
            "ETHEREUM_JSONRPC_VARIANT": "erigon"
            if el_client_name == "erigon" or el_client_name == "reth"
            else el_client_name,
            "ETHEREUM_JSONRPC_HTTP_URL": el_client_rpc_url,
            "ETHEREUM_JSONRPC_TRACE_URL": el_client_rpc_url,
            "DATABASE_URL": database_url,
            "COIN": "ETH",
            "MICROSERVICE_SC_VERIFIER_ENABLED": "true",
            "MICROSERVICE_SC_VERIFIER_URL": verif_url,
            "MICROSERVICE_SC_VERIFIER_TYPE": "sc_verifier",
            "INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER": "true",
            "ECTO_USE_SSL": "false",
            "NETWORK": "Kurtosis",
            "SUBNETWORK": "Kurtosis",
            "API_V2_ENABLED": "true",
            "PORT": "{}".format(HTTP_PORT_NUMBER),
            "SECRET_KEY_BASE": "56NtB48ear7+wMSf0IQuWDAAazhpb31qyc7GiyspBP2vh7t5zlCsF5QDv76chXeN",
        },
        min_cpu=BLOCKSCOUT_MIN_CPU,
        max_cpu=BLOCKSCOUT_MAX_CPU,
        min_memory=BLOCKSCOUT_MIN_MEMORY,
        max_memory=BLOCKSCOUT_MAX_MEMORY,
        node_selectors=node_selectors,
    )


def get_config_frontend(
    plan,
    el_client_rpc_url,
    docker_cache_params,
    blockscout_params,
    network_params,
    node_selectors,
    blockscout_service,
):
    return ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            blockscout_params.frontend_image,
        ),
        ports=FRONTEND_USED_PORTS,
        public_ports=FRONTEND_USED_PORTS,
        env_vars={
            "HOSTNAME": "0.0.0.0",
            "NEXT_PUBLIC_API_PROTOCOL": "http",
            "NEXT_PUBLIC_API_WEBSOCKET_PROTOCOL": "ws",
            "NEXT_PUBLIC_NETWORK_NAME": "Kurtosis",
            "NEXT_PUBLIC_NETWORK_ID": network_params.network_id,
            "NEXT_PUBLIC_NETWORK_RPC_URL": el_client_rpc_url,
            "NEXT_PUBLIC_API_HOST": blockscout_service.ip_address
            + ":"
            + str(blockscout_service.ports["http"].number),
            "NEXT_PUBLIC_AD_BANNER_PROVIDER": "none",
            "NEXT_PUBLIC_AD_TEXT_PROVIDER": "none",
            "NEXT_PUBLIC_IS_TESTNET": "true",
            "NEXT_PUBLIC_GAS_TRACKER_ENABLED": "true",
            "NEXT_PUBLIC_HAS_BEACON_CHAIN": "true",
            "NEXT_PUBLIC_NETWORK_VERIFICATION_TYPE": "validation",
            "NEXT_PUBLIC_NETWORK_ICON": "https://ethpandaops.io/logo.png",
            # "NEXT_PUBLIC_APP_HOST": "0.0.0.0",
            "NEXT_PUBLIC_APP_PROTOCOL": "http",
            "NEXT_PUBLIC_APP_HOST": "127.0.0.1",
            "NEXT_PUBLIC_APP_PORT": str(HTTP_PORT_NUMBER_FRONTEND),
            "NEXT_PUBLIC_USE_NEXT_JS_PROXY": "true",
            "PORT": str(HTTP_PORT_NUMBER_FRONTEND),
        },
        min_cpu=BLOCKSCOUT_MIN_CPU,
        max_cpu=BLOCKSCOUT_MAX_CPU,
        min_memory=BLOCKSCOUT_MIN_MEMORY,
        max_memory=BLOCKSCOUT_MAX_MEMORY,
        node_selectors=node_selectors,
    )
