constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./vc_shared.star")

SILVER_VC_BINARY_PATH = "/usr/local/bin/silver-vc"

# Holds each key's leaf record, expanded XMSS key and VRF tree.
DATA_DIRPATH_ON_CONTAINER = "/data/silver-vc"

LOG_LEVEL_ENV_VAR = "RUST_LOG"


def get_config(
    plan,
    participant,
    el_cl_genesis_data,
    keymanager_file,
    image,
    service_name,
    global_log_level,
    beacon_http_urls,
    cl_context,
    remote_signer_context,
    full_name,
    node_keystore_files,
    tolerations,
    node_selectors,
    keymanager_enabled,
    network_params,
    port_publisher,
    vc_index,
    extra_files_artifacts,
    prysm_password_relative_filepath=None,
    prysm_password_artifact_uuid=None,
    tempo_otlp_grpc_url=None,
    otel_otlp_grpc_url=None,
    vc_binary_artifact=None,
):
    if network_params.preset != "mainnet":
        fail("silver's validator client supports only the mainnet preset")
    if network_params.pq_fork_epoch != 0:
        fail(
            "silver's validator client signs PQ duties only, so it needs pq_fork_epoch: 0"
        )
    if remote_signer_context != None:
        fail(
            "silver's validator client signs with local keys only, not a remote signer"
        )
    if keymanager_enabled:
        fail("silver's validator client has no keymanager API")
    if len(beacon_http_urls) != 1:
        fail("silver's validator client follows exactly one beacon node")
    if (
        network_params.aggregation_cutoff_bps != 4000
        or network_params.aggregate_due_bps_pq != 6000
        or network_params.aggregator_delay_bps != 500
    ):
        fail(
            "silver's validator client times aggregates by the spec's defaults: aggregation_cutoff_bps 4000, aggregate_due_bps_pq 6000, aggregator_delay_bps 500"
        )

    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, vc_shared.VERBOSITY_LEVELS
    )

    validator_keys_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.raw_keys_relative_dirpath,
    )
    validator_secrets_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.raw_secrets_relative_dirpath,
    )

    cmd = [
        SILVER_VC_BINARY_PATH,
        # The genesis data directory holds the devnet's config.yaml and
        # genesis.ssz, whose registry authenticates the XMSS and VRF artifacts.
        "--network=" + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER,
        "--beacon-node=" + beacon_http_urls[0],
        "--keystores-dir=" + validator_keys_dirpath,
        "--secrets-dir=" + validator_secrets_dirpath,
        "--data-dir=" + DATA_DIRPATH_ON_CONTAINER,
        # A fresh enclave's keys have never signed, so their leaf records can
        # be created.
        "--init-leaf-records",
        # burn address - proposals are made only with a fee recipient
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
    ]

    if network_params.gas_limit > 0:
        cmd.append("--gas-limit={0}".format(network_params.gas_limit))
    if network_params.xmss_cache_url != "":
        cmd.append("--xmss-cache-url=" + network_params.xmss_cache_url)
    if network_params.vrf_state_url != "":
        cmd.append("--vrf-state-url=" + network_params.vrf_state_url)

    if len(participant.vc_extra_params) > 0:
        cmd.extend([param for param in participant.vc_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
    }

    vc_shared.apply_extra_mounts(plan, participant, extra_files_artifacts, files)

    setup_cmds = []
    if vc_binary_artifact != None:
        files["/opt/bin"] = vc_binary_artifact.artifact
        setup_cmds.append(
            "cp /opt/bin/{0} {1}".format(
                vc_binary_artifact.filename, SILVER_VC_BINARY_PATH
            )
        )

    # silver's validator client serves no metrics yet. The port is declared
    # without a readiness wait because the package expects one on every VC.
    ports = {
        constants.METRICS_PORT_ID: shared_utils.new_port_spec(
            vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
            wait=None,
        ),
    }
    public_ports, _ = vc_shared.get_public_ports(
        port_publisher, vc_index, with_keymanager=False
    )

    env_vars = {LOG_LEVEL_ENV_VAR: log_level}
    env_vars.update(
        shared_utils.with_otel_env_vars(
            participant.vc_extra_env_vars,
            otel_otlp_grpc_url,
            full_name,
        )
    )

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "entrypoint": ["sh", "-c"],
        "cmd": [" && ".join(setup_cmds + ["exec " + " ".join(cmd)])],
        "files": files,
        "env_vars": env_vars,
        "labels": vc_shared.get_labels(
            constants.VC_TYPE.silver, participant, image, cl_context, vc_index
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    vc_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)
