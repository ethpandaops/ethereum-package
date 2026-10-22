constants = import_module("../package_io/constants.star")
static_files = import_module("../static_files/static_files.star")

RETH_SERVICE_NAME = "ff-reth"
ENGINE_PORT = 8551
HANDOVER_ARTIFACT = "ff-handover"
NIMBUS_HANDOVER_ARTIFACT = "ff-handover-nimbus"
DEFAULT_NIMBUS_IMAGE = "ethpandaops/nimbus-eth2:unstable"

CHECKPOINT_SERVICE_NAME = "ff-checkpoint"
CHECKPOINT_PORT = 5052
TAIL_ARTIFACT = "ff-chain-tail"
INSERT_REPORT_ARTIFACT = "ff-insert-report"

CHAIN_DIR = "/ff/chain"
HANDOVER_DIR = "/ff/handover"
TAIL_DIR = "/ff/tail"
REPORT_DIR = "/ff/report"
SCRIPTS_DIR = "/ff-scripts"


# Generate up to the wall slot; with a later fork meant to activate live, refuse to cross into it.
def generate_command(fast_forward, network_params, final_genesis_timestamp):
    if fast_forward.cutoff_epoch == None:
        return "ff-gen"
    slots_per_epoch = 8 if network_params.preset == "minimal" else 32
    cutoff_slot = fast_forward.cutoff_epoch * slots_per_epoch
    return (
        "wall=$(( ($(date +%s) - {0}) / {1} )); ".format(
            final_genesis_timestamp, network_params.seconds_per_slot
        )
        + 'if [ "$wall" -ge {0} ]; then echo "fast_forward: launch overran, wall slot $wall is already past the start of epoch {1}, where {2} should activate live" >&2; exit 1; fi; '.format(
            cutoff_slot, fast_forward.cutoff_epoch, fast_forward.cutoff_fork
        )
        + "ff-gen --max-slot={0}".format(cutoff_slot - 1)
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
        handover_artifact=HANDOVER_ARTIFACT,
        nimbus_artifact=NIMBUS_HANDOVER_ARTIFACT if has_nimbus_vc else None,
    )


def check_participants(participants):
    for participant in participants:
        if participant.use_separate_vc != True:
            fail("fast_forward needs a separate validator client for every participant")


def describe(plan, fast_forward):
    plan.print(
        "fast_forward: generating until {0} at epoch {1}; history runs to the start of epoch {2}{3}; beacon nodes get it {4}".format(
            fast_forward.state,
            fast_forward.target_epoch,
            fast_forward.end_epoch,
            ""
            if fast_forward.cutoff_fork == None
            else ", {0} activates live at epoch {1}".format(
                fast_forward.cutoff_fork, fast_forward.cutoff_epoch
            ),
            "from its last finalized checkpoint (history: checkpoint)"
            if fast_forward.history == "checkpoint"
            else "block by block from genesis (history: full)",
        )
    )


