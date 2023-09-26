shared_utils = import_module(
    "github.com/kurtosis-tech/eth-network-package/shared_utils/shared_utils.star"
)
el_genesis = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/el_genesis/el_genesis_data.star"
)
prelaunch_data_generator_launcher = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/prelaunch_data_generator_launcher/prelaunch_data_generator_launcher.star"
)

CONFIG_DIRPATH_ON_GENERATOR = "/config"
GENESIS_CONFIG_FILENAME = "genesis-config.yaml"

OUTPUT_DIRPATH_ON_GENERATOR = "/output"

GETH_GENESIS_FILENAME = "genesis.json"
ERIGON_GENESIS_FILENAME = "erigon.json"
NETHERMIND_GENESIS_FILENAME = "nethermind.json"
BESU_GENESIS_FILENAME = "besu.json"
TRUSTED_SETUP_FILENAME = "trusted_setup.txt"

JWT_SECRET_FILENAME = "jwtsecret"

SUCCESSFUL_EXEC_CMD_EXIT_CODE = 0


# Mapping of output genesis filename -> generator to create the file
all_genesis_generation_cmds = {
    GETH_GENESIS_FILENAME: lambda genesis_config_filepath_on_generator: [
        "python3",
        "/apps/el-gen/genesis_geth.py",
        genesis_config_filepath_on_generator,
    ],
    ERIGON_GENESIS_FILENAME: lambda genesis_config_filepath_on_generator: [
        "python3",
        "/apps/el-gen/genesis_geth.py",
        genesis_config_filepath_on_generator,
    ],
    NETHERMIND_GENESIS_FILENAME: lambda genesis_config_filepath_on_generator: [
        "python3",
        "/apps/el-gen/genesis_chainspec.py",
        genesis_config_filepath_on_generator,
    ],
    BESU_GENESIS_FILENAME: lambda genesis_config_filepath_on_generator: [
        "python3",
        "/apps/el-gen/genesis_besu.py",
        genesis_config_filepath_on_generator,
    ],
}


def generate_el_genesis_data(
    plan,
    genesis_generation_config_template,
    genesis_unix_timestamp,
    network_id,
    deposit_contract_address,
    genesis_delay,
    seconds_per_slot,
    capella_fork_epoch,
    deneb_fork_epoch,
    electra_fork_epoch,
):
    template_data = genesis_generation_config_template_data(
        network_id,
        deposit_contract_address,
        genesis_unix_timestamp,
        genesis_delay,
        seconds_per_slot,
        capella_fork_epoch,
        deneb_fork_epoch,
        electra_fork_epoch,
    )

    genesis_config_file_template_and_data = shared_utils.new_template_and_data(
        genesis_generation_config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        GENESIS_CONFIG_FILENAME
    ] = genesis_config_file_template_and_data

    genesis_generation_config_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, name="genesis-generation-config-el"
    )

    # TODO(old) Make this the actual data generator - comment copied from the original module
    launcher_service_name = (
        prelaunch_data_generator_launcher.launch_prelaunch_data_generator(
            plan,
            {
                CONFIG_DIRPATH_ON_GENERATOR: genesis_generation_config_artifact_name,
            },
            "el-genesis-data",
            capella_fork_epoch,
            electra_fork_epoch,
        )
    )

    all_dirpaths_to_create_on_generator = [
        CONFIG_DIRPATH_ON_GENERATOR,
        OUTPUT_DIRPATH_ON_GENERATOR,
    ]

    all_dirpath_creation_commands = []

    for dirpath_to_create_on_generator in all_dirpaths_to_create_on_generator:
        all_dirpath_creation_commands.append(
            "mkdir -p {0}".format(dirpath_to_create_on_generator),
        )

    dir_creation_cmd = [
        "bash",
        "-c",
        " && ".join(all_dirpath_creation_commands),
    ]

    dir_creation_cmd_result = plan.exec(
        recipe=ExecRecipe(command=dir_creation_cmd), service_name=launcher_service_name
    )
    plan.verify(dir_creation_cmd_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)

    genesis_config_filepath_on_generator = shared_utils.path_join(
        CONFIG_DIRPATH_ON_GENERATOR, GENESIS_CONFIG_FILENAME
    )
    genesis_filename_to_relative_filepath_in_artifact = {}
    for output_filename, generation_cmd in all_genesis_generation_cmds.items():
        cmd = generation_cmd(genesis_config_filepath_on_generator)
        output_filepath_on_generator = shared_utils.path_join(
            OUTPUT_DIRPATH_ON_GENERATOR, output_filename
        )
        cmd.append(">")
        cmd.append(output_filepath_on_generator)
        cmd_to_execute = ["bash", "-c", " ".join(cmd)]

        cmd_to_execute_result = plan.exec(
            recipe=ExecRecipe(command=cmd_to_execute),
            service_name=launcher_service_name,
        )
        plan.verify(cmd_to_execute_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)

        genesis_filename_to_relative_filepath_in_artifact[
            output_filename
        ] = shared_utils.path_join(
            shared_utils.path_base(OUTPUT_DIRPATH_ON_GENERATOR),
            output_filename,
        )

    shared_utils.download_trusted_setup(
        plan,
        launcher_service_name,
        shared_utils.path_join(OUTPUT_DIRPATH_ON_GENERATOR, TRUSTED_SETUP_FILENAME),
    )

    jwt_secret_filepath_on_generator = shared_utils.path_join(
        OUTPUT_DIRPATH_ON_GENERATOR, JWT_SECRET_FILENAME
    )
    jwt_secret_generation_cmd = [
        "bash",
        "-c",
        "openssl rand -hex 32 | tr -d \"\\n\" | sed 's/^/0x/' > {0}".format(
            jwt_secret_filepath_on_generator,
        ),
    ]

    jwt_secret_generation_cmd_result = plan.exec(
        recipe=ExecRecipe(command=jwt_secret_generation_cmd),
        service_name=launcher_service_name,
    )
    plan.verify(
        jwt_secret_generation_cmd_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE
    )

    el_genesis_data_artifact_name = plan.store_service_files(
        launcher_service_name, OUTPUT_DIRPATH_ON_GENERATOR, name="el-genesis-data"
    )

    result = el_genesis.new_el_genesis_data(
        el_genesis_data_artifact_name,
        shared_utils.path_join(
            shared_utils.path_base(OUTPUT_DIRPATH_ON_GENERATOR), JWT_SECRET_FILENAME
        ),
        genesis_filename_to_relative_filepath_in_artifact[GETH_GENESIS_FILENAME],
        genesis_filename_to_relative_filepath_in_artifact[ERIGON_GENESIS_FILENAME],
        genesis_filename_to_relative_filepath_in_artifact[NETHERMIND_GENESIS_FILENAME],
        genesis_filename_to_relative_filepath_in_artifact[BESU_GENESIS_FILENAME],
    )

    # TODO(gyani) remove the container when the job is done - this is a resource leaker
    return result


def genesis_generation_config_template_data(
    network_id,
    deposit_contract_address,
    unix_timestamp,
    genesis_delay,
    seconds_per_slot,
    capella_fork_epoch,
    deneb_fork_epoch,
    electra_fork_epoch,
):
    return {
        "NetworkId": network_id,
        "DepositContractAddress": deposit_contract_address,
        "UnixTimestamp": unix_timestamp,
        "GenesisDelay": genesis_delay,
        "SecondsPerSlot": seconds_per_slot,
        "CapellaForkEpoch": capella_fork_epoch,
        "DenebForkEpoch": deneb_fork_epoch,
        "ElectraForkEpoch": electra_fork_epoch,
    }
