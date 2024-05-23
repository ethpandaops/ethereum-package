shared_utils = import_module("../../shared_utils/shared_utils.star")
keystore_files_module = import_module("./keystore_files.star")
keystores_result = import_module("./generate_keystores_result.star")

NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR = "/node-{0}-keystores{1}/"

# Prysm keystores are encrypted with a password
PRYSM_PASSWORD = "password"
PRYSM_PASSWORD_FILEPATH_ON_GENERATOR = "/tmp/prysm-password.txt"

KEYSTORES_GENERATION_TOOL_NAME = "/app/eth2-val-tools"

ETH_VAL_TOOLS_IMAGE = "protolambda/eth2-val-tools:latest"

SUCCESSFUL_EXEC_CMD_EXIT_CODE = 0

RAW_KEYS_DIRNAME = "keys"
RAW_SECRETS_DIRNAME = "secrets"

NIMBUS_KEYS_DIRNAME = "nimbus-keys"
PRYSM_DIRNAME = "prysm"

TEKU_KEYS_DIRNAME = "teku-keys"
TEKU_SECRETS_DIRNAME = "teku-secrets"

KEYSTORE_GENERATION_FINISHED_FILEPATH_FORMAT = "/tmp/keystores_generated-{0}-{1}"

SERVICE_NAME_PREFIX = "validator-key-generation-"

ENTRYPOINT_ARGS = [
    "sleep",
    "99999",
]


# Launches a prelaunch data generator IMAGE, for use in various of the genesis generation
def launch_prelaunch_data_generator(
    plan,
    files_artifact_mountpoints,
    service_name_suffix,
):
    config = get_config(files_artifact_mountpoints)

    service_name = "{0}{1}".format(
        SERVICE_NAME_PREFIX,
        service_name_suffix,
    )
    plan.add_service(service_name, config)

    return service_name


def launch_prelaunch_data_generator_parallel(
    plan, files_artifact_mountpoints, service_name_suffixes
):
    config = get_config(
        files_artifact_mountpoints,
    )
    service_names = [
        "{0}{1}".format(
            SERVICE_NAME_PREFIX,
            service_name_suffix,
        )
        for service_name_suffix in service_name_suffixes
    ]
    services_to_add = {service_name: config for service_name in service_names}
    plan.add_services(services_to_add)
    return service_names


def get_config(files_artifact_mountpoints):
    return ServiceConfig(
        image=ETH_VAL_TOOLS_IMAGE,
        entrypoint=ENTRYPOINT_ARGS,
        files=files_artifact_mountpoints,
    )


