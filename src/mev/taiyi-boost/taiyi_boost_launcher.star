shared_utils = import_module("../../shared_utils/shared_utils.star")
mev_boost_context_module = import_module("./context.star")
input_parser = import_module("../../package_io/input_parser.star")
static_files = import_module("../../static_files/static_files.star")
constants = import_module("../../package_io/constants.star")

TAIYI_JWT = "67b7ad4fc9d58fbe8c11ea04a48f678d85fd36cef983c446c5a164738c4986b8"

CB_CONFIG_FILENAME = "cb-config.toml"
CB_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"
CB_CONFIG_FILES_ARTIFACT_NAME = "commit-boost-config"

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
    taiyi_boost_params,
    mev_boost_launcher,
    service_name,
    network,
    mev_params,
    relays,
    el_cl_genesis_data,
    global_node_selectors,
    genesis_timestamp,
    participant,
    raw_jwt_secret,
    cb_signer_url
):
    network = (
        network
        if network in constants.PUBLIC_NETWORKS
        else constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER 
    )
    plan.print("Participant: {}".format(participant))
    plan.print("Raw JWT Secret: {}".format(raw_jwt_secret))
    plan.print("Genesis Timestamp: {}".format(genesis_timestamp))
    chain = (
        network
        if network in constants.PUBLIC_NETWORKS
        else "{" + "genesis_time_secs = {}, path = \"{}\"".format(genesis_timestamp, constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/config.yaml") + "}"
    )

    execution_api = participant.el_context.rpc_http_url
    beacon_api = participant.cl_context.beacon_http_url
    engine_api = "http://{0}:{1}".format(participant.el_context.ip_addr, participant.el_context.engine_rpc_port_num)

    image = taiyi_boost_params.taiyi_boost_image
    template_data = new_config_template_data(
        chain,
        input_parser.MEV_BOOST_PORT,
        relays,
        execution_api,
    )

    mev_rs_boost_config_template = read_file(static_files.TAIYI_BOOST_CONFIG_TEMPLATE_FILEPATH)

    template_and_data = shared_utils.new_template_and_data(
        mev_rs_boost_config_template, template_data
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
        cb_signer_url,
        execution_api,
        beacon_api,
        engine_api,
        network,
        raw_jwt_secret,
    )

    mev_boost_service = plan.add_service(service_name, config)

    return mev_boost_context_module.new_mev_boost_context(
        "adc0fe12e62c14a505ea1e655dbe4d36fa505ed57b634ba37912153d29edd45c5bc5a77764e68b98c53e3f6f8ce9fa3b",
        mev_boost_service.ip_address, input_parser.MEV_BOOST_PORT
    )


def get_config(
    mev_boost_launcher,
    image,
    config_file_path,
    config_file,
    el_cl_genesis_data,
    node_selectors,
    cb_signer_url,
    execution_api,
    beacon_api,
    engine_url,
    network,
    jwt,
):
    return ServiceConfig(
        image=image,
        ports=USED_PORTS,
        entrypoint=["taiyi-boost"],
        cmd=[
                "--execution_api",
                execution_api,
                "--beacon_api",
                beacon_api,
                "--engine_api",
                engine_url,
                "--builder_private_key",
                "0x6b845831c99c6bf43364bee624447d39698465df5c07f2cc4dca6e0acfbe46cd",
                "--network",
                network,
                "--fee_recipient",
                "0x2Cce2691cAC90Ac80dC551028FA00621d9c70a7F",
                "--engine_jwt",
                jwt,
            ],
        env_vars={
            "CB_CONFIG": config_file_path,
            "CB_SIGNER_JWT": "taiyi={}".format(TAIYI_JWT),
            "CB_SIGNER_URL": cb_signer_url,
            "RUST_LOG": "debug,cb_signer=debug,cb_pbs=debug,cb_common=debug,cb_metrics=debug",
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

def new_config_template_data(chain, port, relays, execution_api):
    return {
        "Chain": chain,
        "Port": port,
        "Relays": relays,
        "ExecutionApi": execution_api,
    }