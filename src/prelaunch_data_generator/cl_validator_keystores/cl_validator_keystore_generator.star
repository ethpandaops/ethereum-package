prelaunch_data_generator_launcher = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/prelaunch_data_generator_launcher/prelaunch_data_generator_launcher.star"
)

shared_utils = import_module(
    "github.com/kurtosis-tech/eth-network-package/shared_utils/shared_utils.star"
)
keystore_files_module = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/cl_validator_keystores/keystore_files.star"
)
keystores_result = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/cl_validator_keystores/generate_keystores_result.star"
)


NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR = "/node-{0}-keystores"

# Prysm keystores are encrypted with a password
PRYSM_PASSWORD = "password"
PRYSM_PASSWORD_FILEPATH_ON_GENERATOR = "/tmp/prysm-password.txt"

KEYSTORES_GENERATION_TOOL_NAME = "eth2-val-tools"

SUCCESSFUL_EXEC_CMD_EXIT_CODE = 0

RAW_KEYS_DIRNAME = "keys"
RAW_SECRETS_DIRNAME = "secrets"

NIMBUS_KEYS_DIRNAME = "nimbus-keys"
PRYSM_DIRNAME = "prysm"

TEKU_KEYS_DIRNAME = "teku-keys"
TEKU_SECRETS_DIRNAME = "teku-secrets"

KEYSTORE_GENERATION_FINISHED_FILEPATH_FORMAT = "/tmp/keystores_generated-{0}-{1}"


# Generates keystores for the given number of nodes from the given mnemonic, where each keystore contains approximately
#
# 	num_keys / num_nodes keys
def generate_cl_validator_keystores(plan, mnemonic, participants):
    service_name = prelaunch_data_generator_launcher.launch_prelaunch_data_generator(
        plan,
        {},
        "cl-validator-keystore",
        capella_fork_epoch=0,  # It doesn't matter how the validator keys are generated
        electra_fork_epoch=None,  # It doesn't matter how the validator keys are generated
    )

    all_output_dirpaths = []
    all_sub_command_strs = []
    running_total_validator_count = 0
    for idx, participant in enumerate(participants):
        output_dirpath = NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(idx)
        if participant.validator_count == 0:
            all_output_dirpaths.append(output_dirpath)
            continue
        start_index = running_total_validator_count
        running_total_validator_count += participant.validator_count
        stop_index = start_index + participant.validator_count

        generate_keystores_cmd = '{0} keystores --insecure --prysm-pass {1} --out-loc {2} --source-mnemonic "{3}" --source-min {4} --source-max {5}'.format(
            KEYSTORES_GENERATION_TOOL_NAME,
            PRYSM_PASSWORD,
            output_dirpath,
            mnemonic,
            start_index,
            stop_index,
        )

        all_sub_command_strs.append(generate_keystores_cmd)
        all_output_dirpaths.append(output_dirpath)

    command_str = " && ".join(all_sub_command_strs)

    command_result = plan.exec(
        recipe=ExecRecipe(command=["sh", "-c", command_str]), service_name=service_name
    )
    plan.verify(command_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)

    # Store outputs into files artifacts
    keystore_files = []
    running_total_validator_count = 0
    for idx, participant in enumerate(participants):
        output_dirpath = all_output_dirpaths[idx]
        if participant.validator_count == 0:
            keystore_files.append(None)
            continue
        padded_idx = zfill_custom(idx + 1, len(str(len(participants))))
        keystore_start_index = running_total_validator_count
        running_total_validator_count += participant.validator_count
        keystore_stop_index = (keystore_start_index + participant.validator_count) - 1
        artifact_name = "{0}-{1}-{2}-{3}-{4}".format(
            padded_idx,
            participant.cl_client_type,
            participant.el_client_type,
            keystore_start_index,
            keystore_stop_index,
        )
        artifact_name = plan.store_service_files(
            service_name, output_dirpath, name=artifact_name
        )

        # This is necessary because the way Kurtosis currently implements artifact-storing is
        base_dirname_in_artifact = shared_utils.path_base(output_dirpath)
        to_add = keystore_files_module.new_keystore_files(
            artifact_name,
            shared_utils.path_join(base_dirname_in_artifact, RAW_KEYS_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, RAW_SECRETS_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, NIMBUS_KEYS_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, PRYSM_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, TEKU_KEYS_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, TEKU_SECRETS_DIRNAME),
        )

        keystore_files.append(to_add)

    write_prysm_password_file_cmd = [
        "sh",
        "-c",
        "echo '{0}' > {1}".format(
            PRYSM_PASSWORD,
            PRYSM_PASSWORD_FILEPATH_ON_GENERATOR,
        ),
    ]
    write_prysm_password_file_cmd_result = plan.exec(
        recipe=ExecRecipe(command=write_prysm_password_file_cmd),
        service_name=service_name,
    )
    plan.verify(
        write_prysm_password_file_cmd_result["code"],
        "==",
        SUCCESSFUL_EXEC_CMD_EXIT_CODE,
    )

    prysm_password_artifact_name = plan.store_service_files(
        service_name, PRYSM_PASSWORD_FILEPATH_ON_GENERATOR, name="prysm-password"
    )

    result = keystores_result.new_generate_keystores_result(
        prysm_password_artifact_name,
        shared_utils.path_base(PRYSM_PASSWORD_FILEPATH_ON_GENERATOR),
        keystore_files,
    )

    # TODO replace this with a task so that we can get the container removed
    # we are removing  a call to remove_service for idempotency
    return result


