shared_utils = import_module("../../../shared_utils/shared_utils.star")
mev_boost_context_module = import_module("../mev_boost/mev_boost_context.star")
input_parser = import_module("../../../package_io/input_parser.star")
constants = import_module("../../../package_io/constants.star")
static_files = import_module("../../../static_files/static_files.star")

FLASHBOTS_MEV_BOOST_PROTOCOL = "TCP"

USED_PORTS = {
    "http": shared_utils.new_port_spec(
        constants.MEV_BOOST_PORT, shared_utils.TCP_PROTOCOL, wait="5s"
    )
}

NETWORK_ID_TO_NAME = {
    "1": "mainnet",
    "17000": "holesky",
    "11155111": "sepolia",
    "560048": "hoodi",
}

# The min/max CPU/memory that mev-boost can use
MIN_CPU = 10
MAX_CPU = 500
MIN_MEMORY = 16
MAX_MEMORY = 256

MEV_BOOST_CONFIG_FILENAME = "config.yaml"
MEV_BOOST_CONFIG_MOUNT_DIRPATH = "/config/"


def launch(
    plan,
    mev_boost_launcher,
    service_name,
    genesis_timestamp,
    mev_boost_image,
    mev_boost_args,
    participant,
    seconds_per_slot,
    port_publisher,
    index,
    global_node_selectors,
    global_tolerations,
    timing_games_params=None,
    relay_names=None,
):
    public_ports = shared_utils.get_mev_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        0,
    )

    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Check if any timing games are enabled
    use_config_file = False
    if timing_games_params:
        for relay_name in relay_names or []:
            if relay_name in timing_games_params:
                if timing_games_params[relay_name].get("enable_timing_games", False):
                    use_config_file = True
                    break

    config_files_artifact = None
    if use_config_file and timing_games_params and relay_names:
        config_files_artifact = generate_config_file(
            plan,
            service_name,
            mev_boost_launcher.relay_end_points,
            relay_names,
            timing_games_params,
        )

    config = get_config(
        plan,
        mev_boost_launcher,
        genesis_timestamp,
        mev_boost_image,
        mev_boost_args,
        global_node_selectors,
        tolerations,
        participant,
        seconds_per_slot,
        public_ports,
        index,
        config_files_artifact,
        timing_games_params,
        relay_names,
    )

    mev_boost_service = plan.add_service(service_name, config)

    return (
        mev_boost_context_module.new_mev_boost_context(
            mev_boost_service.name, constants.MEV_BOOST_PORT
        ),
    )


def generate_config_file(
    plan,
    service_name,
    relay_end_points,
    relay_names,
    timing_games_params,
):
    """Generate mev-boost config file with timing games settings."""
    relays = []
    for idx, endpoint in enumerate(relay_end_points):
        relay_name = relay_names[idx] if idx < len(relay_names) else "unknown"
        timing_config = timing_games_params.get(relay_name, {})

        relays.append(
            {
                "URL": endpoint,
                "EnableTimingGames": str(
                    timing_config.get("enable_timing_games", False)
                ).lower(),
                "TargetFirstRequestMs": timing_config.get(
                    "target_first_request_ms", 200
                ),
                "FrequencyGetHeaderMs": timing_config.get(
                    "frequency_get_header_ms", 100
                ),
            }
        )

    template_data = {"Relays": relays}

    mev_boost_config_template = read_file(
        static_files.FLASHBOTS_MEV_BOOST_CONFIG_FILEPATH
    )
    template_and_data = shared_utils.new_template_and_data(
        mev_boost_config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        MEV_BOOST_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath,
        "mev-boost-config-{0}".format(service_name),
    )

    return config_files_artifact_name


def get_config(
    plan,
    mev_boost_launcher,
    genesis_timestamp,
    mev_boost_image,
    mev_boost_args,
    node_selectors,
    tolerations,
    participant,
    seconds_per_slot,
    public_ports,
    participant_index,
    config_files_artifact=None,
    timing_games_params=None,
    relay_names=None,
):
    command = list(mev_boost_args)  # Make a copy to avoid modifying the original
    files = {}

    # If we have a config file, use it instead of RELAYS env var
    if config_files_artifact:
        config_file_path = shared_utils.path_join(
            MEV_BOOST_CONFIG_MOUNT_DIRPATH, MEV_BOOST_CONFIG_FILENAME
        )
        command.append("--config")
        command.append(config_file_path)
        files[MEV_BOOST_CONFIG_MOUNT_DIRPATH] = config_files_artifact

        # When using config file, we don't need RELAYS env var
        env_vars = {
            "GENESIS_FORK_VERSION": constants.GENESIS_FORK_VERSION,
            "GENESIS_TIMESTAMP": "{0}".format(genesis_timestamp),
            "BOOST_LISTEN_ADDR": "0.0.0.0:{0}".format(constants.MEV_BOOST_PORT),
            "SKIP_RELAY_SIGNATURE_CHECK": "1",
            "SLOT_SEC": str(seconds_per_slot),
        }
    else:
        # Use RELAYS env var (original behavior)
        # Build the RELAYS string with all relay endpoints
        # mev-boost accepts multiple relays separated by commas
        relay_urls = []
        for idx, endpoint in enumerate(mev_boost_launcher.relay_end_points):
            relay_url = "{0}?id={1}-{2}-relay{3}".format(
                endpoint,
                participant.cl_type,
                participant.el_type,
                idx,
            )
            relay_urls.append(relay_url)
        relays_str = ",".join(relay_urls)

        env_vars = {
            "GENESIS_FORK_VERSION": constants.GENESIS_FORK_VERSION,
            "GENESIS_TIMESTAMP": "{0}".format(genesis_timestamp),
            "BOOST_LISTEN_ADDR": "0.0.0.0:{0}".format(constants.MEV_BOOST_PORT),
            "SKIP_RELAY_SIGNATURE_CHECK": "1",
            "SLOT_SEC": str(seconds_per_slot),
            "RELAYS": relays_str,
        }

    config_args = {
        "image": mev_boost_image,
        "ports": USED_PORTS,
        "public_ports": public_ports,
        "cmd": command,
        "env_vars": env_vars,
        "min_cpu": MIN_CPU,
        "max_cpu": MAX_CPU,
        "min_memory": MIN_MEMORY,
        "max_memory": MAX_MEMORY,
        "node_selectors": node_selectors,
        "tolerations": tolerations,
        "labels": shared_utils.label_maker(
            client="mev-boost",
            client_type="mev",
            image=mev_boost_image[-constants.MAX_LABEL_LENGTH :],
            connected_client="{0}-{1}".format(participant.cl_type, participant.el_type),
            extra_labels={constants.NODE_INDEX_LABEL_KEY: str(participant_index + 1)},
            supernode=participant.supernode,
        ),
    }

    # Only add files if there are any
    if files:
        config_args["files"] = files

    return ServiceConfig(**config_args)


def new_mev_boost_launcher(should_check_relay, relay_end_points):
    return struct(
        should_check_relay=should_check_relay, relay_end_points=relay_end_points
    )
