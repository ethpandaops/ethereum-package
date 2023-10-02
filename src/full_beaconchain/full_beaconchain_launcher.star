shared_utils = import_module("../shared_utils/shared_utils.star")
IMAGE_NAME = "gobitfly/eth2-beaconchain-explorer:kurtosis"

POSTGRES_PORT_ID = "postgres"
POSTGRES_PORT_NUMBER = 5432
POSTGRES_DB = "db"
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = "pass"

REDIS_PORT_ID = "redis"
REDIS_PORT_NUMBER = 6379

FRONTEND_PORT_ID = "http"
FRONTEND_PORT_NUMBER = 8080

LITTLE_BIGTABLE_PORT_ID = "littlebigtable"
LITTLE_BIGTABLE_PORT_NUMBER = 9000

FULL_BEACONCHAIN_CONFIG_FILENAME = "config.yml"


USED_PORTS = {
    FRONTEND_PORT_ID: shared_utils.new_port_spec(
        FRONTEND_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_full_beacon(
    plan,
    config_template,
    cl_client_contexts,
    el_client_contexts,
):
    # TODO perhaps use the official redis & postgres packages
    db_services = plan.add_services(
        configs={
            # Add a Postgres server
            "explorer-postgres": ServiceConfig(
                image="postgres:15.2-alpine",
                ports={
                    POSTGRES_PORT_ID: PortSpec(
                        POSTGRES_PORT_NUMBER, application_protocol="postgresql"
                    ),
                },
                env_vars={
                    "POSTGRES_DB": POSTGRES_DB,
                    "POSTGRES_USER": POSTGRES_USER,
                    "POSTGRES_PASSWORD": POSTGRES_PASSWORD,
                },
            ),
            # Add a Redis server
            "explorer-redis": ServiceConfig(
                image="redis:7",
                ports={
                    REDIS_PORT_ID: PortSpec(
                        REDIS_PORT_NUMBER, application_protocol="tcp"
                    ),
                },
            ),
            # Add a Bigtable Emulator server
            "explorer-littlebigtable": ServiceConfig(
                image="gobitfly/little_bigtable:latest",
                ports={
                    LITTLE_BIGTABLE_PORT_ID: PortSpec(
                        LITTLE_BIGTABLE_PORT_NUMBER, application_protocol="tcp"
                    ),
                },
            ),
        }
    )

    el_uri = "http://{0}:{1}".format(
        el_client_contexts[0].ip_addr, el_client_contexts[0].rpc_port_num
    )
    redis_uri = "{0}:{1}".format(
        db_services["explorer-redis"].ip_address, REDIS_PORT_NUMBER
    )

    template_data = new_config_template_data(
        cl_client_contexts[0],
        el_uri,
        db_services["explorer-littlebigtable"].ip_address,
        LITTLE_BIGTABLE_PORT_NUMBER,
        db_services["explorer-postgres"].ip_address,
        POSTGRES_PORT_NUMBER,
        redis_uri,
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
        template_and_data_by_rel_dest_filepath, "config.yml"
    )

    # Initialize the db schema
    initdbschema = plan.add_service(
        name="explorer-initdbschema",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files={
                "/app/config/": config_files_artifact_name,
            },
            entrypoint=["./misc"],
            cmd=["-config", "/app/config/config.yml", "-command", "applyDbSchema"],
        ),
    )
    # Initialize the bigtable schema
    initbigtableschema = plan.add_service(
        name="explorer-initbigtableschema",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files={
                "/app/config/": config_files_artifact_name,
            },
            entrypoint=["./misc"],
            cmd=["-config", "/app/config/config.yml", "-command", "initBigtableSchema"],
        ),
    )
    # Start the indexer
    indexer = plan.add_service(
        name="explorer-indexer",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files={
                "/app/config/": config_files_artifact_name,
            },
            entrypoint=["./explorer"],
            cmd=[
                "-config",
                "/app/config/config.yml",
            ],
            env_vars={
                "INDEXER_ENABLED": "TRUE",
            },
        ),
    )
    # Start the eth1indexer
    eth1indexer = plan.add_service(
        name="explorer-eth1indexer",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files={
                "/app/config/": config_files_artifact_name,
            },
            entrypoint=["./eth1indexer"],
            cmd=[
                "-config",
                "/app/config/config.yml",
                "-blocks.concurrency",
                "1",
                "-blocks.tracemode",
                "geth",
                "-data.concurrency",
                "1",
                "-balances.enabled",
            ],
        ),
    )

    rewardsexporter = plan.add_service(
        name="explorer-rewardsexporter",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files={
                "/app/config/": config_files_artifact_name,
            },
            entrypoint=["./rewards-exporter"],
            cmd=[
                "-config",
                "/app/config/config.yml",
            ],
        ),
    )

    statistics = plan.add_service(
        name="explorer-statistics",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files={
                "/app/config/": config_files_artifact_name,
            },
            entrypoint=["./statistics"],
            cmd=[
                "-config",
                "/app/config/config.yml",
                "-charts.enabled",
                "-graffiti.enabled",
                "-validators.enabled",
            ],
        ),
    )

    fdu = plan.add_service(
        name="explorer-fdu",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files={
                "/app/config/": config_files_artifact_name,
            },
            entrypoint=["./frontend-data-updater"],
            cmd=[
                "-config",
                "/app/config/config.yml",
            ],
        ),
    )

    frontend = plan.add_service(
        name="explorer-frontend",
        config=ServiceConfig(
            image=IMAGE_NAME,
            files={
                "/app/config/": config_files_artifact_name,
            },
            entrypoint=["./explorer"],
            cmd=[
                "-config",
                "/app/config/config.yml",
            ],
            env_vars={
                "FRONTEND_ENABLED": "TRUE",
            },
            ports={
                FRONTEND_PORT_ID: PortSpec(
                    FRONTEND_PORT_NUMBER, application_protocol="http"
                ),
            },
        ),
    )


def new_config_template_data(
    cl_node_info, el_uri, lbt_host, lbt_port, db_host, db_port, redis_uri, frontend_port
):
    return {
        "CLNodeHost": cl_node_info.ip_addr,
        "CLNodePort": cl_node_info.http_port_num,
        "ELNodeEndpoint": el_uri,
        "LBTHost": lbt_host,
        "LBTPort": lbt_port,
        "DBHost": db_host,
        "DBPort": db_port,
        "RedisEndpoint": redis_uri,
        "FrontendPort": frontend_port,
    }


def new_cl_client_info(ip_addr, port_num, service_name):
    return {"IPAddr": ip_addr, "PortNum": port_num, "Name": service_name}
