shared_utils = import_module("../shared_utils/shared_utils.star")
postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")
redis = import_module("github.com/kurtosis-tech/redis-package/main.star")
constants = import_module("../package_io/constants.star")
IMAGE_NAME = "gobitfly/eth2-beaconchain-explorer:latest"

POSTGRES_PORT_ID = "postgres"
POSTGRES_PORT_NUMBER = 5432
POSTGRES_DB = "db"
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = "pass"

REDIS_PORT_ID = "redis"
REDIS_PORT_NUMBER = 6379

FRONTEND_PORT_NUMBER = 8080
LITTLE_BIGTABLE_PORT_NUMBER = 9000

FULL_BEACONCHAIN_CONFIG_FILENAME = "beaconchain-config.yml"

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

# The min/max CPU/memory that littlebigtable can use
LITTLE_BIGTABLE_MIN_CPU = 100
LITTLE_BIGTABLE_MAX_CPU = 1000
LITTLE_BIGTABLE_MIN_MEMORY = 128
LITTLE_BIGTABLE_MAX_MEMORY = 2048

# The min/max CPU/memory that the indexer can use
INDEXER_MIN_CPU = 100
INDEXER_MAX_CPU = 1000
INDEXER_MIN_MEMORY = 1024
INDEXER_MAX_MEMORY = 2048

# The min/max CPU/memory that the init can use
INIT_MIN_CPU = 10
INIT_MAX_CPU = 100
INIT_MIN_MEMORY = 32
INIT_MAX_MEMORY = 128

# The min/max CPU/memory that the eth1indexer can use
ETH1INDEXER_MIN_CPU = 100
ETH1INDEXER_MAX_CPU = 1000
ETH1INDEXER_MIN_MEMORY = 128
ETH1INDEXER_MAX_MEMORY = 1024

# The min/max CPU/memory that the rewards-exporter can use
REWARDSEXPORTER_MIN_CPU = 10
REWARDSEXPORTER_MAX_CPU = 100
REWARDSEXPORTER_MIN_MEMORY = 32
REWARDSEXPORTER_MAX_MEMORY = 128

# The min/max CPU/memory that the statistics can use
STATISTICS_MIN_CPU = 10
STATISTICS_MAX_CPU = 100
STATISTICS_MIN_MEMORY = 32
STATISTICS_MAX_MEMORY = 128

# The min/max CPU/memory that the frontend-data-updater can use
FDU_MIN_CPU = 10
FDU_MAX_CPU = 100
FDU_MIN_MEMORY = 32
FDU_MAX_MEMORY = 128

# The min/max CPU/memory that the frontend can use
FRONTEND_MIN_CPU = 100
FRONTEND_MAX_CPU = 1000
FRONTEND_MIN_MEMORY = 512
FRONTEND_MAX_MEMORY = 2048