# Generates keystores for the given number of nodes from the given mnemonic, where each keystore contains approximately
#
# 	num_keys / num_nodes keys
def generate_validator_keystores(plan, mnemonic, participants):
    service_name = launch_prelaunch_data_generator(plan, {}, "cl-validator-keystore")

    all_output_dirpaths = []
    all_sub_command_strs = []
    running_total_validator_count = 0

    for idx, participant in enumerate(participants):
        output_dirpath = NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(idx, "")
        if participant.validator_count == 0:
            all_output_dirpaths.append(output_dirpath)
            continue

        for i in range(participant.vc_count):
            output_dirpath = (
                NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(idx, "-" + str(i))
                if participant.vc_count != 1
                else NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(idx, "")
            )

            start_index = running_total_validator_count + i * (
                participant.validator_count // participant.vc_count
            )
            stop_index = start_index + (
                participant.validator_count // participant.vc_count
            )

            # Adjust stop_index for the last partition to include all remaining validators
            if i == participant.vc_count - 1:
                stop_index = running_total_validator_count + participant.validator_count

            generate_keystores_cmd = '{0} keystores --insecure --prysm-pass {1} --out-loc {2} --source-mnemonic "{3}" --source-min {4} --source-max {5}'.format(
                KEYSTORES_GENERATION_TOOL_NAME,
                PRYSM_PASSWORD,
                output_dirpath,
                mnemonic,
                start_index,
                stop_index,
            )
            all_output_dirpaths.append(output_dirpath)
            all_sub_command_strs.append(generate_keystores_cmd)

            teku_permissions_cmd = "chmod 0777 -R " + output_dirpath + TEKU_KEYS_DIRNAME
            raw_secret_permissions_cmd = (
                "chmod 0600 -R " + output_dirpath + RAW_SECRETS_DIRNAME
            )
            all_sub_command_strs.append(teku_permissions_cmd)
            all_sub_command_strs.append(raw_secret_permissions_cmd)

        running_total_validator_count += participant.validator_count

    command_str = " && ".join(all_sub_command_strs)

    command_result = plan.exec(
        service_name=service_name,
        description="Generating keystores",
        recipe=ExecRecipe(command=["sh", "-c", command_str]),
    )
    plan.verify(command_result["code"], "==", SUCCESSFUL_EXEC_CMD_EXIT_CODE)

    # Store outputs into files artifacts
    keystore_files = []
    running_total_validator_count = 0
    for idx, participant in enumerate(participants):
        if participant.validator_count == 0:
            keystore_files.append(None)
            continue

        for i in range(participant.vc_count):
            output_dirpath = (
                NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(idx, "-" + str(i))
                if participant.vc_count != 1
                else NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(idx, "")
            )
            padded_idx = shared_utils.zfill_custom(idx + 1, len(str(len(participants))))

            keystore_start_index = running_total_validator_count + i * (
                participant.validator_count // participant.vc_count
            )
            keystore_stop_index = keystore_start_index + (
                participant.validator_count // participant.vc_count
            )

            if i == participant.vc_count - 1:
                keystore_stop_index = (
                    running_total_validator_count + participant.validator_count
                )

            artifact_name = "{0}-{1}-{2}-{3}-{4}-{5}".format(
                padded_idx,
                participant.cl_type,
                participant.el_type,
                keystore_start_index,
                keystore_stop_index - 1,
                i,
            )
            artifact_name = plan.store_service_files(
                service_name, output_dirpath, name=artifact_name
            )

            base_dirname_in_artifact = shared_utils.path_base(output_dirpath)
            to_add = keystore_files_module.new_keystore_files(
                artifact_name,
                shared_utils.path_join(base_dirname_in_artifact),
                shared_utils.path_join(base_dirname_in_artifact, RAW_KEYS_DIRNAME),
                shared_utils.path_join(base_dirname_in_artifact, RAW_SECRETS_DIRNAME),
                shared_utils.path_join(base_dirname_in_artifact, NIMBUS_KEYS_DIRNAME),
                shared_utils.path_join(base_dirname_in_artifact, PRYSM_DIRNAME),
                shared_utils.path_join(base_dirname_in_artifact, TEKU_KEYS_DIRNAME),
                shared_utils.path_join(base_dirname_in_artifact, TEKU_SECRETS_DIRNAME),
            )

            keystore_files.append(to_add)

        running_total_validator_count += participant.validator_count

    write_prysm_password_file_cmd = [
        "sh",
        "-c",
        "echo '{0}' > {1}".format(
            PRYSM_PASSWORD,
            PRYSM_PASSWORD_FILEPATH_ON_GENERATOR,
        ),
    ]
    write_prysm_password_file_cmd_result = plan.exec(
        service_name=service_name,
        description="Storing prysm password in a file",
        recipe=ExecRecipe(command=write_prysm_password_file_cmd),
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

    return result


# this is like above but runs things in parallel - for large networks that run on k8s or gigantic dockers
def generate_valdiator_keystores_in_parallel(plan, mnemonic, participants):
    service_names = launch_prelaunch_data_generator_parallel(
        plan,
        {},
        ["cl-validator-keystore-" + str(idx) for idx in range(0, len(participants))],
    )
    all_output_dirpaths = []
    all_generation_commands = []
    finished_files_to_verify = []
    running_total_validator_count = 0
    for idx, participant in enumerate(participants):
        output_dirpath = NODE_KEYSTORES_OUTPUT_DIRPATH_FORMAT_STR.format(idx, "")
        if participant.validator_count == 0:
            all_generation_commands.append(None)
            all_output_dirpaths.append(None)
            finished_files_to_verify.append(None)
            continue
        start_index = running_total_validator_count
        running_total_validator_count += participant.validator_count
        stop_index = start_index + participant.validator_count
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
        teku_permissions_cmd = (
            " && chmod 777 -R " + output_dirpath + "/" + TEKU_KEYS_DIRNAME
        )
        raw_secret_permissions_cmd = (
            " && chmod 0600 -R " + output_dirpath + "/" + RAW_SECRETS_DIRNAME
        )
        generate_keystores_cmd += teku_permissions_cmd
        generate_keystores_cmd += raw_secret_permissions_cmd
        all_generation_commands.append(generate_keystores_cmd)
        all_output_dirpaths.append(output_dirpath)

    # spin up all jobs
    for idx in range(0, len(participants)):
        service_name = service_names[idx]
        generation_command = all_generation_commands[idx]
        if generation_command == None:
            # no generation command as validator count is 0
            continue
        plan.exec(
            service_name=service_name,
            description="Generating keystore for participant " + str(idx),
            recipe=ExecRecipe(
                command=["sh", "-c", generation_command + " >/dev/null 2>&1 &"]
            ),
        )

    # verify that files got created
    for idx in range(0, len(participants)):
        service_name = service_names[idx]
        output_dirpath = all_output_dirpaths[idx]
        if output_dirpath == None:
            # no output dir path as validator count is 0
            continue
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
        output_dirpath = all_output_dirpaths[idx]
        if participant.validator_count == 0:
            keystore_files.append(None)
            continue
        service_name = service_names[idx]

        padded_idx = shared_utils.zfill_custom(idx + 1, len(str(len(participants))))
        keystore_start_index = running_total_validator_count
        running_total_validator_count += participant.validator_count
        keystore_stop_index = (keystore_start_index + participant.validator_count) - 1
        artifact_name = "{0}-{1}-{2}-{3}-{4}".format(
            padded_idx,
            participant.cl_type,
            participant.el_type,
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
            shared_utils.path_join(base_dirname_in_artifact),
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
        service_name=service_names[0],
        description="Storing prysm password in a file",
        recipe=ExecRecipe(command=write_prysm_password_file_cmd),
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
