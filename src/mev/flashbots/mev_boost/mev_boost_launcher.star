shared_utils = import_module("../../../shared_utils/shared_utils.star")
mev_boost_context_module = import_module("../mev_boost/mev_boost_context.star")
input_parser = import_module("../../../package_io/input_parser.star")

FLASHBOTS_MEV_BOOST_PROTOCOL = "TCP"

USED_PORTS = {
    "api": shared_utils.new_port_spec(
        input_parser.MEV_BOOST_PORT, shared_utils.TCP_PROTOCOL, wait="5s"
    )
}

NETWORK_ID_TO_NAME = {
    "1": "mainnet",
    "17000": "holesky",
    "11155111": "sepolia",
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
    command = mev_boost_args

    return ServiceConfig(
        image=mev_boost_image,
        ports=USED_PORTS,
        cmd=command,
        env_vars={
            # TODO(maybe) remove the hardcoding
            # This is set to match this file https://github.com/ethpandaops/ethereum-package/blob/main/static_files/genesis-generation-config/cl/config.yaml.tmpl#L11
            # latest-notes
            # does this need genesis time to be set as well
            "GENESIS_FORK_VERSION": "0x10000038",
            "BOOST_LISTEN_ADDR": "0.0.0.0:{0}".format(input_parser.MEV_BOOST_PORT),
            # maybe this is breaking; this isn't verifyign the bid and not sending it to the validator
            "SKIP_RELAY_SIGNATURE_CHECK": "1",
            "RELAYS": mev_boost_launcher.relay_end_points[0],
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
