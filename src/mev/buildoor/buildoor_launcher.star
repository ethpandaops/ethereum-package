constants = import_module("../../package_io/constants.star")
shared_utils = import_module("../../shared_utils/shared_utils.star")

BUILDOOR_SERVICE_NAME = constants.BUILDOOR_SERVICE_NAME
BUILDOOR_API_PORT = constants.BUILDOOR_API_PORT
BUILDOOR_BUILDER_API_PORT = 9000

VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE = "/validator-ranges"
VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"
VALIDATOR_RANGES_FILE_NAME = "validator-ranges.yaml"

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
    builder_mnemonic=None,
    builder_key_index=None,
    validator_ranges_artifact=None,
    service_name=BUILDOOR_SERVICE_NAME,
    extra_data=None,
    image=None,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Per-instance image override (A/B testing): an instance may pin its own
    # buildoor image. When unset it falls back to buildoor_params.image (which
    # itself defaults to DEFAULT_BUILDOOR_IMAGE).
    image = image if image != None else buildoor_params.image

    # Strip 0x prefix if present since keys are expected as hex-only
    wallet_key = prefunded_key
    if wallet_key.startswith("0x"):
        wallet_key = wallet_key[2:]

    # The builder API URL buildoor advertises in its bids. With multiple
    # instances each one must advertise its OWN service URL; otherwise every
    # instance but one is rejected by consumers as a builder_url mismatch and
    # never wins a bid. Computed once and reused as the registered api_url.
    api_url = "http://{0}:{1}".format(service_name, BUILDOOR_API_PORT)

    cmd = [
        "run",
        "--cl-client={0}".format(beacon_uri),
        "--el-rpc={0}".format(el_rpc_uri),
        "--el-engine-api={0}".format(engine_rpc_uri),
        "--el-jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--wallet-privkey={0}".format(wallet_key),
        "--api-port={0}".format(BUILDOOR_API_PORT),
        "--builder-api-url={0}".format(api_url),
    ]

    # Builder BLS key: let buildoor derive it from the mnemonic at the given
    # index (matching the 0xB0 builder keys registered at genesis) when provided,
    # otherwise fall back to the default static secret key.
    if builder_mnemonic != None:
        cmd.append("--builder-mnemonic={0}".format(builder_mnemonic))
        cmd.append("--builder-key-index={0}".format(builder_key_index))
    else:
        cmd.append("--builder-privkey={0}".format(constants.DEFAULT_MEV_SECRET_KEY[2:]))

    # Tag built blocks so a given block can be traced back to the buildoor
    # instance that built it. Defaults to the service name (a unique identifier);
    # buildoor injects it as the extra-data prefix (truncated to 32 bytes).
    cmd.append(
        "--extra-data={0}".format(extra_data if extra_data != None else service_name)
    )

    if buildoor_params.builder_api:
        cmd.append("--builder-api-enabled")

    if buildoor_params.epbs_builder:
        cmd.append("--epbs-enabled")

    # Lifecycle lets buildoor deposit/onboard its own builder after genesis (and
    # top it up), so builders work without genesis registration / gloas-at-genesis.
    if buildoor_params.lifecycle:
        cmd.append("--lifecycle")

    if validator_ranges_artifact != None:
        cmd.append(
            "--validator-ranges-file={0}/{1}".format(
                VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE, VALIDATOR_RANGES_FILE_NAME
            )
        )

    cmd += buildoor_params.extra_args

    files = {
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    if validator_ranges_artifact != None:
        files[VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE] = validator_ranges_artifact

    buildoor_service = plan.add_service(
        name=service_name,
        config=ServiceConfig(
            image=image,
            ports={
                "api": PortSpec(
                    number=BUILDOOR_API_PORT,
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            cmd=cmd,
            files=files,
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=global_node_selectors,
            tolerations=tolerations,
        ),
    )
    return {
        "mev_endpoint": "http://{0}@{1}:{2}".format(
            constants.DEFAULT_MEV_PUBKEY,
            service_name,
            BUILDOOR_API_PORT,
        ),
        "api_url": api_url,
    }
