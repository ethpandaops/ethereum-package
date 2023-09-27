SERVICE_NAME_PREFIX = "prelaunch-data-generator-"

# We use Docker exec commands to run the commands we need, so we override the default
ENTRYPOINT_ARGS = [
    "sleep",
    "999999",
]


# Launches a prelaunch data generator IMAGE, for use in various of the genesis generation
def launch_prelaunch_data_generator(
    plan,
    files_artifact_mountpoints,
    service_name_suffix,
    capella_fork_epoch,
    electra_fork_epoch,
):
    config = get_config(
        files_artifact_mountpoints, capella_fork_epoch, electra_fork_epoch
    )

    service_name = "{0}{1}".format(
        SERVICE_NAME_PREFIX,
        service_name_suffix,
    )
    plan.add_service(service_name, config)

    return service_name


def launch_prelaunch_data_generator_parallel(
    plan,
    files_artifact_mountpoints,
    service_name_suffixes,
    capella_fork_epoch,
    electra_fork_epoch,
):
    config = get_config(
        files_artifact_mountpoints, capella_fork_epoch, electra_fork_epoch
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


def get_config(files_artifact_mountpoints, capella_fork_epoch, electra_fork_epoch):
    if capella_fork_epoch > 0 and electra_fork_epoch == None:  # we are running capella
        img = "ethpandaops/ethereum-genesis-generator:1.3.4"
    elif (
        capella_fork_epoch == 0 and electra_fork_epoch == None
    ):  # we are running dencun
        img = "ethpandaops/ethereum-genesis-generator:2.0.0-rc.6"
    else:  # we are running electra
        img = "ethpandaops/ethereum-genesis-generator:3.0.0-rc.2"

    return ServiceConfig(
        image=img,
        entrypoint=ENTRYPOINT_ARGS,
        files=files_artifact_mountpoints,
    )
