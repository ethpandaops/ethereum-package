shared_utils = import_module("../../../shared_utils/shared_utils.star")
input_parser = import_module("../../../package_io/input_parser.star")
static_files = import_module("../../../static_files/static_files.star")
constants = import_module("../../../package_io/constants.star")

MEV_RELAY_CONFIG_FILENAME = "config.toml"
MEV_RELAY_MOUNT_DIRPATH_ON_SERVICE = "/config"
MEV_RELAY_FILES_ARTIFACT_NAME = "mev-rs-relay-config"

MEV_RELAY_ENDPOINT_PORT = 28545

USED_PORTS = {
    "http": shared_utils.new_port_spec(
        MEV_RELAY_ENDPOINT_PORT,
        "TCP",
    )
}

# The min/max CPU/memory that mev-relay can use
MIN_CPU = 10
MAX_CPU = 500
MIN_MEMORY = 16
MAX_MEMORY = 256


def launch_mev_relay(
    plan,
    mev_params,
    network,
    beacon_uri,
    el_cl_genesis_data,
    port_publisher,
    index,
    global_node_selectors,
):
    node_selectors = global_node_selectors
    image = mev_params.mev_relay_image
    network = (
        network
        if network in constants.PUBLIC_NETWORKS
        else constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
    )

    public_ports = shared_utils.get_mev_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        0,
    )
    relay_template_data = new_relay_config_template_data(
        network,
        MEV_RELAY_ENDPOINT_PORT,
        beacon_uri,
        constants.DEFAULT_MEV_PUBKEY,
        constants.DEFAULT_MEV_SECRET_KEY,
    )

    mev_rs_relay_config_template = read_file(
        static_files.MEV_RS_MEV_RELAY_CONFIG_FILEPATH
    )

    template_and_data = shared_utils.new_template_and_data(
        mev_rs_relay_config_template, relay_template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        MEV_RELAY_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, MEV_RELAY_FILES_ARTIFACT_NAME
    )

    config_file_path = shared_utils.path_join(
        MEV_RELAY_MOUNT_DIRPATH_ON_SERVICE, MEV_RELAY_CONFIG_FILENAME
    )

    mev_relay_service = plan.add_service(
        name="mev-rs-relay",
        config=ServiceConfig(
            image=image,
            cmd=[
                "relay",
                config_file_path,
            ],
            files={
                MEV_RELAY_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data,
            },
            ports=USED_PORTS,
            public_ports=public_ports,
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=node_selectors,
            env_vars={"RUST_BACKTRACE": "1"},
        ),
    )

    return (
        "http://{0}@{1}:{2}".format(
            constants.DEFAULT_MEV_PUBKEY,
            mev_relay_service.ip_address,
            MEV_RELAY_ENDPOINT_PORT,
        ),
        mev_relay_service.ip_address,
        MEV_RELAY_ENDPOINT_PORT,
    )


def new_relay_config_template_data(network, port, beacon_uri, pubkey, secret):
    return {
        "Network": network,
        "Port": port,
        "BeaconNodeURL": beacon_uri,
        "PublicKey": pubkey,
        "SecretKey": secret,
    }
