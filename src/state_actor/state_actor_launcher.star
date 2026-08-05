constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

# Pre-populates client-native EL databases with state-actor
# (https://github.com/ethereum/state-actor) — one run per unique el_type,
# driven by the network's genesis.json; see README state_actor_params.
GENERATION_TIMEOUT = "60m"

SUPPORTED_EL_TYPES = ["geth", "reth", "besu", "nethermind", "ethrex", "erigon"]

ARTIFACT_NAME_PATTERN = "state-actor-{0}-data"
ANCHOR_BLOCK_ARTIFACT_NAME = "state-actor-anchor-block"
SPEC_MOUNT_DIRPATH = "/sa-spec"
SPEC_FILENAME = "spec.yaml"
FETCH_IMAGE = "alpine:3.19.1"

# Exported straight from the generation/fetch container — re-mounting the
# multi-GB datadir artifact just to copy it times out the files expander.
ANCHOR_CMD = " && mkdir -p /anchor && cp /output/genesis_block.json /anchor/latest_block.json"


def generate(
    plan,
    state_actor_params,
    participants,
    el_cl_data,
    extra_files_artifacts,
    global_tolerations,
    global_node_selectors,
    persistent=False,
    network_params=None,
):
    el_types = []
    for participant in participants:
        if (
            participant.el_type in SUPPORTED_EL_TYPES
            and participant.el_type not in el_types
        ):
            el_types.append(participant.el_type)

    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Synthetic state changes the genesis hash → CL genesis must be
    # re-anchored. Snapshots may or may not be bloated; anchoring to their
    # genesis_block.json is a no-op when they are alloc-verbatim.
    uses_snapshots = False
    for el_type in el_types:
        if state_actor_params.snapshots.get(el_type, "") != "":
            uses_snapshots = True
    adds_synthetic_state = (
        state_actor_params.target_size != ""
        or state_actor_params.spec != ""
        or uses_snapshots
    )

    spec_artifact = None
    if state_actor_params.spec != "":
        spec_artifact = plan.render_templates(
            {
                SPEC_FILENAME: struct(
                    template=state_actor_params.spec,
                    data={},
                )
            },
            "state-actor-spec",
        )

    anchor_block = ""
    anchor_store = StoreSpec(src="/anchor", name=ANCHOR_BLOCK_ARTIFACT_NAME)

    # Persistent mode: write straight into each opted-in participant's
    # persistent volume (launchers mount the same key). Files artifacts
    # can't ferry multi-GB datadirs — the expander times out.
    if persistent:
        volume_size_key = network_params.network
        if "devnet" in network_params.network:
            volume_size_key = "devnets"
        for index, participant in enumerate(participants):
            if (
                not participant.el_pre_populated_db
                or participant.el_type not in SUPPORTED_EL_TYPES
            ):
                continue
            index_str = shared_utils.zfill_custom(
                index + 1, len(str(len(participants)))
            )
            el_service_name = "el-{0}-{1}-{2}".format(
                index_str, participant.el_type, participant.cl_type
            )
            volume_size = (
                int(participant.el_volume_size)
                if int(participant.el_volume_size) > 0
                else constants.VOLUME_SIZE[volume_size_key][
                    participant.el_type.replace("-", "_") + "_volume_size"
                ]
            )
            files = {
                "/output": Directory(
                    persistent_key="data-{0}".format(el_service_name),
                    size=volume_size,
                ),
            }
            snapshot_url = state_actor_params.snapshots.get(participant.el_type, "")
            if snapshot_url != "":
                cmd = fetch_cmd(snapshot_url)
                image = FETCH_IMAGE
            else:
                cmd = generation_cmd(
                    participant.el_type, state_actor_params, spec_artifact
                )
                image = client_image(state_actor_params, participant.el_type)
                files[
                    constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
                ] = el_cl_data.files_artifact_uuid
                if spec_artifact != None:
                    files[SPEC_MOUNT_DIRPATH] = spec_artifact
            wants_anchor = adds_synthetic_state and anchor_block == ""
            if wants_anchor:
                cmd += ANCHOR_CMD
            # run_sh cannot mount persistent Directories, so use the
            # shadowfork helper-service pattern: on failure the container
            # exits (no tail) and the wait errors out immediately.
            helper_name = "state-actor-{0}".format(el_service_name)
            plan.add_service(
                name=helper_name,
                config=ServiceConfig(
                    image=image,
                    entrypoint=["/bin/sh", "-c"],
                    cmd=[cmd + " && touch /tmp/finished && tail -f /dev/null"],
                    files=files,
                    tolerations=tolerations,
                    node_selectors=global_node_selectors,
                ),
            )
            plan.wait(
                service_name=helper_name,
                recipe=ExecRecipe(command=["cat", "/tmp/finished"]),
                field="code",
                assertion="==",
                target_value=0,
                interval="5s",
                timeout=GENERATION_TIMEOUT,
            )
            if wants_anchor:
                anchor_block = plan.store_service_files(
                    service_name=helper_name,
                    src="/anchor/latest_block.json",
                    name=ANCHOR_BLOCK_ARTIFACT_NAME,
                )
            plan.remove_service(name=helper_name)
        return anchor_block

    # Artifact mode (non-persistent): one artifact per unique el_type,
    # referenced by participants via el_extra_mounts. Suited to small /
    # alloc-verbatim states; large states should use persistent: true.
    for el_type in el_types:
        artifact_name = ARTIFACT_NAME_PATTERN.format(el_type)
        wants_anchor = adds_synthetic_state and el_type == el_types[0]
        store = [StoreSpec(src="/output", name=artifact_name)]
        files = {}

        snapshot_url = state_actor_params.snapshots.get(el_type, "")
        if snapshot_url != "":
            cmd = fetch_cmd(snapshot_url)
            image = FETCH_IMAGE
            step_name = "state-actor-fetch-{0}".format(el_type)
        else:
            cmd = "mkdir -p /output && " + generation_cmd(
                el_type, state_actor_params, spec_artifact
            )
            image = client_image(state_actor_params, el_type)
            step_name = "state-actor-{0}".format(el_type)
            files[
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
            ] = el_cl_data.files_artifact_uuid
            if spec_artifact != None:
                files[SPEC_MOUNT_DIRPATH] = spec_artifact

        if wants_anchor:
            cmd += ANCHOR_CMD
            store.append(anchor_store)

        result = plan.run_sh(
            name=step_name,
            description="Pre-populating {0} database with state-actor".format(el_type),
            run=cmd,
            image=image,
            files=files,
            store=store,
            wait=GENERATION_TIMEOUT,
            tolerations=tolerations,
            node_selectors=global_node_selectors,
        )

        # Register so participants can reference the artifact from
        # el_extra_mounts (process_extra_mounts resolves against this dict).
        extra_files_artifacts[artifact_name] = result.files_artifacts[0]
        if wants_anchor:
            # All writers emit the identical genesis block (cross-client
            # invariant), so the first datadir's anchor covers the network.
            anchor_block = result.files_artifacts[1]

    return anchor_block


def generation_cmd(el_type, state_actor_params, spec_artifact):
    # geth expects its DB at <datadir>/geth/chaindata; every other
    # client's --db IS the datadir (state-actor RUNBOOK layout).
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
    if spec_artifact != None:
        cmd += " --spec={0}/{1}".format(SPEC_MOUNT_DIRPATH, SPEC_FILENAME)
    for arg in state_actor_params.extra_args:
        cmd += " {0}".format(arg)
    return cmd


def fetch_cmd(snapshot_url):
    untar = "tar -xf -"
    if snapshot_url.endswith(".zst"):
        untar = "tar -I zstd -xf -"
    elif snapshot_url.endswith(".gz") or snapshot_url.endswith(".tgz"):
        untar = "tar -xzf -"
    return "apk add --no-cache curl tar zstd >/dev/null && mkdir -p /output && curl -fsSL '{0}' | {1} -C /output && ls /output".format(
        snapshot_url, untar
    )


def client_image(state_actor_params, el_type):
    image = state_actor_params.images.get(el_type, "")
    if image == "":
        fail(
            "state_actor_params.images has no image for el_type '{0}'".format(el_type)
        )
    return image
