shared_utils = import_module("../shared_utils/shared_utils.star")
input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
vc_shared = import_module("./shared.star")
vc_context = import_module("./vc_context.star")
node_metrics = import_module("../node_metrics_info.star")
prometheus = import_module("../prometheus/prometheus_launcher.star")
lighthouse = import_module("./lighthouse.star")
lodestar = import_module("./lodestar.star")
teku = import_module("./teku.star")
nimbus = import_module("./nimbus.star")
prysm = import_module("./prysm.star")
vouch = import_module("./vouch.star")
keystore_files_module = import_module(
    "../prelaunch_data_generator/validator_keystores/keystore_files.star"
)

# Charon specific ports
CHARON_VALIDATOR_API_PORT = 3600
CHARON_P2P_TCP_PORT = 3610
CHARON_MONITORING_PORT = 3620
CHARON_RELAY_HTTP_PORT = 3640

# Fallback node count if the participant doesn't request a valid one.
DEFAULT_CHARON_NODE_COUNT = 4

# Official ethdo image, used to build the Vouch wallet from the split keystores
# (so the Vouch container itself needs no ethdo download).
ETHDO_IMAGE = "wealdtech/ethdo:latest"

# Verbosity levels mapping
VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
}


def launch(
    plan,
    launcher,
    keymanager_file,
    service_name,
    image,
    global_log_level,
    cl_context,
    full_name,
    node_keystore_files,
    participant,
    global_tolerations,
    node_selectors,
    network_params,
    port_publisher,
    vc_index,
    genesis_timestamp,
):
    """
    Launch a Charon distributed validator client
    """
    if node_keystore_files == None:
        return None, []

    tolerations = shared_utils.get_tolerations(
        specific_container_tolerations=participant.vc_tolerations,
        participant_tolerations=participant.tolerations,
        global_tolerations=global_tolerations,
    )

    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, VERBOSITY_LEVELS
    )

    # Number of Charon nodes to create.
    charon_node_count = participant.charon_node_count
    if charon_node_count <= 0:
        charon_node_count = DEFAULT_CHARON_NODE_COUNT

    # Validator client type/image to run behind each Charon node.
    vc_type = constants.CL_TYPE.lighthouse
    vc_image = input_parser.DEFAULT_CL_IMAGES[constants.CL_TYPE.lighthouse]
    if participant.charon_params != None:
        vc_type = participant.charon_params.get("charon_vc", vc_type)
        vc_image = participant.charon_params.get("charon_vc_image", vc_image)

    # All Charon nodes connect to the same beacon node.
    beacon_endpoint = cl_context.beacon_http_url

    # The genesis timestamp is already known from genesis generation, so use it
    # directly rather than querying the (possibly not-yet-ready) beacon node.
    genesis_time = genesis_timestamp

    charon_service_name = service_name + "-charon-split-keys-" + str(vc_index)
    CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/opt/charon/"
    persistent_key = "data-{0}".format(charon_service_name)

    charon_keys_dirpath = shared_utils.path_join(
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
        node_keystore_files.charon_keys_relative_dirpath,
    )

    files = {
        CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER: Directory(
            persistent_key=persistent_key,
        ),
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
    }

    # Run the Charon cluster creation (splits the existing keys across nodes).
    plan.add_service(
        name=charon_service_name,
        config=ServiceConfig(
            image=image,
            cmd=[
                "create",
                "cluster",
                # cluster_name label shown in Charon dashboards; mirror the
                # docker-compose convention "kurtosis-<cl>-<vc>".
                "--name=kurtosis-" + cl_context.client_name + "-" + vc_type,
                "--nodes=" + str(charon_node_count),
                "--fee-recipient-addresses=" + constants.VALIDATING_REWARDS_ACCOUNT,
                "--withdrawal-addresses=" + constants.CHARON_WITHDRAWAL_ADDRESS,
                "--split-existing-keys",
                "--split-keys-dir=" + charon_keys_dirpath,
                "--testnet-chain-id=" + network_params.network_id,
                "--testnet-fork-version=" + constants.GENESIS_FORK_VERSION,
                "--testnet-genesis-timestamp=" + str(genesis_time),
                "--testnet-name=kurtosis",
                "--cluster-dir=" + CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER,
            ],
            files=files,
            user=User(uid=0, gid=0),
        ),
    )

    # Keep a busybox service running on the cluster volume so we can read the
    # generated per-node files back out as artifacts.
    cluster_files_service = plan.add_service(
        name=charon_service_name + "-keep-running",
        config=ServiceConfig(
            image="busybox:latest",
            cmd=["tail", "-f", "/dev/null"],  # Keep the service running
            files=files,
            user=User(uid=0, gid=0),
        ),
    )

    # Wait a moment for files to be fully written
    plan.exec(
        service_name=cluster_files_service.name,
        recipe=ExecRecipe(
            command=["sleep", "5"],
        ),
    )

    # Spin up a local Charon relay so the nodes can discover each other within
    # the enclave instead of depending on the public Obol relay network.
    relay_service = plan.add_service(
        name=service_name + "-charon-relay-" + str(vc_index),
        config=ServiceConfig(
            image=image,
            cmd=[
                "relay",
                "--data-dir=/opt/charon",
                "--http-address=0.0.0.0:" + str(CHARON_RELAY_HTTP_PORT),
                "--p2p-tcp-address=0.0.0.0:" + str(CHARON_P2P_TCP_PORT),
                "--monitoring-address=0.0.0.0:" + str(CHARON_MONITORING_PORT),
                # The relay lives on a private Kurtosis network; without this it
                # advertises no addresses in its ENR and nodes fail to resolve it
                # ("timeout resolving bootnode ENR").
                "--p2p-advertise-private-addresses=true",
            ],
            ports={
                "relay-http": PortSpec(
                    number=CHARON_RELAY_HTTP_PORT,
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
                "p2p-tcp": PortSpec(
                    number=CHARON_P2P_TCP_PORT,
                    transport_protocol="TCP",
                ),
            },
            user=User(uid=0, gid=0),
        ),
    )
    charon_relay_url = "http://{0}:{1}".format(
        relay_service.ip_address, CHARON_RELAY_HTTP_PORT
    )

    # Launch Charon nodes
    charon_services = []
    for i in range(charon_node_count):
        node_name = service_name + "-charon-" + str(i)

        env_vars = {
            "CHARON_LOG_LEVEL": log_level,
            "CHARON_LOG_FORMAT": "console",
            "CHARON_P2P_RELAYS": charon_relay_url,
            "CHARON_BUILDER_API": "true",
            "CHARON_VALIDATOR_API_ADDRESS": "0.0.0.0:" + str(CHARON_VALIDATOR_API_PORT),
            "CHARON_P2P_TCP_ADDRESS": "0.0.0.0:" + str(CHARON_P2P_TCP_PORT),
            "CHARON_MONITORING_ADDRESS": "0.0.0.0:" + str(CHARON_MONITORING_PORT),
            "CHARON_PRIVATE_KEY_FILE": "/opt/charon/.charon/node"
            + str(i)
            + "/charon-enr-private-key",
            "CHARON_LOCK_FILE": "/opt/charon/.charon/node"
            + str(i)
            + "/cluster-lock.json",
            "CHARON_JAEGER_SERVICE": "node" + str(i),
            "CHARON_P2P_EXTERNAL_HOSTNAME": "node" + str(i),
            "CHARON_BEACON_NODE_ENDPOINTS": beacon_endpoint,
            "CHARON_TESTNET_CHAIN_ID": network_params.network_id,
            "CHARON_TESTNET_FORK_VERSION": constants.GENESIS_FORK_VERSION,
            "CHARON_TESTNET_GENESIS_TIMESTAMP": str(genesis_time),
            "CHARON_TESTNET_NAME": "kurtosis",
        }

        # Add any extra environment variables
        if participant.vc_extra_env_vars:
            env_vars.update(participant.vc_extra_env_vars)

        # Ports configuration
        ports = {
            "validator-api": PortSpec(
                number=CHARON_VALIDATOR_API_PORT,
                transport_protocol="TCP",
                application_protocol="http",
            ),
            "p2p-tcp": PortSpec(
                number=CHARON_P2P_TCP_PORT,
                transport_protocol="TCP",
            ),
            "monitoring": PortSpec(
                number=CHARON_MONITORING_PORT,
                transport_protocol="TCP",
                application_protocol="http",
            ),
        }

        # Charon run command
        cmd = [
            "run",
            "--testnet-chain-id=" + network_params.network_id,
            "--testnet-fork-version=" + constants.GENESIS_FORK_VERSION,
            "--testnet-genesis-timestamp=" + str(genesis_time),
            "--testnet-name=kurtosis",
        ]

        # Add the service
        charon_service = plan.add_service(
            name=node_name,
            config=ServiceConfig(
                image=image,
                ports=ports,
                cmd=cmd,
                env_vars=env_vars,
                labels=shared_utils.label_maker(
                    client=constants.VC_TYPE.charon,
                    client_type=constants.CLIENT_TYPES.validator,
                    image=image[-constants.MAX_LABEL_LENGTH :],
                    connected_client=cl_context.client_name,
                    extra_labels=participant.vc_extra_labels,
                    supernode=participant.supernode,
                ),
                tolerations=tolerations,
                node_selectors=node_selectors,
                files={
                    "/opt/charon/.charon/": Directory(persistent_key=persistent_key),
                },
                user=User(uid=0, gid=0),
            ),
        )
        charon_services.append(charon_service)

    vc_launchers = {
        constants.VC_TYPE.lighthouse: launch_lighthouse,
        constants.VC_TYPE.lodestar: launch_lodestar,
        constants.VC_TYPE.teku: launch_teku,
        constants.VC_TYPE.nimbus: launch_nimbus,
        constants.VC_TYPE.prysm: launch_prysm,
        constants.VC_TYPE.vouch: launch_vouch,
    }
    if vc_type not in vc_launchers:
        fail(
            "Unsupported Charon validator client '{0}'. Supported clients: {1}".format(
                vc_type, ", ".join(vc_launchers.keys())
            )
        )

    # Launch one validator client per Charon node, connected to that node's validator API.
    vc_services = []
    for i in range(charon_node_count):
        charon_validator_api_url = "http://{0}:{1}".format(
            charon_services[i].ip_address, CHARON_VALIDATOR_API_PORT
        )
        vc_service_name = service_name + "-vc-" + str(i) + "-" + vc_type

        # Each node's validator keys come from the cluster-creation output.
        validator_keys_for_node = plan.store_service_files(
            service_name=cluster_files_service.name,
            src=CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER
            + "/node"
            + str(i)
            + "/validator_keys",
            name="validator-keys-node-" + str(i) + "-" + str(vc_index),
        )

        vc_services.append(
            vc_launchers[vc_type](
                plan=plan,
                vc_service_name=vc_service_name,
                charon_validator_api_url=charon_validator_api_url,
                split_keys_artifact=validator_keys_for_node,
                launcher=launcher,
                keymanager_file=keymanager_file,
                participant=participant,
                global_log_level=global_log_level,
                cl_context=cl_context,
                tolerations=tolerations,
                node_selectors=node_selectors,
                network_params=network_params,
                port_publisher=port_publisher,
                full_name=full_name + "-node" + str(i),
                vc_index=vc_index,
                node_index=i,
                vc_image=vc_image,
            )
        )

    # The cluster files have all been extracted as artifacts; drop the busybox
    # helper that was only kept alive (tail -f) to read them.
    plan.remove_service(name=cluster_files_service.name)

    # Node 0 is surfaced as the participant's primary vc_context (below). Register
    # every other Charon node and all validator clients as additional Prometheus
    # scrape jobs so the whole cluster is monitored, not just node 0.
    metrics_jobs = []
    for i in range(charon_node_count):
        if i != 0:
            charon_service = charon_services[i]
            metrics_jobs.append(
                prometheus.new_metrics_job(
                    job_name=charon_service.name,
                    endpoint="{0}:{1}".format(
                        charon_service.ip_address, CHARON_MONITORING_PORT
                    ),
                    metrics_path=vc_shared.METRICS_PATH,
                    labels={
                        "service": charon_service.name,
                        "client_type": constants.CLIENT_TYPES.validator,
                        "client_name": constants.VC_TYPE.charon,
                    },
                )
            )
        vc_service = vc_services[i]
        vc_metrics_port = vc_service.ports[constants.METRICS_PORT_ID]
        metrics_jobs.append(
            prometheus.new_metrics_job(
                job_name=vc_service.name,
                endpoint="{0}:{1}".format(
                    vc_service.ip_address, vc_metrics_port.number
                ),
                metrics_path=vc_shared.METRICS_PATH,
                labels={
                    "service": vc_service.name,
                    "client_type": constants.CLIENT_TYPES.validator,
                    "client_name": vc_type,
                },
            )
        )

    # Surface Charon node 0 as the participant's primary vc_context.
    validator_metrics_port = charon_services[0].ports["monitoring"]
    validator_metrics_url = "{0}:{1}".format(
        charon_services[0].ip_address, validator_metrics_port.number
    )
    validator_node_metrics_info = node_metrics.new_node_metrics_info(
        charon_services[0].name, vc_shared.METRICS_PATH, validator_metrics_url
    )

    return (
        vc_context.new_vc_context(
            client_name=constants.VC_TYPE.charon,
            service_name=charon_services[0].name,
            metrics_info=validator_node_metrics_info,
        ),
        metrics_jobs,
    )


def _charon_split_keys_to_keystore_files(
    plan, split_keys_artifact, vc_index, node_index
):
    """
    Convert a Charon node's split keystores (a flat dir of keystore-N.json +
    keystore-N.txt) into the on-disk layouts the stock vc/<client>.star launchers
    consume, and wrap them in a node_keystore_files struct.

    Produces, in the returned artifact:
      keys/<pubkey>/voting-keystore.json + secrets/<pubkey>   (lighthouse, lodestar)
      nimbus-keys/<pubkey>/keystore.json                      (nimbus; reuses secrets/)
      teku-keys/<pubkey>.json + teku-secrets/<pubkey>.txt     (teku)
    matching the eth2-val-tools layouts, so no per-client import step is needed.
    (prysm and vouch instead need a wallet, built separately in
    _charon_split_keys_to_prysm_wallet / _charon_split_keys_to_vouch_wallet.)
    """
    converter_name = "charon-keys-convert-" + str(node_index) + "-" + str(vc_index)
    converter = plan.add_service(
        name=converter_name,
        config=ServiceConfig(
            image="busybox:latest",
            cmd=["tail", "-f", "/dev/null"],
            files={"/split-keys": split_keys_artifact},
        ),
    )

    # Reorganise each keystore-N.json/.txt pair into the on-disk layouts the stock
    # launchers expect: raw (lighthouse/lodestar), nimbus-keys (nimbus), and
    # teku-keys/teku-secrets (teku). Prysm needs a wallet, handled separately.
    convert_script = """#!/bin/sh
set -e
mkdir -p /out/keys /out/secrets /out/nimbus-keys /out/teku-keys /out/teku-secrets
for f in /split-keys/keystore-*.json; do
    [ -f "$f" ] || continue
    pubkey="0x$(grep '"pubkey"' "$f" | head -1 | awk -F'"' '{print $4}')"
    pw="${f%.json}.txt"

    # raw layout (lighthouse, lodestar): <pubkey>/voting-keystore.json + secrets/<pubkey>
    mkdir -p "/out/keys/${pubkey}"
    cp "$f" "/out/keys/${pubkey}/voting-keystore.json"
    cp "$pw" "/out/secrets/${pubkey}"

    # nimbus layout: <pubkey>/keystore.json (secrets reuse the raw secrets dir)
    mkdir -p "/out/nimbus-keys/${pubkey}"
    cp "$f" "/out/nimbus-keys/${pubkey}/keystore.json"

    # teku layout: flat <pubkey>.json + <pubkey>.txt
    cp "$f" "/out/teku-keys/${pubkey}.json"
    cp "$pw" "/out/teku-secrets/${pubkey}.txt"
done
"""
    plan.exec(
        service_name=converter.name,
        recipe=ExecRecipe(command=["sh", "-c", convert_script]),
    )

    keystore_artifact = plan.store_service_files(
        service_name=converter.name,
        src="/out",
        name="charon-raw-keys-" + str(node_index) + "-" + str(vc_index),
    )
    plan.remove_service(name=converter.name)

    return keystore_files_module.new_keystore_files(
        files_artifact_uuid=keystore_artifact,
        raw_root_dirpath="",
        raw_keys_relative_dirpath="keys",
        raw_secrets_relative_dirpath="secrets",
        nimbus_keys_relative_dirpath="nimbus-keys",
        prysm_relative_dirpath="",
        teku_keys_relative_dirpath="teku-keys",
        teku_secrets_relative_dirpath="teku-secrets",
        charon_keys_relative_dirpath="",
    )


def launch_lighthouse(
    plan,
    vc_service_name,
    charon_validator_api_url,
    split_keys_artifact,
    launcher,
    keymanager_file,
    participant,
    global_log_level,
    cl_context,
    tolerations,
    node_selectors,
    network_params,
    port_publisher,
    full_name,
    vc_index,
    node_index,
    vc_image,
):
    node_keystore_files = _charon_split_keys_to_keystore_files(
        plan, split_keys_artifact, vc_index, node_index
    )

    config = lighthouse.get_config(
        plan=plan,
        participant=participant,
        el_cl_genesis_data=launcher.el_cl_genesis_data,
        image=vc_image,
        service_name=vc_service_name,
        global_log_level=global_log_level,
        beacon_http_urls=[charon_validator_api_url],
        cl_context=cl_context,
        el_context=None,  # unused by lighthouse.get_config
        full_name=full_name,
        node_keystore_files=node_keystore_files,
        tolerations=tolerations,
        node_selectors=node_selectors,
        keymanager_enabled=False,
        network_params=network_params,
        port_publisher=port_publisher,
        vc_index=vc_index,
        extra_files_artifacts=[],
        distributed=True,
    )

    return plan.add_service(name=vc_service_name, config=config)


def launch_lodestar(
    plan,
    vc_service_name,
    charon_validator_api_url,
    split_keys_artifact,
    launcher,
    keymanager_file,
    participant,
    global_log_level,
    cl_context,
    tolerations,
    node_selectors,
    network_params,
    port_publisher,
    full_name,
    vc_index,
    node_index,
    vc_image,
):
    node_keystore_files = _charon_split_keys_to_keystore_files(
        plan, split_keys_artifact, vc_index, node_index
    )

    config = lodestar.get_config(
        plan=plan,
        participant=participant,
        el_cl_genesis_data=launcher.el_cl_genesis_data,
        keymanager_file=keymanager_file,
        image=vc_image,
        global_log_level=global_log_level,
        beacon_http_urls=[charon_validator_api_url],
        cl_context=cl_context,
        el_context=None,
        remote_signer_context=None,
        full_name=full_name,
        node_keystore_files=node_keystore_files,
        tolerations=tolerations,
        node_selectors=node_selectors,
        keymanager_enabled=False,
        network_params=network_params,
        port_publisher=port_publisher,
        vc_index=vc_index,
        extra_files_artifacts=[],
        distributed=True,
    )

    return plan.add_service(name=vc_service_name, config=config)


def launch_teku(
    plan,
    vc_service_name,
    charon_validator_api_url,
    split_keys_artifact,
    launcher,
    keymanager_file,
    participant,
    global_log_level,
    cl_context,
    tolerations,
    node_selectors,
    network_params,
    port_publisher,
    full_name,
    vc_index,
    node_index,
    vc_image,
):
    node_keystore_files = _charon_split_keys_to_keystore_files(
        plan, split_keys_artifact, vc_index, node_index
    )

    config = teku.get_config(
        plan=plan,
        participant=participant,
        el_cl_genesis_data=launcher.el_cl_genesis_data,
        keymanager_file=keymanager_file,
        image=vc_image,
        beacon_http_urls=[charon_validator_api_url],
        cl_context=cl_context,
        el_context=None,
        remote_signer_context=None,
        full_name=full_name,
        node_keystore_files=node_keystore_files,
        tolerations=tolerations,
        node_selectors=node_selectors,
        keymanager_enabled=False,
        network_params=network_params,
        port_publisher=port_publisher,
        vc_index=vc_index,
        extra_files_artifacts=[],
        distributed=True,
    )

    return plan.add_service(name=vc_service_name, config=config)


def launch_nimbus(
    plan,
    vc_service_name,
    charon_validator_api_url,
    split_keys_artifact,
    launcher,
    keymanager_file,
    participant,
    global_log_level,
    cl_context,
    tolerations,
    node_selectors,
    network_params,
    port_publisher,
    full_name,
    vc_index,
    node_index,
    vc_image,
):
    node_keystore_files = _charon_split_keys_to_keystore_files(
        plan, split_keys_artifact, vc_index, node_index
    )

    config = nimbus.get_config(
        plan=plan,
        participant=participant,
        el_cl_genesis_data=launcher.el_cl_genesis_data,
        image=vc_image,
        keymanager_file=keymanager_file,
        beacon_http_urls=[charon_validator_api_url],
        cl_context=cl_context,
        el_context=None,
        remote_signer_context=None,
        full_name=full_name,
        node_keystore_files=node_keystore_files,
        tolerations=tolerations,
        node_selectors=node_selectors,
        keymanager_enabled=False,
        network_params=network_params,
        port_publisher=port_publisher,
        vc_index=vc_index,
        extra_files_artifacts=[],
        distributed=True,
    )

    return plan.add_service(name=vc_service_name, config=config)


def _charon_split_keys_to_prysm_wallet(
    plan, split_keys_artifact, vc_index, node_index, prysm_image
):
    """
    Build a Prysm wallet from a Charon node's split keystores so the stock
    vc/prysm.star launcher (which expects a wallet, not raw keystores) can run it.

    Returns an artifact containing:
      prysm/                 the imported direct-keymanager wallet
      wallet-password.txt    the wallet password
    plus the node_keystore_files struct that points at them.
    """
    builder_name = "charon-prysm-wallet-" + str(node_index) + "-" + str(vc_index)
    builder = plan.add_service(
        name=builder_name,
        config=ServiceConfig(
            image=prysm_image,
            entrypoint=["bash", "-c"],
            cmd=["tail -f /dev/null"],
            files={"/split-keys": split_keys_artifact},
            user=User(uid=0, gid=0),
        ),
    )

    build_script = """#!/usr/bin/env bash
set -e
mkdir -p /out
echo "prysm-validator-secret" > /out/wallet-password.txt
/app/cmd/validator/validator wallet create \\
    --accept-terms-of-use \\
    --keymanager-kind=direct \\
    --wallet-dir=/out/prysm \\
    --wallet-password-file=/out/wallet-password.txt
tmpkeys=/tmp/keys
mkdir -p "$tmpkeys"
for f in /split-keys/keystore-*.json; do
    [ -f "$f" ] || continue
    cp "$f" "$tmpkeys/"
    /app/cmd/validator/validator accounts import \\
        --accept-terms-of-use=true \\
        --wallet-dir=/out/prysm \\
        --keys-dir="$tmpkeys" \\
        --account-password-file="${f%.json}.txt" \\
        --wallet-password-file=/out/wallet-password.txt
    rm "$tmpkeys/$(basename "$f")"
done
"""
    plan.exec(
        service_name=builder.name,
        recipe=ExecRecipe(command=["bash", "-c", build_script]),
    )

    wallet_artifact = plan.store_service_files(
        service_name=builder.name,
        src="/out",
        name="charon-prysm-wallet-files-" + str(node_index) + "-" + str(vc_index),
    )
    plan.remove_service(name=builder.name)

    node_keystore_files = keystore_files_module.new_keystore_files(
        files_artifact_uuid=wallet_artifact,
        raw_root_dirpath="",
        raw_keys_relative_dirpath="",
        raw_secrets_relative_dirpath="",
        nimbus_keys_relative_dirpath="",
        prysm_relative_dirpath="prysm",
        teku_keys_relative_dirpath="",
        teku_secrets_relative_dirpath="",
        charon_keys_relative_dirpath="",
    )
    return wallet_artifact, node_keystore_files


def _charon_split_keys_to_vouch_wallet(plan, split_keys_artifact, vc_index, node_index):
    """
    Build an ethdo wallet from a Charon node's split keystores by running the
    official ethdo image, so the Vouch container itself needs no ethdo (and no
    apt/download) — it just mounts the result.

    Returns an artifact containing:
      wallets/                  the ethdo wallet store
      accounts.txt              one account path per line (vals/valN)
      account-passphrase.txt    the account passphrase
    """
    builder_name = "charon-vouch-wallet-" + str(node_index) + "-" + str(vc_index)
    builder = plan.add_service(
        name=builder_name,
        config=ServiceConfig(
            image=ETHDO_IMAGE,
            entrypoint=["sh", "-c"],
            cmd=["tail -f /dev/null"],
            files={"/split-keys": split_keys_artifact},
            user=User(uid=0, gid=0),
        ),
    )

    build_script = """set -e
mkdir -p /out/wallets
echo "1234" > /out/account-passphrase.txt
: > /out/accounts.txt
/app/ethdo --base-dir=/out/wallets wallet create --wallet=vals --passphrase=""
index=0
for f in /split-keys/keystore-*.json; do
    [ -f "$f" ] || continue
    /app/ethdo --base-dir=/out/wallets account import \\
        --account="vals/val${index}" \\
        --keystore="$f" \\
        --keystore-passphrase="$(cat "${f%.json}.txt")" \\
        --passphrase="1234" --allow-weak-passphrases
    echo "vals/val${index}" >> /out/accounts.txt
    index=$((index + 1))
done
"""
    plan.exec(
        service_name=builder.name,
        recipe=ExecRecipe(command=["sh", "-c", build_script]),
    )

    wallet_artifact = plan.store_service_files(
        service_name=builder.name,
        src="/out",
        name="charon-vouch-wallet-files-" + str(node_index) + "-" + str(vc_index),
    )
    plan.remove_service(name=builder.name)
    return wallet_artifact


def launch_prysm(
    plan,
    vc_service_name,
    charon_validator_api_url,
    split_keys_artifact,
    launcher,
    keymanager_file,
    participant,
    global_log_level,
    cl_context,
    tolerations,
    node_selectors,
    network_params,
    port_publisher,
    full_name,
    vc_index,
    node_index,
    vc_image,
):
    wallet_artifact, node_keystore_files = _charon_split_keys_to_prysm_wallet(
        plan, split_keys_artifact, vc_index, node_index, vc_image
    )

    config = prysm.get_config(
        plan=plan,
        participant=participant,
        el_cl_genesis_data=launcher.el_cl_genesis_data,
        keymanager_file=keymanager_file,
        image=vc_image,
        beacon_http_urls=[charon_validator_api_url],
        cl_context=cl_context,
        el_context=None,
        remote_signer_context=None,
        full_name=full_name,
        node_keystore_files=node_keystore_files,
        prysm_password_relative_filepath="wallet-password.txt",
        prysm_password_artifact_uuid=wallet_artifact,
        tolerations=tolerations,
        node_selectors=node_selectors,
        keymanager_enabled=False,
        network_params=network_params,
        port_publisher=port_publisher,
        vc_index=vc_index,
        extra_files_artifacts=[],
        distributed=True,
    )

    return plan.add_service(name=vc_service_name, config=config)


def launch_vouch(
    plan,
    vc_service_name,
    charon_validator_api_url,
    split_keys_artifact,
    launcher,
    keymanager_file,
    participant,
    global_log_level,
    cl_context,
    tolerations,
    node_selectors,
    network_params,
    port_publisher,
    full_name,
    vc_index,
    node_index,
    vc_image,
):
    vouch_wallet_artifact = _charon_split_keys_to_vouch_wallet(
        plan, split_keys_artifact, vc_index, node_index
    )

    config = vouch.get_config(
        plan=plan,
        participant=participant,
        image=vc_image,
        global_log_level=global_log_level,
        beacon_http_urls=[charon_validator_api_url],
        cl_context=cl_context,
        vouch_wallet_artifact=vouch_wallet_artifact,
        tolerations=tolerations,
        node_selectors=node_selectors,
    )

    return plan.add_service(name=vc_service_name, config=config)


def new_charon_launcher(el_cl_genesis_data):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
    )
