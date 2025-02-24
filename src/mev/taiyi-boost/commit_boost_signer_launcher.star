shared_utils = import_module("../../shared_utils/shared_utils.star")
mev_boost_context_module = import_module("./context.star")
input_parser = import_module("../../package_io/input_parser.star")
static_files = import_module("../../static_files/static_files.star")
constants = import_module("../../package_io/constants.star")

TAIYI_JWT = "67b7ad4fc9d58fbe8c11ea04a48f678d85fd36cef983c446c5a164738c4986b8"

CB_CONFIG_FILENAME = "cb-config.toml"
CB_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"
CB_CONFIG_FILES_ARTIFACT_NAME = "commit-boost-config"

COMMIT_BOOST_SIGNER_PORT = 20000

USED_PORTS = {
    "http": shared_utils.new_port_spec(
        COMMIT_BOOST_SIGNER_PORT, shared_utils.TCP_PROTOCOL
    )
}

IMAGE_NAME = constants.DEFAULT_COMMIT_BOOST_SIGNER_IMAGE

# The min/max CPU/memory that mev-boost can use
MIN_CPU = 10
MAX_CPU = 500
MIN_MEMORY = 16
MAX_MEMORY = 256


def launch(
    plan,
    service_name,
    network,
    el_cl_genesis_data,
    global_node_selectors,
    genesis_timestamp,
    validator_keystore_files_artifact_uuid
):

    chain = (
        network
        if network in constants.PUBLIC_NETWORKS
        else "{" + "genesis_time_secs = {}, path = \"{}\"".format(genesis_timestamp , constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/config.yaml") + "}"
    )

    plan.print("Launching commit-boost signer module {}".format(network))
    validator_keys_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        "keys",
    )
    validator_secrets_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        "secrets",
    )
    image = IMAGE_NAME
    template_data = new_config_template_data(
        chain,
        validator_keys_dirpath,
        validator_secrets_dirpath,
    )

    mev_rs_boost_config_template = read_file(static_files.COMMIT_BOOST_SIGNER_CONFIG_TEMPLATE_FILEPATH)

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
        image,
        config_file_path,
        config_files_artifact_name,
        el_cl_genesis_data,
        global_node_selectors,
        validator_keystore_files_artifact_uuid
    )

    mev_boost_service = plan.add_service(service_name, config)

    return "http://{}:{}".format(mev_boost_service.ip_address, COMMIT_BOOST_SIGNER_PORT)


def get_config(
    image,
    config_file_path,
    config_file,
    el_cl_genesis_data,
    node_selectors,
    validator_keystore_files_artifact_uuid
):
    return ServiceConfig(
        image=image,
        ports=USED_PORTS,
        cmd=[],
        env_vars={
            "CB_CONFIG": config_file_path,
            "CB_JWTS": "taiyi={}".format(TAIYI_JWT),
            "CB_SIGNER_PORT": "{}".format(COMMIT_BOOST_SIGNER_PORT)
        },
        files={
            CB_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_file,
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data,
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: validator_keystore_files_artifact_uuid
        },
        user = User(uid=0),
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


def new_config_template_data(chain, keys_path, secrets_path):
    return {
        "Chain": chain,
        "KeysPath": keys_path,
        "SecretsPath": secrets_path,
    }
