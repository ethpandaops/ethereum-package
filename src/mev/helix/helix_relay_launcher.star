postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")
constants = import_module("../../package_io/constants.star")
shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
static_files = import_module("../../static_files/static_files.star")

HELIX_RELAY_NAME = "helix-relay"

HTTP_PORT_ID = "http"
ENDPOINT_PORT_ID = "endpoint"

HELIX_RELAY_CONFIG_FILENAME = "config.yaml"
HELIX_RELAY_MOUNT_DIRPATH_ON_SERVICE = "/config/"
HELIX_RELAY_FILES_ARTIFACT_NAME = "helix-relay-config"

HELIX_RELAY_ENDPOINT_PORT = 4040
HELIX_RELAY_WEBSITE_PORT = 9060

USED_PORTS = {
    ENDPOINT_PORT_ID: shared_utils.new_port_spec(
        HELIX_RELAY_ENDPOINT_PORT,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HELIX_RELAY_WEBSITE_PORT,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

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


def launch_helix_relay(
    plan,
    network_params,
    mev_params,
    beacon_uris,
    genesis_validators_root,
    genesis_timestamp,
    blocksim_uri,
    persistent,
    port_publisher,
    index,
    global_node_selectors,
    global_tolerations,
    el_cl_genesis_data,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)
    public_ports = {}
    endpoint_public_port = shared_utils.get_mev_public_port(
        port_publisher,
        ENDPOINT_PORT_ID,
        index,
        0,
    )
    public_ports.update(endpoint_public_port)
    website_public_port = shared_utils.get_mev_public_port(
        port_publisher,
        HTTP_PORT_ID,
        index,
        1,
    )
    public_ports.update(website_public_port)

    node_selectors = global_node_selectors

    postgres = postgres_module.run(
        plan,
        password="postgres",
        user="postgres",
        database="postgres",
        service_name="helix-relay-postgres",
        image="timescale/timescaledb:latest-pg15",
        persistent=persistent,
        launch_adminer=mev_params.launch_adminer,
        min_cpu=POSTGRES_MIN_CPU,
        max_cpu=POSTGRES_MAX_CPU,
        min_memory=POSTGRES_MIN_MEMORY,
        max_memory=POSTGRES_MAX_MEMORY,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )

    # Generate configuration file using template
    helix_template_data = new_helix_relay_config_template_data(
        network_params,
        genesis_timestamp,
        blocksim_uri,
        beacon_uris,
        genesis_validators_root,
        postgres,
    )

    # Read the helix config template
    helix_config_template = read_file(static_files.HELIX_RELAY_CONFIG_FILEPATH)
    template_and_data = shared_utils.new_template_and_data(
        helix_config_template, helix_template_data
    )

    # Prepare template data for rendering
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        HELIX_RELAY_CONFIG_FILENAME
    ] = template_and_data

    # Render the configuration file
    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, HELIX_RELAY_FILES_ARTIFACT_NAME
    )

    # Path where config file will be mounted in container
    config_file_path = shared_utils.path_join(
        HELIX_RELAY_MOUNT_DIRPATH_ON_SERVICE, HELIX_RELAY_CONFIG_FILENAME
    )

    env_vars = {
        "RELAY_KEY": constants.DEFAULT_MEV_SECRET_KEY,
    }

    endpoint = plan.add_service(
        name=HELIX_RELAY_NAME,
        config=ServiceConfig(
            image=mev_params.mev_relay_image,
            cmd=["--config", config_file_path],
            files={
                HELIX_RELAY_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data,
            },
            ports=USED_PORTS,
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
        constants.DEFAULT_MEV_PUBKEY, endpoint.ip_address, HELIX_RELAY_ENDPOINT_PORT
    )


def new_helix_relay_config_template_data(
    network_params,
    genesis_timestamp,
    blocksim_uri,
    beacon_uris,
    genesis_validators_root,
    postgres,
):
    return {
        "NETWORK_NAME": network_params.network,
        "GENESIS_TIME": genesis_timestamp,
        "BLOCKSIM_URI": blocksim_uri,
        "BEACON_URI": beacon_uris,
        "GENESIS_VALIDATORS_ROOT": genesis_validators_root,
        "POSTGRES_HOST_NAME": postgres.service.name,
        "POSTGRES_PORT": 5432,
        "POSTGRES_DB": "postgres",
        "POSTGRES_USER": "postgres",
        "POSTGRES_PASS": "postgres",
        "HELIX_RELAY_ENDPOINT_PORT": HELIX_RELAY_ENDPOINT_PORT,
        "HELIX_RELAY_WEBSITE_PORT": HELIX_RELAY_WEBSITE_PORT,
        "HELIX_RELAY_ENDPOINT_URL": "helix-relay:{}".format(HELIX_RELAY_ENDPOINT_PORT),
        "HELIX_RELAY_PUBKEY": constants.DEFAULT_MEV_PUBKEY,
        "GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER": constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
    }
