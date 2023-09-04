shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")


SERVICE_NAME = "full-beaconchain"
IMAGE_NAME = "gobitfly/eth2-beaconchain-explorer:kurtosi"

POSTGRES_PORT_ID = "postgres"
POSTGRES_DB = "db"
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = "pass"

REDIS_PORT_ID = "redis"

FRONTEND_PORT_ID     = "http"
FRONTEND_PORT_NUMBER = 8080

LITTLE_BIGTABLE_PORT_ID = "littlebigtable"

FULL_BEACONCHAIN_CONFIG_FILENAME = "full-beaconchain-config.yaml"


USED_PORTS = {
    FRONTEND_PORT_ID:shared_utils.new_port_spec(FRONTEND_PORT_NUMBER, shared_utils.TCP_PROTOCOL, shared_utils.HTTP_APPLICATION_PROTOCOL)
}

def launch_full_beacon(
    plan,
        config_template,
        cl_client_contexts,
        el_client_contexts,
    ):

	# Add a Postgres server
    postgres = plan.add_service(
        name = "postgres",
        config = ServiceConfig(
            image = "postgres:15.2-alpine",
            ports = {
                POSTGRES_PORT_ID: PortSpec(5432, application_protocol = "postgresql"),
            },
            env_vars = {
                "POSTGRES_DB": POSTGRES_DB,
                "POSTGRES_USER": POSTGRES_USER,
                "POSTGRES_PASSWORD": POSTGRES_PASSWORD,
            },
        ),
    )
    # Add a redis server
    redis = plan.add_service(
        name = "redis",
        config = ServiceConfig(
            image = "redis:7",
            ports = {
                REDIS_PORT_ID: PortSpec(6379, application_protocol = "tcp"),
            },
        ),
    )
    # Add a little bigtable server
    littlebigtable = plan.add_service(
        name = "littlebigtable",
        config = ServiceConfig(
            image = "gobitfly/little_bigtable:latest",
            ports = {
                LITTLE_BIGTABLE_PORT_ID: PortSpec(9000, application_protocol = "tcp"),
            },
        ),
    )

    el_uri = "http://{0}:{1}".format(el_client_contexts[0].ip_addr, el_client_contexts[0].rpc_port_num)
    redis_uri = "{0}:{1}".format(redis.ip_address, 6379)

    template_data = new_config_template_data(cl_client_contexts[0], el_uri, littlebigtable.ip_address, 9000, postgres.ip_address, 5432, redis_uri)

    template_and_data = shared_utils.new_template_and_data(config_template, template_data)
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[FULL_BEACONCHAIN_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(template_and_data_by_rel_dest_filepath, "full-beaconchain-config")

    # Initialize the db schema
    initdbschema = plan.add_service(
        name = "initdbschema",
        config = ServiceConfig(
            image = "gobitfly/eth2-beaconchain-explorer:kurtosis",
            files = {
                "/app/config/": config_files_artifact_name,
            },
            entrypoint = [
                "./misc"
            ],
            cmd = [
                "-config",
                "/app/config/config.yml",
                "-command",
                "applyDbSchema"
            ],
        ),
    )


def new_config_template_data(cl_node_info, el_uri, lbt_host, lbt_port, db_host, db_port, redis_uri, frontend_port):
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
	return {
		"IPAddr": ip_addr,
		"PortNum": port_num,
		"Name": service_name
	}