# this is like above but runs things in parallel - for large networks that run on k8s or gigantic dockers
def generate_cl_valdiator_keystores_in_parallel(plan, mnemonic, participants):
    service_names = prelaunch_data_generator_launcher.launch_prelaunch_data_generator_parallel(
        plan,
        {},
        ["cl-validator-keystore-" + str(idx) for idx in range(0, len(participants))],
        capella_fork_epoch=0,  # It doesn't matter how the validator keys are generated
        electra_fork_epoch=None,
    )  # It doesn't matter how the validator keys are generated

    all_output_dirpaths = []
    all_generation_commands = []
    finished_files_to_verify = []
    running_total_validator_count = 0
    for idx, participant in enumerate(participants):
        output_dirpath = NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(idx)
        if participant.validator_count == 0:
            all_output_dirpaths.append(output_dirpath)
            continue
        start_index = idx * participant.validator_count
        stop_index = (idx + 1) * participant.validator_count
        generation_finished_filepath = (
            KEYSTORE_GENERATION_FINISHED_FILEPATH_FORMAT.format(start_index, stop_index)
        )
        finished_files_to_verify.append(generation_finished_filepath)

        generate_keystores_cmd = 'nohup {0} keystores --insecure --prysm-pass {1} --out-loc {2} --source-mnemonic "{3}" --source-min {4} --source-max {5} && touch {6}'.format(
            KEYSTORES_GENERATION_TOOL_NAME,
            PRYSM_PASSWORD,
            output_dirpath,
            mnemonic,
            start_index,
            stop_index,
            generation_finished_filepath,
        )
        all_generation_commands.append(generate_keystores_cmd)
        all_output_dirpaths.append(output_dirpath)

    # spin up all jobs
    for idx in range(0, len(participants)):
        service_name = service_names[idx]
        generation_command = all_generation_commands[idx]
        plan.exec(
            recipe=ExecRecipe(
                command=["sh", "-c", generation_command + " >/dev/null 2>&1 &"]
            ),
            service_name=service_name,
        )

    # verify that files got created
    for idx in range(0, len(participants)):
        service_name = service_names[idx]
        output_dirpath = all_output_dirpaths[idx]
        generation_finished_filepath = finished_files_to_verify[idx]
        verificaiton_command = ["ls", generation_finished_filepath]
        plan.wait(
            recipe=ExecRecipe(command=verificaiton_command),
            service_name=service_name,
            field="code",
            assertion="==",
            target_value=0,
            timeout="5m",
            interval="0.5s",
        )

    # Store outputs into files artifacts
    keystore_files = []
    running_total_validator_count = 0
    for idx, participant in enumerate(participants):
        if participant.validator_count == 0:
            keystore_files.append(None)
            continue
        service_name = service_names[idx]
        output_dirpath = all_output_dirpaths[idx]

        running_total_validator_count += participant.validator_count
        padded_idx = zfill_custom(idx + 1, len(str(len(participants))))
        keystore_start_index = running_total_validator_count
        running_total_validator_count += participant.validator_count
        keystore_stop_index = (keystore_start_index + participant.validator_count) - 1
        artifact_name = "{0}-{1}-{2}-{3}-{4}".format(
            padded_idx,
            participant.cl_client_type,
            participant.el_client_type,
            keystore_start_index,
            keystore_stop_index,
        )
        artifact_name = plan.store_service_files(
            service_name, output_dirpath, name=artifact_name
        )

        # This is necessary because the way Kurtosis currently implements artifact-storing is
        base_dirname_in_artifact = shared_utils.path_base(output_dirpath)
        to_add = keystore_files_module.new_keystore_files(
            artifact_name,
            shared_utils.path_join(base_dirname_in_artifact, RAW_KEYS_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, RAW_SECRETS_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, NIMBUS_KEYS_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, PRYSM_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, TEKU_KEYS_DIRNAME),
            shared_utils.path_join(base_dirname_in_artifact, TEKU_SECRETS_DIRNAME),
        )

        keystore_files.append(to_add)

    write_prysm_password_file_cmd = [
        "sh",
        "-c",
        "echo '{0}' > {1}".format(
            PRYSM_PASSWORD,
            PRYSM_PASSWORD_FILEPATH_ON_GENERATOR,
        ),
    ]
    write_prysm_password_file_cmd_result = plan.exec(
        recipe=ExecRecipe(command=write_prysm_password_file_cmd),
        service_name=service_names[0],
    )
    plan.verify(
        write_prysm_password_file_cmd_result["code"],
        "==",
        SUCCESSFUL_EXEC_CMD_EXIT_CODE,
    )

    prysm_password_artifact_name = plan.store_service_files(
        service_names[0], PRYSM_PASSWORD_FILEPATH_ON_GENERATOR, name="prysm-password"
    )

    result = keystores_result.new_generate_keystores_result(
        prysm_password_artifact_name,
        shared_utils.path_base(PRYSM_PASSWORD_FILEPATH_ON_GENERATOR),
        keystore_files,
    )

    # we don't cleanup the containers as its a costly operation
    return result


def zfill_custom(value, width):
    return ("0" * (width - len(str(value)))) + str(value)
