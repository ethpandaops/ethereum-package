redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")
postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")
constants = import_module("../../../package_io/constants.star")
shared_utils = import_module("../../../shared_utils/shared_utils.star")

MEV_RELAY_WEBSITE = "mev-relay-website"
MEV_RELAY_ENDPOINT = "mev-relay-api"
MEV_RELAY_HOUSEKEEPER = "mev-relay-housekeeper"

MEV_RELAY_ENDPOINT_PORT = 9062
MEV_RELAY_WEBSITE_PORT = 9060
MEV_RELAY_PPROF_PORT = 6060
NETWORK_ID_TO_NAME = {
    "1": "mainnet",
    "17000": "holesky",
    "11155111": "sepolia",
    "560048": "hoodi",
}

LAUNCH_ADMINER = True

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
    blocksim_uri,
    network_params,
    persistent,
    port_publisher,
    index,
    global_node_selectors,
):
    public_ports = shared_utils.get_mev_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        0,
    )

    node_selectors = global_node_selectors
    redis = redis_module.run(
        plan,
        service_name="mev-relay-redis",
        min_cpu=REDIS_MIN_CPU,
        max_cpu=REDIS_MAX_CPU,
        min_memory=REDIS_MIN_MEMORY,
        max_memory=REDIS_MAX_MEMORY,
        node_selectors=node_selectors,
    )
    # making the password postgres as the relay expects it to be postgres
    postgres = postgres_module.run(
        plan,
        password="postgres",
        user="postgres",
        database="postgres",
        service_name="mev-relay-postgres",
        persistent=persistent,
        launch_adminer=LAUNCH_ADMINER,
        min_cpu=POSTGRES_MIN_CPU,
        max_cpu=POSTGRES_MAX_CPU,
        min_memory=POSTGRES_MIN_MEMORY,
        max_memory=POSTGRES_MAX_MEMORY,
        node_selectors=node_selectors,
    )

    network_name = NETWORK_ID_TO_NAME.get(network_id, network_id)

    image = mev_params.mev_relay_image

    env_vars = {
        "GENESIS_FORK_VERSION": constants.GENESIS_FORK_VERSION,
        "BELLATRIX_FORK_VERSION": constants.BELLATRIX_FORK_VERSION,
        "CAPELLA_FORK_VERSION": constants.CAPELLA_FORK_VERSION,
        "DENEB_FORK_VERSION": constants.DENEB_FORK_VERSION,
        "ELECTRA_FORK_VERSION": constants.ELECTRA_FORK_VERSION,
        "GENESIS_VALIDATORS_ROOT": validator_root,
        "SEC_PER_SLOT": str(network_params.seconds_per_slot),
        "SLOTS_PER_EPOCH": str(32) if network_params.preset == "mainnet" else str(8),
        "LOG_LEVEL": "debug",
        "DB_TABLE_PREFIX": "custom",
        "ENABLE_BUILDER_CANCELLATIONS": "1",
    }

    redis_url = "{}:{}".format(redis.hostname, redis.port_number)
    postgres_url = postgres.url + "?sslmode=disable"
    plan.add_service(
        name=MEV_RELAY_HOUSEKEEPER,
        config=ServiceConfig(
            image=image,
            cmd=[
                "housekeeper",
                "--network",
                "custom",
                "--db",
                postgres_url,
                "--redis-uri",
                redis_url,
                "--beacon-uris",
                beacon_uris,
            ]
            + mev_params.mev_relay_housekeeper_extra_args,
            env_vars=env_vars | mev_params.mev_relay_housekeeper_extra_env_vars,
            min_cpu=RELAY_MIN_CPU,
            max_cpu=RELAY_MAX_CPU,
            min_memory=RELAY_MIN_MEMORY,
            max_memory=RELAY_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    api = plan.add_service(
        name=MEV_RELAY_ENDPOINT,
        config=ServiceConfig(
            image=image,
            cmd=[
                "api",
                "--network",
                "custom",
                "--db",
                postgres_url,
                "--secret-key",
                constants.DEFAULT_MEV_SECRET_KEY,
                "--listen-addr",
                "0.0.0.0:{0}".format(MEV_RELAY_ENDPOINT_PORT),
                "--redis-uri",
                redis_url,
                "--beacon-uris",
                beacon_uris,
                "--blocksim",
                blocksim_uri,
                "--pprof-listen-addr",
                "0.0.0.0:{0}".format(MEV_RELAY_PPROF_PORT),
            ]
            + mev_params.mev_relay_api_extra_args,
            ports={
                "http": PortSpec(
                    number=MEV_RELAY_ENDPOINT_PORT, transport_protocol="TCP"
                ),
                "pprof": PortSpec(
                    number=MEV_RELAY_PPROF_PORT, transport_protocol="TCP"
                ),
            },
            public_ports=public_ports,
            env_vars=env_vars | mev_params.mev_relay_api_extra_env_vars,
            min_cpu=RELAY_MIN_CPU,
            max_cpu=RELAY_MAX_CPU,
            min_memory=RELAY_MIN_MEMORY,
            max_memory=RELAY_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    public_ports = shared_utils.get_mev_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        1,
    )
    plan.add_service(
        name=MEV_RELAY_WEBSITE,
        config=ServiceConfig(
            image=image,
            cmd=[
                "website",
                "--network",
                "custom",
                "--db",
                postgres_url,
                "--listen-addr",
                "0.0.0.0:{0}".format(MEV_RELAY_WEBSITE_PORT),
                "--redis-uri",
                redis_url,
                "https://{0}@{1}".format(
                    constants.DEFAULT_MEV_PUBKEY, MEV_RELAY_ENDPOINT
                ),
                "--show-config-details",
                "--relay-url",
                "http://{0}@{1}:{2}".format(
                    constants.DEFAULT_MEV_PUBKEY,
                    api.ip_address,
                    MEV_RELAY_ENDPOINT_PORT,
                ),
                "--pubkey-override",
                constants.DEFAULT_MEV_PUBKEY,
            ]
            + mev_params.mev_relay_website_extra_args,
            ports={
                "http": PortSpec(
                    number=MEV_RELAY_WEBSITE_PORT,
                    transport_protocol="TCP",
                    application_protocol="http",
                )
            },
            public_ports=public_ports,
            env_vars=env_vars | mev_params.mev_relay_website_extra_env_vars,
            min_cpu=RELAY_MIN_CPU,
            max_cpu=RELAY_MAX_CPU,
            min_memory=RELAY_MIN_MEMORY,
            max_memory=RELAY_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    return "http://{0}@{1}:{2}".format(
        constants.DEFAULT_MEV_PUBKEY, api.ip_address, MEV_RELAY_ENDPOINT_PORT
    )
