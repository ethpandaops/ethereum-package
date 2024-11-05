redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")
postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")
constants = import_module("../../package_io/constants.star")
shared_utils = import_module("../../shared_utils/shared_utils.star")
static_files = import_module("../../static_files/static_files.star")

IMAGE = "lubann/helix:latest"

HELIX_CONFIG_FILENAME = "helix-config.yml"
HELIX_RELAY_ENDPOINT_PORT = 4040

RELAY_PUB_KEY =  "0xadc0fe12e62c14a505ea1e655dbe4d36fa505ed57b634ba37912153d29edd45c5bc5a77764e68b98c53e3f6f8ce9fa3b"
RELAY_KEY = "0x6b845831c99c6bf43364bee624447d39698465df5c07f2cc4dca6e0acfbe46cd"

TAIYI_CORE_CONTRACT_ADDRESS = "0xA791D59427B2b7063050187769AC871B497F4b3C"

POSTGRES_PORT_ID = "postgres"
POSTGRES_PORT_NUMBER = 5432
POSTGRES_DB = "db"
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = "pass"

HELIX_ENDPOINT_PORT = 9062
LAUNCH_ADMINER = True

# The min/max CPU/memory that mev-relay can use
RELAY_MIN_MEMORY = 128
RELAY_MAX_MEMORY = 1024

# The min/max CPU/memory that postgres can use
POSTGRES_MIN_CPU = 10
POSTGRES_MAX_CPU = 1000
POSTGRES_MIN_MEMORY = 32
POSTGRES_MAX_MEMORY = 1024

# The min/max CPU/memory that redis can use
REDIS_MIN_CPU = 10
REDIS_MAX_CPU = 1000
REDIS_MIN_MEMORY = 16
REDIS_MAX_MEMORY = 1024


def launch_helix(
    plan,
    config_template,
    genesis_timestamp,
    genesis_validators_root,
    cl_contexts,
    el_contexts,
    el_cl_data_files_artifact_uuid,
    persistent,
    global_node_selectors,
):
    node_selectors = global_node_selectors

    redis = redis_module.run(
        plan,
        service_name="helix-redis",
        min_cpu=REDIS_MIN_CPU,
        max_cpu=REDIS_MAX_CPU,
        min_memory=REDIS_MIN_MEMORY,
        max_memory=REDIS_MAX_MEMORY,
        node_selectors=node_selectors,
    )
    plan.print("Successfully launched helix redis")
    # making the password postgres as the relay expects it to be postgres
    postgres = postgres_module.run(
        plan,
        password=POSTGRES_PASSWORD,
        user=POSTGRES_USER,
        database=POSTGRES_DB,
        service_name="helix-postgres",
        persistent=persistent,
        min_cpu=POSTGRES_MIN_CPU,
        max_cpu=POSTGRES_MAX_CPU,
        min_memory=POSTGRES_MIN_MEMORY,
        max_memory=POSTGRES_MAX_MEMORY,
        node_selectors=node_selectors,
        image="timescale/timescaledb-ha:pg16",
    )
    plan.print("Successfully launched helix postgres")
    # print network name
    redis_url = "redis://{}:{}".format("helix-redis", redis.port_number)

    network_dir_path = "{}/config.yaml".format(constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS)

    beacon_client_url = "http://{0}:{1}".format(
        cl_contexts[0].ip_addr, cl_contexts[0].http_port
    )
    execution_url = "http://{0}:{1}".format(
        el_contexts[0].ip_addr, el_contexts[0].rpc_port_num
    )

    # relay_url = "http://{0}:{1}".format(
    #     all_mevboost_contexts[0].private_ip_address, all_mevboost_contexts[0].port
    # )

    simulator_url = "http://{0}:{1}".format(
        el_contexts[0].ip_addr, el_contexts[0].rpc_port_num
    )
    template_data = {
        "Hostname": "helix-postgres",
        "Port": postgres.port.number,
        "DbName": POSTGRES_DB,
        "User": POSTGRES_USER,
        "Password": POSTGRES_PASSWORD,
        "Region": 0,
        "RegionName": "",
        "RedisUrl": redis_url,
        "BeaconClientUrl": beacon_client_url,
        "SimulatorUrl": simulator_url,
        "NetworkDirPath": network_dir_path,
        "GenesisValidatorRoot": genesis_validators_root,
        "GenesisTime": genesis_timestamp,
        # "RelayUrl": relay_url,
        "ExecutionUrl": execution_url,
        "DelegationContractAddress": TAIYI_CORE_CONTRACT_ADDRESS,
    }

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        HELIX_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "helix-config.yml"
    )

    files = {
        "/app/config/": config_files_artifact_name,
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data_files_artifact_uuid,
    }

    env = {
        "RELAY_KEY": RELAY_KEY,
        "RUST_LOG": "helix_api=debug,helix_common=debug,helix_beacon_client=debug,helix_database=debug,helix_datastore=debug,helix_housekeeper=debug,helix_utils=debug",
    }
    api = plan.add_service(
        name="helix-relay",
        config=ServiceConfig(
            image=IMAGE,
            files=files,
            cmd=[
                "--config",
                "/app/config/helix-config.yml",
            ],
            ports={
                "api": PortSpec(
                    number=HELIX_RELAY_ENDPOINT_PORT, transport_protocol="TCP"
                )
            },
            env_vars=env,
            min_memory=RELAY_MIN_MEMORY,
            max_memory=RELAY_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    return "http://{0}@{1}:{2}".format(
        RELAY_PUB_KEY, api.ip_address, HELIX_RELAY_ENDPOINT_PORT
    )
