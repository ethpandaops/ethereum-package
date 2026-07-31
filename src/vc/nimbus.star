constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./vc_shared.star")


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
    distributed=False,
):
    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.nimbus_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.raw_secrets_relative_dirpath,
        )

    cmd = []

    for beacon_url in beacon_http_urls:
        cmd.append("--beacon-node=" + beacon_url)

    cmd.extend(
        [
            "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
            # vvvvvvvvvvvvvvvvvvv METRICS CONFIG vvvvvvvvvvvvvvvvvvvvv
            "--metrics",
            "--metrics-address=0.0.0.0",
            "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        ]
    )

    if remote_signer_context == None:
        cmd.extend(
            [
                "--validators-dir=" + validator_keys_dirpath,
                "--secrets-dir=" + validator_secrets_dirpath,
            ]
        )
    else:
        cmd.extend(
            [
                "--web3-signer-url={0}".format(remote_signer_context.http_url),
            ]
        )

    keymanager_api_cmd = [
        "--keymanager",
        "--keymanager-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--keymanager-address=0.0.0.0",
        "--keymanager-allow-origin=*",
        "--keymanager-token-file=" + constants.KEYMANAGER_MOUNT_PATH_ON_CONTAINER,
    ]

    if network_params.gas_limit > 0:
        cmd.append("--suggested-gas-limit={0}".format(network_params.gas_limit))

    if distributed:
        cmd.append("--distributed")
        cmd.append("--payload-builder=true")
        # Disable doppelganger detection for distributed (Charon) validators. A
        # Charon cluster legitimately shares the same validator pubkeys across
        # all nodes (threshold signing), so each Nimbus VC sees "its" validators
        # already attesting on the network and would self-terminate at the epoch
        # boundary (FATAL, exit 127), taking down the whole DV. Standalone
        # (non-distributed) Nimbus VCs keep doppelganger detection enabled.
        cmd.append("--doppelganger-detection=false")

    if len(participant.vc_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.vc_extra_params])

    files = {
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
    }

    public_ports, public_keymanager_port_assignment = vc_shared.get_public_ports(
        port_publisher, vc_index
    )

    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    if keymanager_enabled:
        files[constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS] = keymanager_file
        cmd.extend(keymanager_api_cmd)
        ports.update(vc_shared.VALIDATOR_KEYMANAGER_USED_PORTS)
        public_ports.update(
            shared_utils.get_port_specs(public_keymanager_port_assignment)
        )

    vc_shared.apply_extra_mounts(plan, participant, extra_files_artifacts, files)

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.vc_enabled,
        "cmd": cmd,
        "files": files,
        "env_vars": shared_utils.with_otel_env_vars(
            participant.vc_extra_env_vars,
            otel_otlp_grpc_url,
            full_name,
        ),
        "labels": vc_shared.get_labels(
            constants.VC_TYPE.nimbus, participant, image, cl_context, vc_index
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
        "user": User(uid=0, gid=0),
    }

    vc_shared.apply_binary_override(
        config_args,
        cmd,
        vc_binary_artifact,
        "/usr/bin/nimbus_validator_client",
        "/usr/bin/nimbus_validator_client",
    )

    vc_shared.apply_resource_limits(config_args, participant)
    return ServiceConfig(**config_args)
