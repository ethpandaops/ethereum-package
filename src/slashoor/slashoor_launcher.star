shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "slashoor"

SLASHOOR_CONFIG_FILENAME = "config.yaml"
SLASHOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"


def launch_slashoor(
    plan,
    config_template,
    participant_contexts,
    participant_configs,
    slashoor_params,
    global_node_selectors,
    global_tolerations,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    beacon_endpoints = []
    for index, participant in enumerate(participant_contexts):
        beacon_http_url = participant.cl_context.beacon_http_url
        beacon_endpoints.append(beacon_http_url)

    template_data = new_config_template_data(
        beacon_endpoints,
        slashoor_params,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {
        SLASHOOR_CONFIG_FILENAME: template_and_data,
    }

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "slashoor-config"
    )

    config = get_config(
        plan,
        config_files_artifact_name,
        slashoor_params,
        global_node_selectors,
        tolerations,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    plan,
    config_files_artifact_name,
    slashoor_params,
    node_selectors,
    tolerations,
):
    config_file_path = shared_utils.path_join(
        SLASHOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        SLASHOOR_CONFIG_FILENAME,
    )

    cmd = [
        "--config={}".format(config_file_path),
    ]

    if slashoor_params.log_level:
        cmd.append("--log-level={}".format(slashoor_params.log_level))

    for extra_arg in slashoor_params.extra_args:
        cmd.append(extra_arg)

    return ServiceConfig(
        image=slashoor_params.image,
        cmd=cmd,
        min_cpu=slashoor_params.min_cpu,
        max_cpu=slashoor_params.max_cpu,
        min_memory=slashoor_params.min_mem,
        max_memory=slashoor_params.max_mem,
        node_selectors=node_selectors,
        tolerations=tolerations,
        files={
            SLASHOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
    )


def new_config_template_data(
    beacon_endpoints,
    slashoor_params,
):
    return {
        "BeaconEndpoints": beacon_endpoints,
        "BeaconTimeout": slashoor_params.beacon_timeout,
        "MaxEpochsToKeep": slashoor_params.max_epochs_to_keep,
        "DetectorEnabled": slashoor_params.detector_enabled,
        "SubmitterEnabled": slashoor_params.submitter_enabled,
        "SubmitterDryRun": slashoor_params.submitter_dry_run,
    }
