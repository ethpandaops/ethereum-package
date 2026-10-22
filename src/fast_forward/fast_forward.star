constants = import_module("../package_io/constants.star")
static_files = import_module("../static_files/static_files.star")
vc_shared = import_module("../vc/vc_shared.star")

RETH_SERVICE_NAME = "ff-reth"
DRIP_SERVICE_NAME = "ff-drip"
ENGINE_PORT = 8551
HANDOVER_ARTIFACT = "ff-handover"
CHAIN_ARTIFACT = "ff-chain"
WATERMARK_ARTIFACT = "ff-watermark"
NIMBUS_HANDOVER_ARTIFACT = "ff-handover-nimbus"
DEFAULT_NIMBUS_IMAGE = "ethpandaops/nimbus-eth2:unstable"

CHAIN_DIR = "/ff/chain"
HANDOVER_DIR = "/ff/handover"
WATERMARK_DIR = "/ff/watermark"
SCRIPTS_DIR = "/ff-scripts"
GO_FILE = "/tmp/ff-handover-go"

# Slots generated past the wall clock, for the blocks published at their own slot times until handover.
GENERATE_AHEAD_SLOTS = 32
# Handover slot distance from the wall clock once every node holds the dripped head: watermark, VC start, warm-up.
HANDOVER_LEAD_SLOTS = 4
# Validator clients start this long before the handover slot, after the previous slot's attestations are due.
VC_LEAD_SECONDS = 6


def wall_slot_command(network_params, final_genesis_timestamp):
    return "$(( ($(date +%s) - {0}) / {1} ))".format(
        final_genesis_timestamp, network_params.seconds_per_slot
    )


# Generate GENERATE_AHEAD_SLOTS past the wall slot; with a later fork meant to activate live, stop before it.
def generate_command(fast_forward, network_params, final_genesis_timestamp):
    wall = "wall={0}; last=$((wall + {1})); ".format(
        wall_slot_command(network_params, final_genesis_timestamp),
        GENERATE_AHEAD_SLOTS,
    )
    if fast_forward.cutoff_epoch == None:
        return wall + "ff-gen --until-slot=$last"
    slots_per_epoch = 8 if network_params.preset == "minimal" else 32
    cutoff_slot = fast_forward.cutoff_epoch * slots_per_epoch
    return (
        wall
        + 'if [ "$wall" -ge {0} ]; then echo "fast_forward: launch overran, wall slot $wall is already past the start of epoch {1}, where {2} should activate live" >&2; exit 1; fi; '.format(
            cutoff_slot, fast_forward.cutoff_epoch, fast_forward.cutoff_fork
        )
        + 'if [ "$last" -ge {0} ]; then last={1}; fi; '.format(
            cutoff_slot, cutoff_slot - 1
        )
        + "ff-gen --until-slot=$last"
    )


# Fails unless ff-gen's summary shows the target state requested by fast_forward.until.
def assert_target_command(fast_forward, summary_path):
    checks = {
        "activated": "s['head_slot'] >= {0}".format(fast_forward.target_slot),
        "justified": "int(s['finality_checkpoints']['current_justified']['epoch']) >= {0}".format(
            fast_forward.target_epoch
        ),
        "finalized": "int(s['finality_checkpoints']['finalized']['epoch']) >= {0}".format(
            fast_forward.target_epoch
        ),
    }
    script = "import json,sys; s=json.load(open('{0}')); ok={1}; print('ff-gen target {2} {3}:', 'met' if ok else 'NOT met', 'head', s['head_slot'], s['finality_checkpoints']); sys.exit(0 if ok else 1)".format(
        summary_path,
        checks[fast_forward.state],
        fast_forward.state,
        fast_forward.target_epoch,
    )
    return 'python3 -c "{0}"'.format(script)


def new_handover(participants):
    has_nimbus_vc = False
    for participant in participants:
        if (
            participant.use_separate_vc
            and participant.vc_type == constants.VC_TYPE.nimbus
        ):
            has_nimbus_vc = True
    return struct(
        handover_artifact=WATERMARK_ARTIFACT,
        nimbus_artifact=NIMBUS_HANDOVER_ARTIFACT if has_nimbus_vc else None,
    )


