constants = import_module("../package_io/constants.star")
static_files = import_module("../static_files/static_files.star")

RETH_SERVICE_NAME = "ff-reth"
ENGINE_PORT = 8551
HANDOVER_ARTIFACT = "ff-handover"
NIMBUS_HANDOVER_ARTIFACT = "ff-handover-nimbus"
DEFAULT_NIMBUS_IMAGE = "ethpandaops/nimbus-eth2:unstable"

CHAIN_DIR = "/ff/chain"
HANDOVER_DIR = "/ff/handover"
SCRIPTS_DIR = "/ff-scripts"


# With a later fork scheduled, stop at the wall-clock slot or the slot before that fork, whichever is first.
def until_slot_arg(fast_forward, network_params, final_genesis_timestamp):
    if fast_forward.cutoff_epoch == None:
        return ""
    slots_per_epoch = 8 if network_params.preset == "minimal" else 32
    last_slot = fast_forward.cutoff_epoch * slots_per_epoch - 1
    wall_slot = "(($(date +%s) - {0}) / {1})".format(
        final_genesis_timestamp, network_params.seconds_per_slot
    )
    return " --until-slot=$(( {0} < {1} ? {0} : {1} ))".format(wall_slot, last_slot)


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


# Generates a finalized chain up to the wall-clock slot against a private reth, publishes it into every
# beacon node, and stores the per-key slashing-protection watermark the validator clients import at start.
def launch(
    plan,
    fast_forward,
    handover,
    network_params,
    el_cl_data,
    jwt_file,
    all_cl_contexts,
    participants,
    validator_count,
    final_genesis_timestamp,
):
    for participant in participants:
        if participant.use_separate_vc != True:
            fail("fast_forward needs a separate validator client for every participant")

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
        src=static_files.FAST_FORWARD_INSERT_SCRIPT_FILEPATH, name="ff-scripts"
    )
    nodes = " ".join(
        [
            "{0}={1}".format(ctx.beacon_service_name, ctx.beacon_http_url)
            for ctx in all_cl_contexts
        ]
    )
    run = " && ".join(
        [
            "mkdir -p " + HANDOVER_DIR,
            "echo gen_start=$(date +%s.%N) > " + HANDOVER_DIR + "/timing.txt",
            "ff-gen"
            + until_slot_arg(fast_forward, network_params, final_genesis_timestamp)
            + " --testnet-dir="
            + constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
            + " --validator-count={0}".format(validator_count)
            + " --engine-url=http://{0}:{1}".format(reth.ip_address, ENGINE_PORT)
            + " --jwt-secret="
            + constants.JWT_MOUNT_PATH_ON_CONTAINER
            + " --output-dir="
            + CHAIN_DIR
            + " --no-json",
            "echo gen_end=$(date +%s.%N) >> " + HANDOVER_DIR + "/timing.txt",
            "cp {0}/interchange.json {0}/summary.json {1}/".format(
                CHAIN_DIR, HANDOVER_DIR
            ),
            "python3 {0}/insert.py --chain {1} --report {2}/insert.json {3}".format(
                SCRIPTS_DIR, CHAIN_DIR, HANDOVER_DIR, nodes
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
        store=[StoreSpec(src=HANDOVER_DIR, name=HANDOVER_ARTIFACT)],
        wait="10m",
    )

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
            run="mkdir -p /tmp/ff-nimbus && nimbus_beacon_node slashingdb import --validators-dir=/tmp/ff-nimbus /ff/handover/interchange.json",
            store=[StoreSpec(src="/tmp/ff-nimbus", name=NIMBUS_HANDOVER_ARTIFACT)],
            wait="2m",
        )
