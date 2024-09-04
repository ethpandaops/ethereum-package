shared_utils = import_module("../../../shared_utils/shared_utils.star")
mev_boost_context_module = import_module("../mev_boost/mev_boost_context.star")
input_parser = import_module("../../../package_io/input_parser.star")
static_files = import_module("../../../static_files/static_files.star")
constants = import_module("../../../package_io/constants.star")

MEV_BOOST_CONFIG_FILENAME = "config.toml"
MEV_BOOST_MOUNT_DIRPATH_ON_SERVICE = "/config"
MEV_BOOST_FILES_ARTIFACT_NAME = "mev-rs-mev-boost-config"

USED_PORTS = {
    "http": shared_utils.new_port_spec(
        input_parser.MEV_BOOST_PORT, shared_utils.TCP_PROTOCOL
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
    global_node_selectors,
):
    network = (
        network
        if network in constants.PUBLIC_NETWORKS
        else constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
    )
    image = mev_params.mev_boost_image
    template_data = new_config_template_data(
        network,
        input_parser.MEV_BOOST_PORT,
        relays,
    )

    mev_rs_boost_config_template = read_file(
        static_files.MEV_RS_MEV_BOOST_CONFIG_FILEPATH
    )

    template_and_data = shared_utils.new_template_and_data(
        mev_rs_boost_config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        MEV_BOOST_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath,
        MEV_BOOST_FILES_ARTIFACT_NAME + service_name,
    )

    config_file_path = shared_utils.path_join(
        MEV_BOOST_MOUNT_DIRPATH_ON_SERVICE, MEV_BOOST_CONFIG_FILENAME
    )

    config = get_config(
        mev_boost_launcher,
        image,
        config_file_path,
        config_files_artifact_name,
        el_cl_genesis_data,
        global_node_selectors,
    )

    mev_boost_service = plan.add_service(service_name, config)

    return mev_boost_context_module.new_mev_boost_context(
        mev_boost_service.ip_address, input_parser.MEV_BOOST_PORT
    )


def get_config(
    mev_boost_launcher,
    image,
    config_file_path,
    config_file,
    el_cl_genesis_data,
    node_selectors,
):
    return ServiceConfig(
        image=image,
        ports=USED_PORTS,
        cmd=[
            "boost",
            config_file_path,
        ],
        files={
            MEV_BOOST_MOUNT_DIRPATH_ON_SERVICE: config_file,
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


def new_config_template_data(network, port, relays):
    return {
        "Network": network,
        "Port": port,
        "Relays": relays,
    }