# Generates the chain to the wall slot on a private reth, publishes it to every beacon node, and stores the VC watermark.
def launch(
    plan,
    fast_forward,
    handover,
    network_params,
    el_cl_data,
    jwt_file,
    all_el_contexts,
    all_cl_contexts,
    participants,
    validator_count,
    final_genesis_timestamp,
):
    for participant in participants:
        if (
            participant.use_separate_vc != True
            and participant.cl_type != constants.CL_TYPE.grandine
        ):
            fail(
                "fast_forward needs a separate validator client for every participant except Grandine"
            )

    plan.print(
        "fast_forward: generating until {0} at epoch {1}; history runs to the start of epoch {2}{3}".format(
            fast_forward.state,
            fast_forward.target_epoch,
            fast_forward.end_epoch,
            ""
            if fast_forward.cutoff_fork == None
            else ", {0} activates live at epoch {1}".format(
                fast_forward.cutoff_fork, fast_forward.cutoff_epoch
            ),
        )
    )

    reth = plan.add_service(
        name=RETH_SERVICE_NAME,
        config=ServiceConfig(
            image=fast_forward.el_image,
            cmd=[
                "node",
                "--chain="
                + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
                + "/genesis.json",
                "--datadir=/data",
                "--authrpc.addr=0.0.0.0",
                "--authrpc.port={0}".format(ENGINE_PORT),
                "--authrpc.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
                "--disable-discovery",
                "--max-outbound-peers=0",
                "--max-inbound-peers=0",
            ],
            files={
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data.files_artifact_uuid,
                constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
            },
            ports={
                "engine-rpc": PortSpec(
                    number=ENGINE_PORT,
                    transport_protocol="TCP",
                    application_protocol="http",
                    wait="60s",
                ),
            },
        ),
    )

    scripts = plan.upload_files(
        src=static_files.FAST_FORWARD_SCRIPTS_DIRPATH, name="ff-scripts"
    )
    nodes = " ".join(
        [
            "{0}={1}@{2}".format(
                cl.beacon_service_name, cl.beacon_http_url, el.rpc_http_url
            )
            for cl, el in zip(all_cl_contexts, all_el_contexts)
        ]
    )
    # Prysm sends its post-envelope forkchoice update from a goroutine, so updates reorder unless each payload lands first.
    el_confirm = ",".join(
        [
            ctx.beacon_service_name
            for ctx in all_cl_contexts
            if ctx.client_name == constants.CL_TYPE.prysm
        ]
    )
    run = " && ".join(
        [
            "mkdir -p " + HANDOVER_DIR,
            "echo gen_start=$(date +%s.%N) > " + HANDOVER_DIR + "/timing.txt",
            "("
            + generate_command(fast_forward, network_params, final_genesis_timestamp)
            + " --testnet-dir="
            + constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
            + " --validator-count={0}".format(validator_count)
            + " --engine-url=http://{0}:{1}".format(reth.ip_address, ENGINE_PORT)
            + " --jwt-secret="
            + constants.JWT_MOUNT_PATH_ON_CONTAINER
            + " --output-dir="
            + CHAIN_DIR
            + " --no-json)",
            assert_target_command(fast_forward, CHAIN_DIR + "/summary.json"),
            "echo gen_end=$(date +%s.%N) >> " + HANDOVER_DIR + "/timing.txt",
            "cp {0}/interchange.json {0}/summary.json {1}/".format(
                CHAIN_DIR, HANDOVER_DIR
            ),
            "python3 {0}/insert.py --chain {1} --report {2}/insert.json --seconds-per-slot {3} --until-slot={4} --el-confirm={5} {6}".format(
                SCRIPTS_DIR,
                CHAIN_DIR,
                HANDOVER_DIR,
                network_params.seconds_per_slot,
                wall_slot_command(network_params, final_genesis_timestamp),
                el_confirm,
                nodes,
            ),
            "echo insert_end=$(date +%s.%N) >> " + HANDOVER_DIR + "/timing.txt",
        ]
    )
    plan.run_sh(
        name="ff-generate-and-insert",
        description="Generating the fast-forward chain and publishing it into every beacon node",
        image=fast_forward.image,
        env_vars={
            "FF_GEN_MNEMONIC": network_params.preregistered_validator_keys_mnemonic
        },
        files={
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data.files_artifact_uuid,
            constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
            SCRIPTS_DIR: scripts,
        },
        run=run,
        store=[
            StoreSpec(src=HANDOVER_DIR, name=HANDOVER_ARTIFACT),
            StoreSpec(src=CHAIN_DIR, name=CHAIN_ARTIFACT),
        ],
        wait="10m",
    )

    drip(plan, fast_forward, network_params, scripts, nodes, el_confirm)

    # Teku starts gossip only on a sync-state change or a new peer while near the head; API import triggers neither.
    for ctx in all_cl_contexts:
        if ctx.client_name == constants.CL_TYPE.teku:
            plan.stop_service(name=ctx.beacon_service_name)
            plan.start_service(name=ctx.beacon_service_name)

    choose_handover_slot(plan)

    if handover.nimbus_artifact != None:
        nimbus_image = DEFAULT_NIMBUS_IMAGE
        for participant in participants:
            if participant.cl_type == constants.CL_TYPE.nimbus:
                nimbus_image = participant.cl_image
        plan.run_sh(
            name="ff-nimbus-slashingdb",
            description="Building the Nimbus slashing-protection database from the fast-forward watermark",
            image=nimbus_image,
            files={"/ff": WATERMARK_ARTIFACT},
            run="mkdir -p /tmp/ff-nimbus && nimbus_beacon_node slashingdb import --validators-dir=/tmp/ff-nimbus /ff/interchange.json",
            store=[StoreSpec(src="/tmp/ff-nimbus", name=NIMBUS_HANDOVER_ARTIFACT)],
            wait="2m",
        )


