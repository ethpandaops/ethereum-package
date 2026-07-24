constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

# Pre-populates client-native EL databases with state-actor
# (https://github.com/ethereum/state-actor) before the EL clients launch.
#
# One generation run happens per unique el_type among the participants,
# driven by the network's own genesis.json (state-actor --genesis), so the
# resulting DB's genesis hash matches the hash the CL genesis was built
# against. The produced datadir is stored as a files artifact named
# "state-actor-<el_type>-data" and registered in extra_files_artifacts, so
# participants opt in by mounting it at their execution data dir:
#
#   participants:
#     - el_type: geth
#       el_extra_mounts:
#         /data/geth/execution-data: state-actor-geth-data
#
# --db layout per client mirrors docs/RUNBOOK.md in the state-actor repo:
# geth wants the DB at <datadir>/geth/chaindata; every other client's --db
# IS the datadir.
GENERATION_TIMEOUT = "30m"

SUPPORTED_EL_TYPES = ["geth", "reth", "besu", "nethermind", "ethrex", "erigon"]

ARTIFACT_NAME_PATTERN = "state-actor-{0}-data"


def generate(
    plan,
    state_actor_params,
    participants,
    el_cl_data,
    extra_files_artifacts,
    global_tolerations,
    global_node_selectors,
):
    el_types = []
    for participant in participants:
        if (
            participant.el_type in SUPPORTED_EL_TYPES
            and participant.el_type not in el_types
        ):
            el_types.append(participant.el_type)

    for el_type in el_types:
        image = state_actor_params.images.get(el_type, "")
        if image == "":
            fail(
                "state_actor_params.images has no image for el_type '{0}'".format(
                    el_type
                )
            )

        db_path = "/output"
        if el_type == "geth":
            db_path = "/output/geth/chaindata"

        cmd = "state-actor --client={0} --db={1} --genesis={2}/genesis.json --seed={3}".format(
            el_type,
            db_path,
            constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER,
            state_actor_params.seed,
        )
        if state_actor_params.target_size != "":
            cmd += " --target-size={0}".format(state_actor_params.target_size)

        artifact_name = ARTIFACT_NAME_PATTERN.format(el_type)
        result = plan.run_sh(
            name="state-actor-{0}".format(el_type),
            description="Pre-populating {0} database with state-actor".format(el_type),
            run="mkdir -p /output && " + cmd,
            image=image,
            files={
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data.files_artifact_uuid,
            },
            store=[
                StoreSpec(src="/output", name=artifact_name),
            ],
            wait=GENERATION_TIMEOUT,
            tolerations=shared_utils.get_tolerations(
                global_tolerations=global_tolerations
            ),
            node_selectors=global_node_selectors,
        )

        # Registering the artifact under its name makes it referenceable
        # from participants' el_extra_mounts (process_extra_mounts resolves
        # string sources against this dict).
        extra_files_artifacts[artifact_name] = result.files_artifacts[0]
