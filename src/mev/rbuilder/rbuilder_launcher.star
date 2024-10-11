shared_utils = import_module("../../../shared_utils/shared_utils.star")
input_parser = import_module("../../../package_io/input_parser.star")
static_files = import_module("../../../static_files/static_files.star")
constants = import_module("../../../package_io/constants.star")
mev_rs_relay = import_module("../mev_relay/mev_relay_launcher.star")

# MEV Builder flags

MEV_BUILDER_CONFIG_FILENAME = "config.toml"
MEV_BUILDER_MOUNT_DIRPATH_ON_SERVICE = "/config"
MEV_BUILDER_FILES_ARTIFACT_NAME = "mev-rs-mev-builder-config"
MEV_FILE_PATH_ON_CONTAINER = (
    MEV_BUILDER_MOUNT_DIRPATH_ON_SERVICE + MEV_BUILDER_CONFIG_FILENAME
)

def new_builder_config(
    plan,
    service_name,
    network,
    fee_recipient,
    mnemonic,
    extra_data,
    global_node_selectors,
):
    builder_template_data = new_builder_config_template_data(
        chain,
        reth_datadir,
        coinbase_secret_key,
        relay_secret_key,
        optimistic_relay_secret_key
        cl_node_url,
        extra_data,
    )
    rbuilder_config_template = read_file(
        static_files.RBUILDER_CONFIG_FILEPATH
    )

    template_and_data = shared_utils.new_template_and_data(
        rbuilder_config_template, builder_template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        RBUILDER_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, MEV_BUILDER_FILES_ARTIFACT_NAME
    )

    config_file_path = shared_utils.path_join(
        MEV_BUILDER_MOUNT_DIRPATH_ON_SERVICE, MEV_BUILDER_CONFIG_FILENAME
    )

    return config_files_artifact_name


def new_builder_config_template_data(
    chain,
    reth_datadir,
    coinbase_secret_key,
    relay_secret_key,
    optimistic_relay_secret_key
    cl_node_url,
    extra_data,
):
    return {
        "Chain": chain,
        "RethDatadir": reth_datadir,
        "CoinBaseSecretKey": coinbase_secret_key,
        "RelaySecretKey": relay_secret_key,
        "OptimisticRelaySecretKey": optimistic_relay_secret_key,
        "ClNodeUrl": cl_node_url,
        "ExtraData": extra_data,
    }
