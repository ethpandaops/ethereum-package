shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")

IMAGE_NAME_BLOCKSCOUT = "blockscout/blockscout:6.0.0"
IMAGE_NAME_BLOCKSCOUT_VERIF = "ghcr.io/blockscout/smart-contract-verifier:v1.6.0"

SERVICE_NAME_BLOCKSCOUT = "blockscout"
SERVICE_NAME_BLOCKSCOUT_POSTGRES = "blockscout-posgres"
SERVICE_NAME_BLOCKSCOUT_VERIF = "blockscout-verif"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 4000
HTTP_PORT_NUMBER_VERIF = 8050

BLOCKSCOUT_MIN_CPU = 100
BLOCKSCOUT_MAX_CPU = 1000
BLOCKSCOUT_MIN_MEMORY = 1024
BLOCKSCOUT_MAX_MEMORY = 2048

BLOCKSCOUT_VERIF_MIN_CPU = 10
BLOCKSCOUT_VERIF_MAX_CPU = 1000
BLOCKSCOUT_VERIF_MIN_MEMORY = 10
BLOCKSCOUT_VERIF_MAX_MEMORY = 1024


USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

VERIF_USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER_VERIF,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_blockscout(
    plan,
    el_client_contexts,
):
    postgres_output = postgres.run(
        plan, 
        service_name="{}-postgres".format(SERVICE_NAME_BLOCKSCOUT_POSTGRES), 
        database="blockscout", 
        extra_configs=["max_connections=1000"],
    )

    el_client_context = el_client_contexts[0]
    el_client_rpc_url = "http://{}:{}/".format(el_client_context.ip_addr, el_client_context.rpc_port_num)    
    el_client_name = el_client_context.client_name                    

    config_verif = get_config_verif()
    verif_service= plan.add_service(SERVICE_NAME_BLOCKSCOUT_VERIF, config_verif)  
    config_backend = get_config_backend(postgres_output, el_client_rpc_url,verif_service.hostname,el_client_name)
    blockscout_service= plan.add_service(SERVICE_NAME_BLOCKSCOUT, config_backend)  

def get_config_verif():

    return ServiceConfig(
        image=IMAGE_NAME_BLOCKSCOUT_VERIF,
        ports=VERIF_USED_PORTS,
        env_vars={
            "SMART_CONTRACT_VERIFIER__SERVER__HTTP__ADDR":"0.0.0.0:{}".format(HTTP_PORT_NUMBER_VERIF) 
        },
        min_cpu=BLOCKSCOUT_VERIF_MIN_CPU,
        max_cpu=BLOCKSCOUT_VERIF_MAX_CPU,
        min_memory=BLOCKSCOUT_VERIF_MIN_MEMORY,
        max_memory=BLOCKSCOUT_VERIF_MAX_MEMORY
    )


def get_config_backend(postgres_output, el_client_rpc_url,service_name,el_client_name):
    
    database_url = "{protocol}://{user}:{password}@{hostname}:{port}/{database}".format(
        protocol="postgresql",
        user=postgres_output.user,
        password=postgres_output.password,
        hostname=postgres_output.service.hostname,
        port=postgres_output.port.number,
        database=postgres_output.database,
    )

    return ServiceConfig(
        image=IMAGE_NAME_BLOCKSCOUT,
        ports=USED_PORTS,
        cmd=[
            "/bin/sh", "-c", 
            'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()" && bin/blockscout start'
        ],
        env_vars={
            "ETHEREUM_JSONRPC_VARIANT": el_client_name,
            "ETHEREUM_JSONRPC_HTTP_URL": el_client_rpc_url,
            "ETHEREUM_JSONRPC_TRACE_URL": el_client_rpc_url,
            "DATABASE_URL": database_url,
            "COIN": "ETH",
            "MICROSERVICE_SC_VERIFIER_ENABLED": "true",
            "MICROSERVICE_SC_VERIFIER_URL": service_name+":{}".format(HTTP_PORT_NUMBER_VERIF),
            "MICROSERVICE_SC_VERIFIER_TYPE": "sc_verifier",
            "INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER": "true",
            "ECTO_USE_SSL": "false",
            "NETWORK": "Kurtosis",
            "SUBNETWORK": "Kurtosis",
            "API_V2_ENABLED": "true",
            "PORT": "{}".format(HTTP_PORT_NUMBER),
            "SECRET_KEY_BASE":"56NtB48ear7+wMSf0IQuWDAAazhpb31qyc7GiyspBP2vh7t5zlCsF5QDv76chXeN"
        },
        min_cpu=BLOCKSCOUT_MIN_CPU,
        max_cpu=BLOCKSCOUT_MAX_CPU,
        min_memory=BLOCKSCOUT_MIN_MEMORY,
        max_memory=BLOCKSCOUT_MAX_MEMORY,        
    )