redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")
postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")
constants = import_module("../../../package_io/constants.star")
shared_utils = import_module("../../../shared_utils/shared_utils.star")
input_parser = import_module("../../../package_io/input_parser.star")

MEV_RELAY_ENDPOINT = "mev-ultrasound-relay"
MEV_RELAY_ENDPOINT_PORT = 9062


# The min/max CPU/memory that mev-relay can use
RELAY_MIN_CPU = 500
RELAY_MAX_CPU = 3000
RELAY_MIN_MEMORY = 256
RELAY_MAX_MEMORY = 4096

# The min/max CPU/memory that postgres can use
POSTGRES_MIN_CPU = 10
POSTGRES_MAX_CPU = 1000
POSTGRES_MIN_MEMORY = 32
POSTGRES_MAX_MEMORY = 1024

# The min/max CPU/memory that redis can use
REDIS_MIN_CPU = 500
REDIS_MAX_CPU = 3000
REDIS_MIN_MEMORY = 16
REDIS_MAX_MEMORY = 1024


def launch_mev_relay(
    plan,
    mev_params,
    network_id,
    beacon_uris,
    validator_root,
    final_genesis_timestamp,
    blocksim_uri,
    network_params,
    persistent,
    port_publisher,
    index,
    global_node_selectors,
    global_tolerations,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    node_selectors = global_node_selectors
    redis = redis_module.run(
        plan,
        service_name="mev-relay-redis",
        min_cpu=REDIS_MIN_CPU,
        max_cpu=REDIS_MAX_CPU,
        min_memory=REDIS_MIN_MEMORY,
        max_memory=REDIS_MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )
    
    mevdb = postgres_module.run(
        plan,
        password="postgres",
        user="postgres",
        database="postgres",
        service_name="mev-relay-mevdb",
        persistent=persistent,
        launch_adminer=mev_params.launch_adminer,
        min_cpu=POSTGRES_MIN_CPU,
        max_cpu=POSTGRES_MAX_CPU,
        min_memory=POSTGRES_MIN_MEMORY,
        max_memory=POSTGRES_MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )

    localdb = postgres_module.run(
        plan,
        password="postgres",
        user="postgres",
        database="postgres",
        service_name="mev-relay-localdb",
        persistent=persistent,
        launch_adminer=mev_params.launch_adminer,
        min_cpu=POSTGRES_MIN_CPU,
        max_cpu=POSTGRES_MAX_CPU,
        min_memory=POSTGRES_MIN_MEMORY,
        max_memory=POSTGRES_MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )

    globaldb = postgres_module.run(
        plan,
        password="postgres",
        user="postgres",
        database="postgres",
        service_name="mev-relay-globaldb",
        persistent=persistent,
        launch_adminer=mev_params.launch_adminer,
        min_cpu=POSTGRES_MIN_CPU,
        max_cpu=POSTGRES_MAX_CPU,
        min_memory=POSTGRES_MIN_MEMORY,
        max_memory=POSTGRES_MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )

    image = mev_params.mev_relay_image
    public_ports = shared_utils.get_mev_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        0,
    )
    redis_url = "{}:{}".format(redis.hostname, redis.port_number)
    mevdb_url = mevdb.url + "?sslmode=disable"
    localdb_url = localdb.url + "?sslmode=disable"
    globaldb_url = globaldb.url + "?sslmode=disable"

    env_vars = {
        # Persistence
        "MEV_DATABASE_URL": mevdb_url,
        "LOCAL_DATABASE_URL": localdb_url,
        "GLOBAL_DATABASE_URL": globaldb_url,
        "REDIS_URI": redis_url,
        "REDIS_READ_URI": redis_url,

        # General config
        "CONSENSUS_NODES": beacon_uris,
        "EXECUTION_CLIENT_URLS": blocksim_uri,
        "BLOCKSIM_URI": blocksim_uri,

        "GEO": "rbx",
        "RELAY_SECRET_KEY": constants.DEFAULT_MEV_SECRET_KEY,
        "PRIVATE_ROUTE_AUTH_TOKEN": "7D74sFpCHufoNaLwhreycRV4jsK4LM",
        "ADMIN_TOKEN": "localdevtoken",
        "API_TIMEOUT": "10000",
        "TELEGRAM_API_KEY": "",
        "TELEGRAM_CHANNEL_ID": "",
        "BIND_IP_ADDR": "0.0.0.0",
        "TOP_BID_DEBOUNCE_MS_LOCAL": "2",
        "FORCED_TIMEOUT_MAX_BID_VALUE": "0",
        "X_TIMEOUT_HEADER_CORRECTION": "0",
        "ADJUSTMENT_LOOKBACK_MS": "50",
        "ADJUSTMENT_MIN_DELTA": "0",
        "SKIP_SIM_PROBABILITY": "1",
        "TOKIO_WORKER_THREADS": "4",
        "LOG_JSON": "false",
        "RUST_LOG": "info",

        # Feature flags
        "FF_ENABLE_TOP_BID_GOSSIP": "false",
        "FF_LOWBALL_AMOUNT": "1",
        "FF_ENABLE_V3_SUBMISSIONS": "false",
        "FF_ENABLE_DEHYDRATED_SUBMISSIONS": "false",
        "FF_PRIMEV_ENABLED": "false",
        "FF_PRIMEV_ENFORCE": "false",

        # Devnet specific configuration
        "NETWORK": "custom",
        "GENESIS_TIMESTAMP": final_genesis_timestamp,
        "GENESIS_VALIDATORS_ROOT": validator_root,
        "GENESIS_FORK_VERSION": constants.GENESIS_FORK_VERSION,
        "BELLATRIX_FORK_VERSION": constants.BELLATRIX_FORK_VERSION,
        "CAPELLA_FORK_VERSION": constants.CAPELLA_FORK_VERSION,
        "DENEB_FORK_VERSION": constants.DENEB_FORK_VERSION,
        "ELECTRA_FORK_VERSION": constants.ELECTRA_FORK_VERSION,
        "FULU_FORK_VERSION": constants.FULU_FORK_VERSION,
    }

    plan.run_sh(
        description="Waiting for genesis timestamp to finalise",
        run="while [ $(date +%s) -lt " + final_genesis_timestamp + " ]; do sleep 1; done",
    )

    api = plan.add_service(
        name=MEV_RELAY_ENDPOINT,
        config=ServiceConfig(
            image=image,
            cmd=[],
            ports={
                "http": PortSpec(
                    number=MEV_RELAY_ENDPOINT_PORT, transport_protocol="TCP"
                ),
            },
            public_ports=public_ports,
            env_vars=env_vars | mev_params.mev_relay_api_extra_env_vars,
            min_cpu=RELAY_MIN_CPU,
            max_cpu=RELAY_MAX_CPU,
            min_memory=RELAY_MIN_MEMORY,
            max_memory=RELAY_MAX_MEMORY,
            node_selectors=node_selectors,
            tolerations=tolerations,
        ),
    )

    return "http://{0}@{1}:{2}".format(
        constants.DEFAULT_MEV_PUBKEY, api.ip_address, MEV_RELAY_ENDPOINT_PORT
    )
