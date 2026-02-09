constants = import_module("../../package_io/constants.star")
shared_utils = import_module("../../shared_utils/shared_utils.star")

BUILDOOR_SERVICE_NAME = "buildoor"
BUILDOOR_API_PORT = 8080
BUILDOOR_BUILDER_API_PORT = 9000

MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 1024


def launch_buildoor(
    plan,
    beacon_uri,
    el_rpc_uri,
    engine_rpc_uri,
    jwt_file,
    prefunded_key,
    buildoor_params,
    global_node_selectors,
    global_tolerations,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Strip 0x prefix if present since keys are expected as hex-only
    wallet_key = prefunded_key
    if wallet_key.startswith("0x"):
        wallet_key = wallet_key[2:]

    # Use the existing BLS keypair from constants for builder identity
    builder_bls_key = constants.DEFAULT_MEV_SECRET_KEY[2:]

    cmd = [
        "run",
        "--cl-client={0}".format(beacon_uri),
        "--el-rpc={0}".format(el_rpc_uri),
        "--el-engine-api={0}".format(engine_rpc_uri),
        "--el-jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--builder-privkey={0}".format(builder_bls_key),
        "--wallet-privkey={0}".format(wallet_key),
        "--api-port={0}".format(BUILDOOR_API_PORT),
        "--builder-api-port={0}".format(BUILDOOR_BUILDER_API_PORT),
    ]

    if buildoor_params.legacy_builder:
        cmd.append("--builder-api-enabled")

    if buildoor_params.epbs_builder:
        cmd.append("--epbs-enabled")

    cmd += buildoor_params.extra_args

    buildoor_service = plan.add_service(
        name=BUILDOOR_SERVICE_NAME,
        config=ServiceConfig(
            image=buildoor_params.image,
            ports={
                "api": PortSpec(
                    number=BUILDOOR_API_PORT, transport_protocol="TCP", application_protocol="http"
                ),
                "builder-api": PortSpec(
                    number=BUILDOOR_BUILDER_API_PORT, transport_protocol="TCP"
                ),
            },
            cmd=cmd,
            files={
                constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
            },
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=global_node_selectors,
            tolerations=tolerations,
        ),
    )
    return "http://{0}@{1}:{2}".format(
        constants.DEFAULT_MEV_PUBKEY, BUILDOOR_SERVICE_NAME, BUILDOOR_BUILDER_API_PORT
    )