# Publishes the generated blocks after the inserted history at their slot times, in the background until handover.
def drip(plan, fast_forward, network_params, scripts, nodes, el_confirm):
    plan.add_service(
        name=DRIP_SERVICE_NAME,
        config=ServiceConfig(
            image=fast_forward.image,
            files={
                CHAIN_DIR: CHAIN_ARTIFACT,
                HANDOVER_DIR: HANDOVER_ARTIFACT,
                SCRIPTS_DIR: scripts,
            },
            entrypoint=["sh", "-c"],
            cmd=[
                "exec python3 -u {0}/drip.py --chain {1} --history-head $(python3 -c \"import json; print(json.load(open('{2}/insert.json'))['head_slot'])\") --out {3} --seconds-per-slot {4} --go-file {5} --lead-slots {6} --vc-lead-seconds {7} --el-confirm={8} {9}".format(
                    SCRIPTS_DIR,
                    CHAIN_DIR,
                    HANDOVER_DIR,
                    WATERMARK_DIR,
                    network_params.seconds_per_slot,
                    GO_FILE,
                    HANDOVER_LEAD_SLOTS,
                    VC_LEAD_SECONDS,
                    el_confirm,
                    nodes,
                )
            ],
        ),
    )


# Once every slow step is done, the drip picks the handover slot and writes the watermark for it.
def choose_handover_slot(plan):
    plan.exec(
        service_name=DRIP_SERVICE_NAME,
        recipe=ExecRecipe(command=["touch", GO_FILE]),
    )
    result = plan.wait(
        service_name=DRIP_SERVICE_NAME,
        recipe=ExecRecipe(command=["cat", WATERMARK_DIR + "/status"]),
        field="code",
        assertion="==",
        target_value=0,
        timeout="6m",
    )
    plan.verify(
        value=result["output"],
        assertion="==",
        target_value="ok",
        description="fast_forward handover: see the ff-drip service log",
    )
    plan.store_service_files(
        service_name=DRIP_SERVICE_NAME,
        src=WATERMARK_DIR,
        name=WATERMARK_ARTIFACT,
    )


# Loads the keys of in-process validators (Grandine) through their keymanager at the validator start time.
def load_in_process_keys(plan, fast_forward, all_cl_contexts, participants, validator_data):
    specs = []
    files = {}
    for index, participant in enumerate(participants):
        if participant.use_separate_vc or participant.validator_count == 0:
            continue
        ctx = all_cl_contexts[index]
        keystores = validator_data.per_node_keystores[index]
        mount = "/keys-{0}".format(index)
        files[mount] = keystores.files_artifact_uuid
        specs.append(
            "{0}=http://{1}:{2}@{3}/{4}:{3}/{5}".format(
                ctx.beacon_service_name,
                ctx.beacon_service_name,
                vc_shared.VALIDATOR_HTTP_PORT_NUM,
                mount,
                keystores.teku_keys_relative_dirpath,
                keystores.teku_secrets_relative_dirpath,
            )
        )
    if len(specs) == 0:
        return
    files[WATERMARK_DIR] = WATERMARK_ARTIFACT
    files[SCRIPTS_DIR] = "ff-scripts"
    files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = plan.upload_files(
        src=static_files.KEYMANAGER_PATH_FILEPATH, name="ff-keymanager-token"
    )
    plan.run_sh(
        name="ff-keymanager-import",
        description="Loading in-process validator keys and their watermark through the keymanager",
        image=fast_forward.image,
        files=files,
        run="python3 -u {0}/keymanager_import.py --handover {1} --token-file {2} {3}".format(
            SCRIPTS_DIR,
            WATERMARK_DIR,
            constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
            " ".join(specs),
        ),
        wait="5m",
    )


# Fails unless every beacon node shows the target state requested by fast_forward.until.
def wait_for_target(plan, fast_forward, all_cl_contexts, port_id):
    endpoint, extract, target = {
        "activated": (
            "/eth/v1/beacon/headers/head",
            ".data.header.message.slot | tonumber",
            fast_forward.target_slot,
        ),
        "justified": (
            "/eth/v1/beacon/states/head/finality_checkpoints",
            ".data.current_justified.epoch | tonumber",
            fast_forward.target_epoch,
        ),
        "finalized": (
            "/eth/v1/beacon/states/head/finality_checkpoints",
            ".data.finalized.epoch | tonumber",
            fast_forward.target_epoch,
        ),
    }[fast_forward.state]
    plan.print(
        "Waiting for every beacon node to reach {0} {1}".format(
            fast_forward.state, target
        )
    )
    for cl_context in all_cl_contexts:
        plan.wait(
            recipe=GetHttpRequestRecipe(
                endpoint=endpoint,
                port_id=port_id,
                extract={"value": extract},
            ),
            field="extract.value",
            assertion=">=",
            target_value=target,
            timeout="40m",
            service_name=cl_context.beacon_service_name,
        )
    plan.print("Every beacon node reached {0} {1}".format(fast_forward.state, target))
