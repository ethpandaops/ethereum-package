shared_utils = import_module("../../../shared_utils/shared_utils.star")
input_parser = import_module("../../../package_io/input_parser.star")
static_files = import_module("../../../static_files/static_files.star")
constants = import_module("../../../package_io/constants.star")
flashbots_relay = import_module("../mev_relay/mev_relay_launcher.star")
lighthouse = import_module("../../../cl/lighthouse/lighthouse_launcher.star")
# MEV Builder flags

MEV_BUILDER_CONFIG_FILENAME = "config.toml"
MEV_BUILDER_MOUNT_DIRPATH_ON_SERVICE = "/config/"
MEV_BUILDER_FILES_ARTIFACT_NAME = "mev-rbuilder-config"
MEV_FILE_PATH_ON_CONTAINER = (
    MEV_BUILDER_MOUNT_DIRPATH_ON_SERVICE + MEV_BUILDER_CONFIG_FILENAME
)


def new_builder_config(
    plan,
    service_name,
    network_params,
    fee_recipient,
    mnemonic,
    mev_params,
    participants,
    global_node_selectors,
):
    num_of_participants = shared_utils.zfill_custom(
        len(participants), len(str(len(participants)))
    )
    builder_template_data = new_builder_config_template_data(
        network_params,
        constants.DEFAULT_MEV_PUBKEY,
        constants.DEFAULT_MEV_SECRET_KEY[2:],  # drop the 0x prefix
        mnemonic,
        fee_recipient,
        mev_params.mev_builder_extra_data,
        num_of_participants,
        mev_params.mev_builder_subsidy,
    )
    flashbots_builder_config_template = read_file(
        static_files.FLASHBOTS_RBUILDER_CONFIG_FILEPATH
    )

    template_and_data = shared_utils.new_template_and_data(
        flashbots_builder_config_template, builder_template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        MEV_BUILDER_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, MEV_BUILDER_FILES_ARTIFACT_NAME
    )

    config_file_path = shared_utils.path_join(
        MEV_BUILDER_MOUNT_DIRPATH_ON_SERVICE, MEV_BUILDER_CONFIG_FILENAME
    )

    return config_files_artifact_name


def new_builder_config_template_data(
    network_params,
    pubkey,
    secret,
    mnemonic,
    fee_recipient,
    extra_data,
    num_of_participants,
    subsidy,
):
    return {
        "Network": network_params.network
        if network_params.network in constants.PUBLIC_NETWORKS
        else "/network-configs/genesis.json",
        "DataDir": "/data/reth/execution-data",
        "CLEndpoint": "http://cl-{0}-{1}-{2}:{3}".format(
            num_of_participants,
            constants.CL_TYPE.lighthouse,
            constants.EL_TYPE.reth_builder,
            lighthouse.BEACON_HTTP_PORT_NUM,
        ),
        "GenesisForkVersion": constants.GENESIS_FORK_VERSION,
        "Relay": "mev-relay-api",
        "RelayPort": flashbots_relay.MEV_RELAY_ENDPOINT_PORT,
        "PublicKey": pubkey,
        "SecretKey": secret,
        "Mnemonic": mnemonic,
        "FeeRecipient": fee_recipient,
        "ExtraData": extra_data,
        "Subsidy": subsidy,
    }