def launch_full_beacon(
    plan,
    config_template,
    el_cl_data_files_artifact_uuid,
    cl_contexts,
    el_contexts,
    persistent,
    global_node_selectors,
    port_publisher,
    additional_service_index,
):
    node_selectors = global_node_selectors
    postgres_output = postgres.run(
        plan,
        service_name="beaconchain-postgres",
        image="postgres:15.2-alpine",
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD,
        database=POSTGRES_DB,
        min_cpu=POSTGRES_MIN_CPU,
        max_cpu=POSTGRES_MAX_CPU,
        min_memory=POSTGRES_MIN_MEMORY,
        max_memory=POSTGRES_MAX_MEMORY,
        persistent=persistent,
        node_selectors=node_selectors,
    )
    redis_output = redis.run(
        plan,
        service_name="beaconchain-redis",
        image="redis:7",
        min_cpu=REDIS_MIN_CPU,
        max_cpu=REDIS_MAX_CPU,
        min_memory=REDIS_MIN_MEMORY,
        max_memory=REDIS_MAX_MEMORY,
        node_selectors=node_selectors,
    )
    # TODO perhaps create a new service for the littlebigtable
    little_bigtable = plan.add_service(
        name="beaconchain-littlebigtable",
        config=get_little_bigtable_config(
            node_selectors, port_publisher, additional_service_index
        ),
    )

    el_uri = "http://{0}:{1}".format(
        el_contexts[0].ip_addr, el_contexts[0].rpc_port_num
    )
    redis_url = "{}:{}".format(redis_output.hostname, redis_output.port_number)

    template_data = new_config_template_data(
        cl_contexts[0].ip_addr,
        cl_contexts[0].http_port,
        cl_contexts[0].client_name,
        el_uri,
        little_bigtable.ip_address,
        LITTLE_BIGTABLE_PORT_NUMBER,
        postgres_output.service.name,
        POSTGRES_PORT_NUMBER,
        redis_url,
        FRONTEND_PORT_NUMBER,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        FULL_BEACONCHAIN_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "beaconchain-config.yml"
    )

    files = {
        "/app/config/": config_files_artifact_name,
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data_files_artifact_uuid,
    }

    # Initialize the db schema
    initdbschema = plan.add_service(
        name="beaconchain-schema-initializer",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files=files,
            entrypoint=["tail", "-f", "/dev/null"],
            min_cpu=INIT_MIN_CPU,
            max_cpu=INIT_MAX_CPU,
            min_memory=INIT_MIN_MEMORY,
            max_memory=INIT_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    plan.print("applying db schema")
    plan.exec(
        service_name=initdbschema.name,
        description="Applying db schema",
        recipe=ExecRecipe(
            [
                "./misc",
                "-config",
                "/app/config/beaconchain-config.yml",
                "-command",
                "applyDbSchema",
            ]
        ),
    )

    plan.print("applying big table schema")
    # Initialize the bigtable schema
    plan.exec(
        service_name=initdbschema.name,
        description="Applying big table schema",
        recipe=ExecRecipe(
            [
                "./misc",
                "-config",
                "/app/config/beaconchain-config.yml",
                "-command",
                "initBigtableSchema",
            ]
        ),
    )

    # Start the indexer
    indexer = plan.add_service(
        name="beaconchain-indexer",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files=files,
            entrypoint=["./explorer"],
            cmd=[
                "-config",
                "/app/config/beaconchain-config.yml",
            ],
            env_vars={
                "INDEXER_ENABLED": "TRUE",
            },
            min_cpu=INDEXER_MIN_CPU,
            max_cpu=INDEXER_MAX_CPU,
            min_memory=INDEXER_MIN_MEMORY,
            max_memory=INDEXER_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )
    # Start the eth1indexer
    eth1indexer = plan.add_service(
        name="beaconchain-eth1indexer",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files=files,
            entrypoint=["./eth1indexer"],
            cmd=[
                "-config",
                "/app/config/beaconchain-config.yml",
                "-blocks.concurrency",
                "1",
                "-blocks.tracemode",
                "geth",
                "-data.concurrency",
                "1",
                "-balances.enabled",
            ],
            min_cpu=ETH1INDEXER_MIN_CPU,
            max_cpu=ETH1INDEXER_MAX_CPU,
            min_memory=ETH1INDEXER_MIN_MEMORY,
            max_memory=ETH1INDEXER_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    rewardsexporter = plan.add_service(
        name="beaconchain-rewardsexporter",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files=files,
            entrypoint=["./rewards-exporter"],
            cmd=[
                "-config",
                "/app/config/beaconchain-config.yml",
            ],
            min_cpu=REWARDSEXPORTER_MIN_CPU,
            max_cpu=REWARDSEXPORTER_MAX_CPU,
            min_memory=REWARDSEXPORTER_MIN_MEMORY,
            max_memory=REWARDSEXPORTER_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    statistics = plan.add_service(
        name="beaconchain-statistics",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files=files,
            entrypoint=["./statistics"],
            cmd=[
                "-config",
                "/app/config/beaconchain-config.yml",
                "-charts.enabled",
                "-graffiti.enabled",
                "-validators.enabled",
            ],
            min_cpu=STATISTICS_MIN_CPU,
            max_cpu=STATISTICS_MAX_CPU,
            min_memory=STATISTICS_MIN_MEMORY,
            max_memory=STATISTICS_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    fdu = plan.add_service(
        name="beaconchain-fdu",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files=files,
            entrypoint=["./frontend-data-updater"],
            cmd=[
                "-config",
                "/app/config/beaconchain-config.yml",
            ],
            min_cpu=FDU_MIN_CPU,
            max_cpu=FDU_MAX_CPU,
            min_memory=FDU_MIN_MEMORY,
            max_memory=FDU_MAX_MEMORY,
            node_selectors=node_selectors,
        ),
    )

    frontend = plan.add_service(
        name="beaconchain-frontend",
        config=get_frontend_config(
            files, node_selectors, port_publisher, additional_service_index
        ),
    )


def get_little_bigtable_config(
    node_selectors, port_publisher, additional_service_index
):
    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.LITTLE_BIGTABLE_PORT_ID,
        additional_service_index,
        0,
    )
    return ServiceConfig(
        image="gobitfly/little_bigtable:latest",
        ports={
            constants.LITTLE_BIGTABLE_PORT_ID: PortSpec(
                LITTLE_BIGTABLE_PORT_NUMBER, application_protocol="tcp"
            )
        },
        public_ports=public_ports,
        min_cpu=LITTLE_BIGTABLE_MIN_CPU,
        max_cpu=LITTLE_BIGTABLE_MAX_CPU,
        min_memory=LITTLE_BIGTABLE_MIN_MEMORY,
        max_memory=LITTLE_BIGTABLE_MAX_MEMORY,
        node_selectors=node_selectors,
    )


def get_frontend_config(
    files, node_selectors, port_publisher, additional_service_index
):
    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        1,
    )
    return ServiceConfig(
        image=IMAGE_NAME,
        files=files,
        entrypoint=["./explorer"],
        cmd=[
            "-config",
            "/app/config/beaconchain-config.yml",
        ],
        env_vars={
            "FRONTEND_ENABLED": "TRUE",
        },
        ports={
            constants.HTTP_PORT_ID: PortSpec(
                FRONTEND_PORT_NUMBER, application_protocol="http"
            ),
        },
        public_ports=public_ports,
        min_cpu=FRONTEND_MIN_CPU,
        max_cpu=FRONTEND_MAX_CPU,
        min_memory=FRONTEND_MIN_MEMORY,
        max_memory=FRONTEND_MAX_MEMORY,
        node_selectors=node_selectors,
    )


def new_config_template_data(
    cl_url,
    cl_port,
    cl_type,
    el_uri,
    lbt_host,
    lbt_port,
    db_host,
    db_port,
    redis_url,
    frontend_port,
):
    return {
        "CLNodeHost": cl_url,
        "CLNodePort": cl_port,
        "CLNodeType": cl_type,
        "ELNodeEndpoint": el_uri,
        "LBTHost": lbt_host,
        "LBTPort": lbt_port,
        "DBName": POSTGRES_DB,
        "DBUser": POSTGRES_USER,
        "DBPass": POSTGRES_PASSWORD,
        "DBHost": db_host,
        "DBPort": db_port,
        "RedisEndpoint": redis_url,
        "FrontendPort": frontend_port,
    }