def add_reth(plan, fast_forward, el_cl_data, jwt_file):
    return plan.add_service(
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
                # MDBX's default 4 GB growth step is fully allocated in the container layer.
                "--db.growth-step=64MB",
                "--db.max-size=64GB",
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


def upload_scripts(plan):
    return plan.upload_files(
        src=static_files.FAST_FORWARD_SCRIPTS_DIRPATH, name="ff-scripts"
    )


def ff_gen_command(
    fast_forward,
    network_params,
    final_genesis_timestamp,
    reth,
    validator_count,
):
    return (
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
        + " --no-json)"
    )


# Generation takes about 10 ms per slot natively; leave room for a slower, shared Docker VM.
def generation_wait(fast_forward):
    return "{0}s".format(600 + fast_forward.target_slot // 10)


def insert_command(network_params, all_el_contexts, all_cl_contexts, report_dir, timeout):
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
    return "python3 {0}/insert.py --chain {1} --report {2}/insert.json --seconds-per-slot {3} --timeout {4} --el-confirm={5} {6}".format(
        SCRIPTS_DIR,
        CHAIN_DIR,
        report_dir,
        network_params.seconds_per_slot,
        timeout,
        el_confirm,
        nodes,
    )


# history: checkpoint, before any beacon node starts. Generates the chain, feeds every EL its payloads
# up to the last finalized checkpoint while ff-gen runs, keeps the anchor plus the blocks after it,
# and serves the anchor as a beacon API for the beacon nodes' checkpoint sync.
def generate_checkpoint(
    plan,
    fast_forward,
    network_params,
    el_cl_data,
    jwt_file,
    all_el_contexts,
    participants,
    validator_count,
    final_genesis_timestamp,
):
    check_participants(participants)
    describe(plan, fast_forward)
    reth = add_reth(plan, fast_forward, el_cl_data, jwt_file)
    scripts = upload_scripts(plan)
    slots_per_epoch = 8 if network_params.preset == "minimal" else 32
    engines = " ".join(
        [
            "{0}=http://{1}:{2}".format(
                el.service_name, el.ip_addr, el.engine_rpc_port_num
            )
            for el in all_el_contexts
        ]
    )
    run = "\n".join(
        [
            "set -e",
            "mkdir -p {0} {1}".format(HANDOVER_DIR, TAIL_DIR),
            "echo gen_start=$(date +%s.%N) > " + HANDOVER_DIR + "/timing.txt",
            "python3 {0}/checkpoint.py feed --chain {1} --jwt {2} --slots-per-epoch {3} --report {4}/feed.json {5} > {4}/feed.log 2>&1 &".format(
                SCRIPTS_DIR,
                CHAIN_DIR,
                constants.JWT_MOUNT_PATH_ON_CONTAINER,
                slots_per_epoch,
                HANDOVER_DIR,
                engines,
            ),
            "feeder=$!",
            "mkdir -p " + CHAIN_DIR,
            ff_gen_command(
                fast_forward,
                network_params,
                final_genesis_timestamp,
                reth,
                validator_count,
            )
            + " || { kill $feeder; exit 1; }",
            assert_target_command(fast_forward, CHAIN_DIR + "/summary.json")
            + " || { kill $feeder; exit 1; }",
            "echo gen_end=$(date +%s.%N) >> " + HANDOVER_DIR + "/timing.txt",
            "wait $feeder || { cat " + HANDOVER_DIR + "/feed.log; exit 1; }",
            "cat {0}/feed.log".format(HANDOVER_DIR),
            "echo feed_end=$(date +%s.%N) >> " + HANDOVER_DIR + "/timing.txt",
            "python3 {0}/checkpoint.py tail --chain {1} --out {2}".format(
                SCRIPTS_DIR, CHAIN_DIR, TAIL_DIR
            ),
            "cp {0}/interchange.json {0}/summary.json {1}/".format(
                CHAIN_DIR, HANDOVER_DIR
            ),
            # The run's container stays until the enclave goes; drop the full history it no longer needs.
            "rm -rf " + CHAIN_DIR,
        ]
    )
    plan.run_sh(
        name="ff-generate-and-feed",
        description="Generating the fast-forward chain and feeding every EL up to its last finalized checkpoint",
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
            StoreSpec(src=TAIL_DIR, name=TAIL_ARTIFACT),
        ],
        wait=generation_wait(fast_forward),
    )
    plan.remove_service(name=RETH_SERVICE_NAME)

    plan.add_service(
        name=CHECKPOINT_SERVICE_NAME,
        config=ServiceConfig(
            image=fast_forward.image,
            cmd=[
                "python3",
                SCRIPTS_DIR + "/checkpoint.py",
                "serve",
                "--dir",
                TAIL_DIR,
                "--network-config",
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
                "--port",
                str(CHECKPOINT_PORT),
            ],
            files={
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_data.files_artifact_uuid,
                TAIL_DIR: TAIL_ARTIFACT,
                SCRIPTS_DIR: scripts,
            },
            ports={
                "http": PortSpec(
                    number=CHECKPOINT_PORT,
                    transport_protocol="TCP",
                    application_protocol="http",
                    wait="30s",
                ),
            },
        ),
    )


# Publishes the generated chain into every beacon node (history: full generates it here first;
# history: checkpoint only publishes the blocks after the anchor), then readies the VC handover.
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
    if fast_forward.history == "checkpoint":
        plan.run_sh(
            name="ff-insert-tail",
            description="Publishing the blocks after the checkpoint anchor into every beacon node",
            image=fast_forward.image,
            files={
                CHAIN_DIR: TAIL_ARTIFACT,
                SCRIPTS_DIR: "ff-scripts",
            },
            run=" && ".join(
                [
                    "mkdir -p " + REPORT_DIR,
                    "echo insert_start=$(date +%s.%N) > " + REPORT_DIR + "/timing.txt",
                    insert_command(
                        network_params,
                        all_el_contexts,
                        all_cl_contexts,
                        REPORT_DIR,
                        600,
                    ),
                    "echo insert_end=$(date +%s.%N) >> " + REPORT_DIR + "/timing.txt",
                ]
            ),
            store=[StoreSpec(src=REPORT_DIR, name=INSERT_REPORT_ARTIFACT)],
            wait="15m",
        )
    else:
        check_participants(participants)
        describe(plan, fast_forward)
        reth = add_reth(plan, fast_forward, el_cl_data, jwt_file)
        scripts = upload_scripts(plan)
        # Every node imports every block; give slow importers room so the report shows the real cost.
        insert_timeout = max(300, fast_forward.target_slot)
        run = " && ".join(
            [
                "mkdir -p " + HANDOVER_DIR,
                "echo gen_start=$(date +%s.%N) > " + HANDOVER_DIR + "/timing.txt",
                ff_gen_command(
                    fast_forward,
                    network_params,
                    final_genesis_timestamp,
                    reth,
                    validator_count,
                ),
                assert_target_command(fast_forward, CHAIN_DIR + "/summary.json"),
                "echo gen_end=$(date +%s.%N) >> " + HANDOVER_DIR + "/timing.txt",
                "cp {0}/interchange.json {0}/summary.json {1}/".format(
                    CHAIN_DIR, HANDOVER_DIR
                ),
                insert_command(
                    network_params,
                    all_el_contexts,
                    all_cl_contexts,
                    HANDOVER_DIR,
                    insert_timeout,
                ),
                "echo insert_end=$(date +%s.%N) >> " + HANDOVER_DIR + "/timing.txt",
                "rm -rf " + CHAIN_DIR,
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
            store=[StoreSpec(src=HANDOVER_DIR, name=HANDOVER_ARTIFACT)],
            wait="{0}s".format(
                int(generation_wait(fast_forward)[:-1]) + insert_timeout + 60
            ),
        )
        plan.remove_service(name=RETH_SERVICE_NAME)

    # Teku starts gossip only on a sync-state change or a new peer while near the head; API import triggers neither.
    for ctx in all_cl_contexts:
        if ctx.client_name == constants.CL_TYPE.teku:
            plan.stop_service(name=ctx.beacon_service_name)
            plan.start_service(name=ctx.beacon_service_name)

    if handover.nimbus_artifact != None:
        nimbus_image = DEFAULT_NIMBUS_IMAGE
        for participant in participants:
            if participant.cl_type == constants.CL_TYPE.nimbus:
                nimbus_image = participant.cl_image
        plan.run_sh(
            name="ff-nimbus-slashingdb",
            description="Building the Nimbus slashing-protection database from the fast-forward watermark",
            image=nimbus_image,
            files={"/ff": HANDOVER_ARTIFACT},
            run="mkdir -p /tmp/ff-nimbus && nimbus_beacon_node slashingdb import --validators-dir=/tmp/ff-nimbus /ff/interchange.json",
            store=[StoreSpec(src="/tmp/ff-nimbus", name=NIMBUS_HANDOVER_ARTIFACT)],
            wait="2m",
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
