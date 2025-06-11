shared_utils = import_module("../../../shared_utils/shared_utils.star")
mev_boost_context_module = import_module("../mev_boost/mev_boost_context.star")
input_parser = import_module("../../../package_io/input_parser.star")
static_files = import_module("../../../static_files/static_files.star")
constants = import_module("../../../package_io/constants.star")

CB_CONFIG_FILENAME = "cb-config.toml"
CB_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"
CB_CONFIG_FILES_ARTIFACT_NAME = "commit-boost-config"

USED_PORTS = {
    "http": shared_utils.new_port_spec(
        constants.MEV_BOOST_PORT, shared_utils.TCP_PROTOCOL
    )
}

# The min/max CPU/memory that mev-boost can use
MIN_CPU = 10
MAX_CPU = 500
MIN_MEMORY = 16
MAX_MEMORY = 256


def launch(
    plan,
    mev_boost_launcher,
    service_name,
    network,
    mev_params,
    relays,
    el_cl_genesis_data,
    port_publisher,
    index,
    global_node_selectors,
    final_genesis_timestamp,
):
    network = (
        network
        if network in constants.PUBLIC_NETWORKS
        else constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/config.yaml"
    )

    public_ports = shared_utils.get_mev_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        0,
    )

    image = mev_params.mev_boost_image
    template_data = new_config_template_data(
        network, constants.MEV_BOOST_PORT, relays, final_genesis_timestamp
    )

    commit_boost_config_template = read_file(static_files.COMMIT_BOOST_CONFIG_FILEPATH)

    template_and_data = shared_utils.new_template_and_data(
        commit_boost_config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[CB_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath,
        CB_CONFIG_FILES_ARTIFACT_NAME + service_name,
    )

    config_file_path = shared_utils.path_join(
        CB_CONFIG_MOUNT_DIRPATH_ON_SERVICE, CB_CONFIG_FILENAME
    )

    config = get_config(
        mev_boost_launcher,
        image,
        config_file_path,
        config_files_artifact_name,
        el_cl_genesis_data,
        global_node_selectors,
        public_ports,
    )

    mev_boost_service = plan.add_service(service_name, config)

    return mev_boost_context_module.new_mev_boost_context(
        mev_boost_service.ip_address, constants.MEV_BOOST_PORT
    )


def get_config(
    mev_boost_launcher,
    image,
    config_file_path,
    config_file,
    el_cl_genesis_data,
    node_selectors,
    public_ports,
):
    return ServiceConfig(
        image=image,
        ports=USED_PORTS,
        public_ports=public_ports,
        cmd=[],
        env_vars={
            "CB_CONFIG": config_file_path,
            "RUST_LOG": "debug",
        },
        files={
            CB_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_file,
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data,
        },
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )


def new_mev_boost_launcher(should_check_relay, relay_end_points):
    return struct(
        should_check_relay=should_check_relay, relay_end_points=relay_end_points
    )


def new_config_template_data(network, port, relays, final_genesis_timestamp):
    return {
        "Network": network,
        "Port": port,
        "Relays": relays,
        "Timestamp": final_genesis_timestamp,
    }
