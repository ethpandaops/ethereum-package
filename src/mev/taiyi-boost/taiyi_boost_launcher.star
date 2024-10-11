shared_utils = import_module("../../shared_utils/shared_utils.star")
mev_boost_context_module = import_module("../mev_boost/mev_boost_context.star")
static_files = import_module("../../static_files/static_files.star")
constants = import_module("../../package_io/constants.star")
input_parser = import_module("../../package_io/input_parser.star")

TAIYI_BOOST_CONFIG_FILENAME="taiyi-boost-config.toml"
TAIYI_BOOST_CONFIG_MOUNT_DIRPATH_ON_SERVICE="/config"

USED_PORTS = {
    "api": shared_utils.new_port_spec(
        input_parser.MEV_BOOST_PORT, shared_utils.TCP_PROTOCOL, wait="5s"
    )
}

# The min/max CPU/memory that taiyi-boost can use
MIN_CPU = 10
MAX_CPU = 500
MIN_MEMORY = 16
MAX_MEMORY = 256

def launch_taiyi_boost(
    plan,
    mev_boost_launcher,
    service_name,
    network_id,
    mev_boost_image,
    mev_boost_args,
    global_node_selectors,
):
    config = get_config(
        mev_boost_launcher,
        network_id,
        mev_boost_image,
        mev_boost_args,
        global_node_selectors,
    )

    mev_boost_service = plan.add_service(service_name, config)

    return mev_boost_context_module.new_mev_boost_context(
        mev_boost_service.ip_address, input_parser.MEV_BOOST_PORT
    )

def get_config(
    mev_boost_launcher,
    network_id,
    mev_boost_image,
    mev_boost_args,
    node_selectors,
):
