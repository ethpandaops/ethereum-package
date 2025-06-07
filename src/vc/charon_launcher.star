shared_utils = import_module("../shared_utils/shared_utils.star")
input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
cl_context = import_module("../cl/cl_context.star")
vc_shared = import_module("./shared.star")
vc_context = import_module("./vc_context.star")
node_metrics = import_module("../node_metrics_info.star")

# Charon specific ports
CHARON_VALIDATOR_API_PORT = 3600
CHARON_P2P_TCP_PORT = 3610
CHARON_MONITORING_PORT = 3620
CHARON_METRICS_PORT = 8080

# Default Charon image
DEFAULT_CHARON_IMAGE = "obolnetwork/charon:latest"

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
    el_context,
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
    VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS = "/validator-keys"

    if node_keystore_files == None:
        return None

    tolerations = input_parser.get_client_tolerations(
        participant.vc_tolerations, participant.tolerations, global_tolerations
    )

    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, VERBOSITY_LEVELS
    )

    # Get the number of Charon nodes to create (default to 4)
    charon_node_count = 4
    if hasattr(participant, "charon_node_count") and participant.charon_node_count > 0:
        charon_node_count = participant.charon_node_count

    # Get the beacon node endpoints for each Charon node
    beacon_endpoints = []
    for i in range(charon_node_count):
        # Just use the same beacon node for all Charon nodes
        beacon_endpoints.append(cl_context.beacon_http_url)

    # Fetch the actual genesis timestamp from the beacon node
    genesis_response = plan.run_sh(
        name="get-genesis-timestamp",
        description="Get the genesis timestamp from the beacon node",
        run="curl -s " + cl_context.beacon_http_url + "/eth/v1/beacon/genesis | jq -r '.data.genesis_time' | tr -d '\\n'",
    )

    # Extract the genesis timestamp from the response
    genesis_time = genesis_response.output

    # Get the raw validator keys directory path
    validator_keys_dirpath = ""
    if node_keystore_files:
        validator_keys_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.raw_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.raw_secrets_relative_dirpath,
        )

    # Create a temporary service to format the validator keys for Charon
    # Use busybox as a lightweight image for key formatting
    key_formatter_service = plan.add_service(
        name=service_name + "-key-formatter-" + str(vc_index),
        config=ServiceConfig(
            image="busybox:latest",
            cmd=["tail", "-f", "/dev/null"],  # Keep the service running
            files={
                constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
            },
        ),
    )

    # Create a directory for Charon-formatted keys
    plan.exec(
        service_name=key_formatter_service.name,
        recipe=ExecRecipe(
            command=["mkdir", "-p", "/opt/charon/charon-keys"],
        ),
    )

    # Create a script to format the validator keys for Charon
    format_keys_script = """#!/bin/sh
# Find all directories in the validator keys directory
keystore_directories="%s/*"

index=0
echo "Processing keystores from ${keystore_directories}"

# Create directory with proper permissions
mkdir -p /opt/charon/charon-keys
chmod 755 /opt/charon/charon-keys

# Iterate over each directory
for keystore_dir in $keystore_directories; do
    # Check if it's a directory
    if [ -d "$keystore_dir" ]; then
        # Copy 'voting-keystore.json' to 'charon-keys' with an indexed name
        cp "$keystore_dir/voting-keystore.json" "/opt/charon/charon-keys/keystore-${index}.json"
        chmod 644 "/opt/charon/charon-keys/keystore-${index}.json"

        # Extract the directory name (pubkey) from the current keystore directory
        dir_name=$(basename "$keystore_dir")

        # Check if a file with the same name exists in the secrets directory and copy it
        if [ -f "%s/$dir_name" ]; then
            cp "%s/$dir_name" "/opt/charon/charon-keys/keystore-${index}.txt"
            chmod 644 "/opt/charon/charon-keys/keystore-${index}.txt"
        else
            echo "No matching file found in secrets directory for '$dir_name'."
        fi

        # Increment the index for the next iteration (busybox compatible)
        index=$(($index + 1))
    fi
done
""" % (validator_keys_dirpath, validator_secrets_dirpath, validator_secrets_dirpath)

    # Save the script to the service
    plan.exec(
        service_name=key_formatter_service.name,
        recipe=ExecRecipe(
            command=[
                "sh", "-c", "cat > /opt/charon/format_keys.sh << 'EOL'\n" + format_keys_script + "\nEOL"
            ],
        ),
    )

    # Make the script executable
    plan.exec(
        service_name=key_formatter_service.name,
        recipe=ExecRecipe(
            command=["chmod", "+x", "/opt/charon/format_keys.sh"],
        ),
    )

    # Run the script to format the keys
    plan.exec(
        service_name=key_formatter_service.name,
        recipe=ExecRecipe(
            command=["/opt/charon/format_keys.sh"],
        ),
    )

    # Store the formatted keys
    charon_keys_artifact = plan.store_service_files(
        service_name=key_formatter_service.name, src="/opt/charon/charon-keys", name="charon-keys-" + str(vc_index),
    )

    # Set the path to the formatted keys for the Charon cluster creation
    # charon_keys_dir = "/opt/charon/charon-keys"

    charon_service_name = service_name + "-charon-split-keys-" + str(vc_index)
    CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/opt/charon/"
    persistent_key = "data-{0}".format(charon_service_name)

    files = {}
    files[CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
            persistent_key=persistent_key,
    )
    files["/opt/charon/charon-keys"] = charon_keys_artifact

    # Create a temporary service to run the Charon cluster creation
    # Use the Charon image for cluster creation with the direct command
    temp_service = plan.add_service(
        name=charon_service_name,
        config=ServiceConfig(
            image=image,
            cmd=[
                "create", "cluster",
                "--name=test",
                "--nodes=" + str(charon_node_count),
                "--fee-recipient-addresses=0x8943545177806ED17B9F23F0a21ee5948eCaa776",
                "--withdrawal-addresses=0xBc7c960C1097ef1Af0FD32407701465f3c03e407",
                "--split-existing-keys",
                "--split-keys-dir=/opt/charon/charon-keys",
                "--testnet-chain-id=3151908",
                "--testnet-fork-version=0x10000038",
                "--testnet-genesis-timestamp=" + str(genesis_time),
                "--testnet-name=kurtosis-testnet",
                "--cluster-dir=" + CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER,
            ],
            files=files,
            user = User(uid=0, gid=0),
        ),
    )

    # Restart the temporary service but with busy box image and keep running
    temp_service = plan.add_service(
        name=charon_service_name+"-keep-running",
        config=ServiceConfig(
            image="busybox:latest",
            cmd=["tail", "-f", "/dev/null"],  # Keep the service running
            files=files,
            user = User(uid=0, gid=0),
        ),
    )

    # Wait a moment for files to be fully written
    plan.exec(
        service_name=temp_service.name,
        recipe=ExecRecipe(
            command=["sleep", "5"],
        ),
    )

    # Store the Charon cluster files
    # First store the entire cluster directory to get all shared files
    # For e
    charon_cluster_files = plan.store_service_files(
        service_name=temp_service.name,
        src=CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        name="charon-cluster-files-" + str(vc_index)
    )

    # Then store each node's files separately for individual access
    charon_node_files = []
    charon_lock = []
    for i in range(charon_node_count):
        charon_node_files.append(plan.store_service_files(
            service_name=temp_service.name,
            src=CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER + "/node" + str(i),
            name="charon-node-files-" + str(i) + "-" + str(vc_index)
        ))

    # Launch Charon nodes
    charon_services = []
    for i in range(charon_node_count):
        node_name = service_name + "-charon-" + str(i)

        # cmd=["tail", "-f", "/dev/null"]

        # cmd = [
        #     "run",
        #     "--testnet-chain-id=3151908",
        #     "--testnet-fork-version=0x10000038",
        #     "--testnet-genesis-timestamp=" + str(genesis_time),
        #     "--testnet-name=testnet",
        # ]

        # if len(participant.vc_extra_params) > 0:
        #     cmd.extend([param for param in participant.vc_extra_params])

        env_vars = {
            "CHARON_LOG_LEVEL": "debug",
            "CHARON_LOG_FORMAT": "console",
            "CHARON_P2P_RELAYS": "https://0.relay.obol.tech",
            "CHARON_BUILDER_API": "true",
            "CHARON_VALIDATOR_API_ADDRESS": "0.0.0.0:" + str(CHARON_VALIDATOR_API_PORT),
            "CHARON_P2P_TCP_ADDRESS": "0.0.0.0:" + str(CHARON_P2P_TCP_PORT),
            "CHARON_MONITORING_ADDRESS": "0.0.0.0:" + str(CHARON_MONITORING_PORT),
            "CHARON_PRIVATE_KEY_FILE": "/opt/charon/.charon/node" + str(i) + "/charon-enr-private-key",
            "CHARON_LOCK_FILE": "/opt/charon/.charon/node" + str(i) + "/cluster-lock.json",
            "CHARON_JAEGER_SERVICE": "node" + str(i),
            "CHARON_P2P_EXTERNAL_HOSTNAME": "node" + str(i),
            "CHARON_BEACON_NODE_ENDPOINTS": beacon_endpoints[i],
            "CHARON_TESTNET_CHAIN_ID": "3151908",
            "CHARON_TESTNET_FORK_VERSION": "0x10000038",
            "CHARON_TESTNET_GENESIS_TIMESTAMP": str(genesis_time),
            "CHARON_TESTNET_NAME": "kurtosis-testnet",
        }

        # Add any extra environment variables
        if hasattr(participant, "vc_extra_env_vars") and participant.vc_extra_env_vars:
            env_vars.update(participant.vc_extra_env_vars)

        # Files to mount
        # files = {
        #     "/opt/charon/.charon/cluster": charon_node_files[i],
        #     # "/opt/charon/.charon/cluster/cluster-lock.json": charon_lock[i],
        # }

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
            # constants.METRICS_PORT_ID: PortSpec(
            #     number=CHARON_METRICS_PORT,
            #     transport_protocol="TCP",
            #     application_protocol="http",
            # ),
        }

        # Charon run command
        cmd = [
            "run",
            "--testnet-chain-id=3151908",
            "--testnet-fork-version=0x10000038",
            "--testnet-genesis-timestamp=" + str(genesis_time),
            "--testnet-name=kurtosis-testnet",
        ]

        # Add the service
        charon_service = plan.add_service(
            name=node_name,
            config=ServiceConfig(
                # image=image,
                image="obolnetwork/charon:latest",
                ports=ports,
                cmd=cmd,
                env_vars=env_vars,
                labels=shared_utils.label_maker(
                    client=constants.VC_TYPE.charon,
                    client_type=constants.CLIENT_TYPES.validator,
                    image=image[-constants.MAX_LABEL_LENGTH:],
                    connected_client=cl_context.client_name,
                    extra_labels=participant.vc_extra_labels,
                    supernode=participant.supernode,
                ),
                tolerations=tolerations,
                node_selectors=node_selectors,
                files={
                    "/opt/charon/.charon/": Directory(
                        persistent_key=persistent_key
                    ),
                },
                user = User(uid=0, gid=0),
            ),
        )
        charon_services.append(charon_service)

    # Now launch the validator clients that will connect to Charon nodes
    vc_services = []
    for i in range(charon_node_count):
        # Determine which validator client to use with Charon
        vc_type = "lighthouse"  # Default
        if hasattr(participant, "charon_validator_client"):
            vc_type = participant.charon_validator_client

        # Create VC service name
        vc_service_name = service_name + "-vc-" + str(i) + "-" + vc_type

        # Get the Charon node's validator API URL
        charon_validator_api_url = "http://{0}:{1}".format(
            charon_services[i].ip_address,
            CHARON_VALIDATOR_API_PORT
        )

        # Create validator keys directory for this specific node
        validator_keys_for_node = plan.store_service_files(
            service_name=temp_service.name,
            src=CHARON_DATA_DIRPATH_ON_CLIENT_CONTAINER + "/node" + str(i) + "/validator_keys",
            name="validator-keys-node-" + str(i) + "-" + str(vc_index)
        )

        # Launch the validator client based on type
        if vc_type == "lighthouse":
            vc_service = launch_lighthouse_vc(
                plan=plan,
                vc_service_name=vc_service_name,
                charon_validator_api_url=charon_validator_api_url,
                validator_keys_artifact=validator_keys_for_node,
                launcher=launcher,
                participant=participant,
                tolerations=tolerations,
                node_selectors=node_selectors,
                full_name=full_name + "-node" + str(i),
                vc_index=vc_index,
                node_index=i
            )
            vc_services.append(vc_service)
        elif vc_type == "lodestar":
            vc_service = launch_lodestar_vc(
                plan=plan,
                vc_service_name=vc_service_name,
                charon_validator_api_url=charon_validator_api_url,
                validator_keys_artifact=validator_keys_for_node,
                launcher=launcher,
                participant=participant,
                tolerations=tolerations,
                node_selectors=node_selectors,
                full_name=full_name + "-node" + str(i),
                vc_index=vc_index,
                node_index=i
            )
            vc_services.append(vc_service)
        elif vc_type == "teku":
            vc_service = launch_teku_vc(
                plan=plan,
                vc_service_name=vc_service_name,
                charon_validator_api_url=charon_validator_api_url,
                validator_keys_artifact=validator_keys_for_node,
                launcher=launcher,
                participant=participant,
                tolerations=tolerations,
                node_selectors=node_selectors,
                full_name=full_name + "-node" + str(i),
                vc_index=vc_index,
                node_index=i
            )
            vc_services.append(vc_service)
        elif vc_type == "nimbus":
            vc_service = launch_nimbus_vc(
                plan=plan,
                vc_service_name=vc_service_name,
                charon_validator_api_url=charon_validator_api_url,
                validator_keys_artifact=validator_keys_for_node,
                launcher=launcher,
                participant=participant,
                tolerations=tolerations,
                node_selectors=node_selectors,
                full_name=full_name + "-node" + str(i),
                vc_index=vc_index,
                node_index=i
            )
            vc_services.append(vc_service)
        else:
            # For now, only lighthouse, lodestar, teku, and nimbus are supported
            fail("Only lighthouse, lodestar, teku, and nimbus validator clients are currently supported with Charon")

    # Return the first Charon service as the main service
    validator_metrics_port = charon_services[0].ports["monitoring"]
    validator_metrics_url = "{0}:{1}".format(
        charon_services[0].ip_address, validator_metrics_port.number
    )
    validator_node_metrics_info = node_metrics.new_node_metrics_info(
        charon_services[0].name, vc_shared.METRICS_PATH, validator_metrics_url
    )

    return vc_context.new_vc_context(
        client_name=constants.VC_TYPE.charon,
        service_name=charon_services[0].name,
        metrics_info=validator_node_metrics_info,
    )

def launch_lighthouse_vc(
    plan,
    vc_service_name,
    charon_validator_api_url,
    validator_keys_artifact,
    launcher,
    participant,
    tolerations,
    node_selectors,
    full_name,
    vc_index,
    node_index
):
    """
    Launch a Lighthouse validator client that connects to a Charon node
    Uses the two-stage approach: import keys, then run validator
    """

    # Create the startup script that implements the two-stage approach
    startup_script = """#!/bin/bash
set -e

# Install required packages
apt-get update && apt-get install -y curl jq wget

# Wait for Charon node to be available
# while ! curl "${LIGHTHOUSE_BEACON_NODE_ADDRESS}/eth/v1/node/health" 2>/dev/null; do
#   echo "Waiting for ${LIGHTHOUSE_BEACON_NODE_ADDRESS} to become available..."
#   sleep 5
# done

echo "Charon node is available, proceeding with key import..."

# Stage 1: Import validator keys
for f in /opt/charon/keys/keystore-*.json; do
  if [ -f "$f" ]; then
    echo "Importing key ${f}"
    lighthouse account validator import \\
      --reuse-password \\
      --keystore "${f}" \\
      --password-file "${f//json/txt}" \\
      --testnet-dir "/opt/lighthouse/network-configs"
  fi
done

echo "Starting lighthouse validator client for node""" + str(node_index) + """"
# Stage 2: Run the validator client
exec lighthouse validator \\
  --beacon-nodes ${LIGHTHOUSE_BEACON_NODE_ADDRESS} \\
  --suggested-fee-recipient """ + constants.VALIDATING_REWARDS_ACCOUNT + """ \\
  --metrics \\
  --metrics-address "0.0.0.0" \\
  --metrics-allow-origin "*" \\
  --metrics-port """ + str(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM) + """ \\
  --use-long-timeouts \\
  --testnet-dir "/opt/lighthouse/network-configs" \\
  --builder-proposals \\
  --distributed \\
  --debug-level "debug"
"""

    # Environment variables
    env_vars = {
        "LIGHTHOUSE_BEACON_NODE_ADDRESS": charon_validator_api_url,
        "NODE": "node" + str(node_index),
        "RUST_BACKTRACE": "full"
    }
    if hasattr(participant, "vc_extra_env_vars") and participant.vc_extra_env_vars:
        env_vars.update(participant.vc_extra_env_vars)

    # Files to mount
    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        "/opt/charon/keys": validator_keys_artifact,
        "/opt/lighthouse/network-configs": launcher.el_cl_genesis_data.files_artifact_uuid,
    }

    # Ports configuration
    ports = {
        constants.METRICS_PORT_ID: PortSpec(
            number=vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM,
            transport_protocol="TCP",
            application_protocol="http",
        ),
    }

    # Create the service with the startup script
    vc_service = plan.add_service(
        name=vc_service_name,
        config=ServiceConfig(
            image="sigp/lighthouse:latest",
            ports=ports,
            cmd=["bash", "-c", startup_script],
            env_vars=env_vars,
            files=files,
            labels=shared_utils.label_maker(
                client=constants.VC_TYPE.lighthouse,
                client_type=constants.CLIENT_TYPES.validator,
                image="sigp/lighthouse:latest"[-constants.MAX_LABEL_LENGTH:],
                connected_client="charon-node-" + str(node_index),
                extra_labels=participant.vc_extra_labels if hasattr(participant, "vc_extra_labels") else {},
                supernode=participant.supernode if hasattr(participant, "supernode") else False,
            ),
            tolerations=tolerations,
            node_selectors=node_selectors,
        ),
    )

    return vc_service

def launch_lodestar_vc(
    plan,
    vc_service_name,
    charon_validator_api_url,
    validator_keys_artifact,
    launcher,
    participant,
    tolerations,
    node_selectors,
    full_name,
    vc_index,
    node_index
):
    """
    Launch a Lodestar validator client that connects to a Charon node
    Uses Charon-specific key management with standard Lodestar parameters
    """

    # Create the run.sh script content (similar to kurtosis-charon/lodestar/run.sh)
    run_script_content = """#!/bin/sh

BUILDER_SELECTION="executiononly"

# If the builder API is enabled, override the builder selection to signal Lodestar to always prefer proposing blinded blocks, but fall back on EL blocks if unavailable.
if [ "$BUILDER_API_ENABLED" = "true" ]; then
    BUILDER_SELECTION="builderalways"
fi

DATA_DIR="/opt/data"
KEYSTORES_DIR="${DATA_DIR}/keystores"
SECRETS_DIR="${DATA_DIR}/secrets"

mkdir -p "${KEYSTORES_DIR}" "${SECRETS_DIR}"

IMPORTED_COUNT=0
EXISTING_COUNT=0

for f in /home/charon/validator_keys/keystore-*.json; do
    echo "Importing key ${f}"

    # Extract pubkey from keystore file
    PUBKEY="0x$(grep '"pubkey"' "$f" | awk -F'"' '{print $4}')"

    PUBKEY_DIR="${KEYSTORES_DIR}/${PUBKEY}"

    # Skip import if keystore already exists
    if [ -d "${PUBKEY_DIR}" ]; then
        EXISTING_COUNT=$((EXISTING_COUNT + 1))
        continue
    fi

    mkdir -p "${PUBKEY_DIR}"
    chown 1000:1000 "${PUBKEY_DIR}"

    # Copy the keystore file to persisted keys backend
    install -m 600 "$f" "${PUBKEY_DIR}/voting-keystore.json"
    chown 1000:1000 "${PUBKEY_DIR}/voting-keystore.json"

    # Copy the corresponding password file
    PASSWORD_FILE="${f%.json}.txt"
    install -m 600 "${PASSWORD_FILE}" "${SECRETS_DIR}/${PUBKEY}"

    IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
done

echo "Processed all keys imported=${IMPORTED_COUNT}, existing=${EXISTING_COUNT}, total=$(ls /home/charon/validator_keys/keystore-*.json | wc -l)"

exec node /usr/app/packages/cli/bin/lodestar validator \\
    --dataDir="$DATA_DIR" \\
    --keystoresDir="$KEYSTORES_DIR" \\
    --secretsDir="$SECRETS_DIR" \\
    --metrics=true \\
    --metrics.address="0.0.0.0" \\
    --metrics.port=""" + str(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM) + """ \\
    --beaconNodes="$BEACON_NODE_ADDRESS" \\
    --builder="$BUILDER_API_ENABLED" \\
    --builder.selection="$BUILDER_SELECTION" \\
    --distributed \\
    --paramsFile="/opt/lodestar/config.yaml"
"""

    # Add extra params if specified
    if hasattr(participant, "vc_extra_params") and len(participant.vc_extra_params) > 0:
        extra_params = " \\\n    " + " \\\n    ".join(participant.vc_extra_params)
        run_script_content += extra_params

    # Create the script file artifact using render_templates
    script_artifact = plan.render_templates(
        config={
            "run.sh": struct(
                template=run_script_content,
                data={},
            ),
        },
        name="lodestar-run-script-" + str(node_index) + "-" + str(vc_index),
    )

    # Debug: Print that the script artifact has been created
    plan.print("Created Lodestar run script artifact: lodestar-run-script-" + str(node_index) + "-" + str(vc_index))
    plan.print("You can download this script using: kurtosis files download <enclave> lodestar-run-script-" + str(node_index) + "-" + str(vc_index))

    # Environment variables
    env_vars = {
        "BEACON_NODE_ADDRESS": charon_validator_api_url,
        "BUILDER_API_ENABLED": "true",
        "NODE": "node" + str(node_index),
    }
    if hasattr(participant, "vc_extra_env_vars") and participant.vc_extra_env_vars:
        env_vars.update(participant.vc_extra_env_vars)

    # Files to mount - Charon keys + standard genesis data + run script
    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        "/home/charon/validator_keys": validator_keys_artifact,
        "/opt/lodestar": launcher.el_cl_genesis_data.files_artifact_uuid,
        "/opt/charon": script_artifact,
    }

    # Ports configuration
    ports = {
        constants.METRICS_PORT_ID: PortSpec(
            number=vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM,
            transport_protocol="TCP",
            application_protocol="http",
        ),
    }

    # Create the service - execute the script file
    vc_service = plan.add_service(
        name=vc_service_name,
        config=ServiceConfig(
            image="chainsafe/lodestar:latest",
            ports=ports,
            cmd=["chmod +x /opt/charon/run.sh && /opt/charon/run.sh"],
            entrypoint=["sh", "-c"],
            env_vars=env_vars,
            files=files,
            labels=shared_utils.label_maker(
                client=constants.VC_TYPE.lodestar,
                client_type=constants.CLIENT_TYPES.validator,
                image="chainsafe/lodestar:latest"[-constants.MAX_LABEL_LENGTH:],
                connected_client="charon-node-" + str(node_index),
                extra_labels=participant.vc_extra_labels if hasattr(participant, "vc_extra_labels") else {},
                supernode=participant.supernode if hasattr(participant, "supernode") else False,
            ),
            tolerations=tolerations,
            node_selectors=node_selectors,
        ),
    )

    return vc_service

def launch_teku_vc(
    plan,
    vc_service_name,
    charon_validator_api_url,
    validator_keys_artifact,
    launcher,
    participant,
    tolerations,
    node_selectors,
    full_name,
    vc_index,
    node_index
):
    """
    Launch a Teku validator client that connects to a Charon node
    Uses config file approach similar to compose.teku.yaml
    """

    # Create the teku-config.yaml content based on kurtosis-charon/teku/teku-config.yaml
    teku_config_content = """metrics-enabled: true
metrics-host-allowlist: "*"
metrics-interface: "0.0.0.0"
metrics-port: \"""" + str(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM) + """\"
validators-keystore-locking-enabled: false
network: "/opt/teku/network-configs/config.yaml"
validator-keys: "/opt/charon/validator_keys:/opt/charon/validator_keys"
validators-proposer-default-fee-recipient: \"""" + constants.VALIDATING_REWARDS_ACCOUNT + """\"
"""

    # Create the config file artifact using render_templates
    config_artifact = plan.render_templates(
        config={
            "teku-config.yaml": struct(
                template=teku_config_content,
                data={},
            ),
        },
        name="teku-config-" + str(node_index) + "-" + str(vc_index),
    )

    # Debug: Print that the config artifact has been created
    plan.print("Created Teku config artifact: teku-config-" + str(node_index) + "-" + str(vc_index))
    plan.print("You can download this config using: kurtosis files download <enclave> teku-config-" + str(node_index) + "-" + str(vc_index))

    # Teku validator command based on standard teku.star but with Charon-specific flags
    cmd = [
        "validator-client",
        "--network=/opt/teku/network-configs/config.yaml",
        "--beacon-node-api-endpoint=" + charon_validator_api_url,
        "--config-file=/opt/charon/teku/teku-config.yaml",
        "--validators-external-signer-slashing-protection-enabled=true",
        "--validators-proposer-blinded-blocks-enabled=true",
        "--validators-builder-registration-default-enabled=true",
        "--Xobol-dvt-integration-enabled=true",
        "--logging=DEBUG",
        "--metrics-enabled=true",
        "--metrics-host-allowlist=*",
        "--metrics-interface=0.0.0.0",
        "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
    ]

    # print the cmd
    plan.print("cmd: " + str(cmd))

    # Add extra params if specified
    if hasattr(participant, "vc_extra_params") and len(participant.vc_extra_params) > 0:
        cmd.extend([param for param in participant.vc_extra_params])

    # Environment variables
    env_vars = {}
    if hasattr(participant, "vc_extra_env_vars") and participant.vc_extra_env_vars:
        env_vars.update(participant.vc_extra_env_vars)

    # Files to mount - Charon keys + standard genesis data + teku config
    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        "/opt/charon/validator_keys": validator_keys_artifact,
        "/opt/charon/teku": config_artifact,
        "/opt/teku/network-configs": launcher.el_cl_genesis_data.files_artifact_uuid,
    }

    # Ports configuration
    ports = {
        constants.METRICS_PORT_ID: PortSpec(
            number=vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM,
            transport_protocol="TCP",
            application_protocol="http",
        ),
    }

    # Create the service
    vc_service = plan.add_service(
        name=vc_service_name,
        config=ServiceConfig(
            image="consensys/teku:latest",
            ports=ports,
            cmd = cmd,
            # cmd=["tail", "-f", "/dev/null"],
            # entrypoint= ["sh", "-c"],
            env_vars=env_vars,
            files=files,
            labels=shared_utils.label_maker(
                client=constants.VC_TYPE.teku,
                client_type=constants.CLIENT_TYPES.validator,
                image="consensys/teku:latest"[-constants.MAX_LABEL_LENGTH:],
                connected_client="charon-node-" + str(node_index),
                extra_labels=participant.vc_extra_labels if hasattr(participant, "vc_extra_labels") else {},
                supernode=participant.supernode if hasattr(participant, "supernode") else False,
            ),
            tolerations=tolerations,
            node_selectors=node_selectors,
            user = User(uid=0, gid=0),
        ),
    )

    return vc_service

def launch_nimbus_vc(
    plan,
    vc_service_name,
    charon_validator_api_url,
    validator_keys_artifact,
    launcher,
    participant,
    tolerations,
    node_selectors,
    full_name,
    vc_index,
    node_index
):
    """
    Launch a Nimbus validator client that connects to a Charon node
    Uses a two-service approach:
    1. Key import service using nimbus-eth2 (beacon node) to import keys
    2. Validator client service using nimbus-validator-client with imported keys
    """

    # Step 1: Create key import service using beacon node image
    key_import_service_name = vc_service_name + "-key-import"

    # Create the key import script
    key_import_script = """#!/usr/bin/env bash

# Cleanup nimbus directories if they already exist.
rm -rf /home/user/data/${NODE}

# Refer: https://nimbus.guide/keys.html
# Running a nimbus VC involves two steps which need to run in order:
# 1. Importing the validator keys
# 2. And then actually running the VC
tmpkeys="/home/validator_keys/tmpkeys"
mkdir -p ${tmpkeys}

for f in /home/validator_keys/keystore-*.json; do
  echo "Importing key ${f}"

  # Read password from keystore-*.txt into $password variable.
  password=$(<"${f//json/txt}")
  echo "Password length: ${#password}"

  # Copy keystore file to tmpkeys/ directory.
  cp "${f}" "${tmpkeys}"
  echo "Copied ${f} to ${tmpkeys}"

  # List files in tmpkeys before import
  echo "Files in tmpkeys before import:"
  ls -la "${tmpkeys}"

  # Import keystore with the password.
  echo "Running nimbus import command..."
  echo "$password" | \\
  /home/user/nimbus_beacon_node deposits import \\
  --data-dir=/home/user/data/${NODE} \\
  /home/validator_keys/tmpkeys

  IMPORT_RESULT=$?
  echo "Import command exit code: $IMPORT_RESULT"

  # Check what was created
  echo "Contents of data directory after import:"
  ls -la /home/user/data/${NODE}/ || echo "Data directory does not exist"
  if [ -d "/home/user/data/${NODE}/validators" ]; then
    echo "Validators directory contents:"
    ls -la /home/user/data/${NODE}/validators/
  fi

  # Delete tmpkeys/keystore-*.json file that was copied before.
  filename="$(basename ${f})"
  rm "${tmpkeys}/${filename}"
  echo "Deleted ${tmpkeys}/${filename}"
done

# Delete the tmpkeys/ directory since it's no longer needed.
rm -r ${tmpkeys}

echo "Imported all keys successfully"
echo "Key import process completed"

# Create a completion marker file to signal that import is done
echo "IMPORT_COMPLETE" > /home/user/data/import_complete.txt
echo "Created completion marker file"

# Keep the container running so we can extract the data
tail -f /dev/null
"""

    # Create the key import script artifact
    key_import_script_artifact = plan.render_templates(
        config={
            "import_keys.sh": struct(
                template=key_import_script,
                data={},
            ),
        },
        name="nimbus-key-import-script-" + str(node_index) + "-" + str(vc_index),
    )

    # Environment variables for key import
    import_env_vars = {
        "NODE": "node" + str(node_index),
    }

    # Files to mount for key import
    import_files = {
        "/home/validator_keys": validator_keys_artifact,
        "/home/user/scripts": key_import_script_artifact,
    }

    # Create the key import service
    plan.print("Creating Nimbus key import service: " + key_import_service_name)
    key_import_service = plan.add_service(
        name=key_import_service_name,
        config=ServiceConfig(
            image="statusim/nimbus-eth2:multiarch-latest",
            cmd=["chmod +x /home/user/scripts/import_keys.sh && /home/user/scripts/import_keys.sh"],
            entrypoint=["bash", "-c"],
            env_vars=import_env_vars,
            files=import_files,
            user=User(uid=0, gid=0),
        ),
    )

    # Step 2: Wait for key import to complete and then extract the keys as an artifact
    plan.print("Waiting for key import to complete...")

    # Wait for the completion marker file to be created
    plan.exec(
        service_name=key_import_service_name,
        recipe=ExecRecipe(
            command=["bash", "-c", "while [ ! -f /home/user/data/import_complete.txt ]; do echo 'Waiting for import to complete...'; sleep 2; done; echo 'Import completed! Found completion marker.'"]
        ),
        description="Wait for key import completion",
    )

    # Store the imported keys from the key import service
    # Note: The beacon node imports to /home/user/data/${NODE}, so we store that specific directory
    imported_keys_artifact = plan.store_service_files(
        service_name=key_import_service_name,
        src="/home/user/data/node" + str(node_index),
        name="nimbus-imported-keys-" + str(node_index) + "-" + str(vc_index),
        description="Nimbus imported validator keys for node " + str(node_index),
    )

    # Step 3: Create the actual validator client service
    # Create the VC run script
    vc_run_script = """#!/usr/bin/env bash

# Find the nimbus_validator_client binary
if [ -f "/home/user/nimbus_validator_client" ]; then
    NIMBUS_VC_PATH="/home/user/nimbus_validator_client"
elif [ -f "/usr/bin/nimbus_validator_client" ]; then
    NIMBUS_VC_PATH="/usr/bin/nimbus_validator_client"
elif [ -f "/usr/local/bin/nimbus_validator_client" ]; then
    NIMBUS_VC_PATH="/usr/local/bin/nimbus_validator_client"
else
    echo "Error: Could not find nimbus_validator_client binary"
    echo "Available files in /home/user:"
    ls -la /home/user/
    exit 1
fi

echo "Using Nimbus VC binary at: $NIMBUS_VC_PATH"
echo "Using imported keys from: /home/user/imported_data"

# List what's available in the imported data
echo "Contents of imported_data:"
ls -la /home/user/imported_data/

# Run nimbus validator client with imported keys
exec "$NIMBUS_VC_PATH" \\
  --data-dir="/home/user/imported_data" \\
  --beacon-node="$BEACON_NODE_ADDRESS" \\
  --doppelganger-detection=false \\
  --metrics \\
  --metrics-address=0.0.0.0 \\
  --metrics-port=""" + str(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM) + """ \\
  --payload-builder=true \\
  --distributed
"""

    # Add extra params if specified
    if hasattr(participant, "vc_extra_params") and len(participant.vc_extra_params) > 0:
        extra_params = " \\\n  " + " \\\n  ".join(participant.vc_extra_params)
        vc_run_script = vc_run_script.replace("--distributed", "--distributed" + extra_params)

    # Create the VC script artifact
    vc_script_artifact = plan.render_templates(
        config={
            "run_vc.sh": struct(
                template=vc_run_script,
                data={},
            ),
        },
        name="nimbus-vc-script-" + str(node_index) + "-" + str(vc_index),
    )

    # Environment variables for VC
    vc_env_vars = {
        "BEACON_NODE_ADDRESS": charon_validator_api_url,
        "NODE": "node" + str(node_index),
    }
    if hasattr(participant, "vc_extra_env_vars") and participant.vc_extra_env_vars:
        vc_env_vars.update(participant.vc_extra_env_vars)

    # Files to mount for VC - imported keys + VC script
    vc_files = {
        "/home/user/imported_data": imported_keys_artifact,
        "/home/user/scripts": vc_script_artifact,
    }

    # Ports configuration
    ports = {
        constants.METRICS_PORT_ID: PortSpec(
            number=vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM,
            transport_protocol="TCP",
            application_protocol="http",
        ),
    }

    # Create the actual validator client service
    plan.print("Creating Nimbus validator client service: " + vc_service_name)
    vc_service = plan.add_service(
        name=vc_service_name,
        config=ServiceConfig(
            image="statusim/nimbus-validator-client:multiarch-latest",
            ports=ports,
            cmd=["chmod +x /home/user/scripts/run_vc.sh && /home/user/scripts/run_vc.sh"],
            entrypoint=["bash", "-c"],
            env_vars=vc_env_vars,
            files=vc_files,
            labels=shared_utils.label_maker(
                client=constants.VC_TYPE.nimbus,
                client_type=constants.CLIENT_TYPES.validator,
                image="statusim/nimbus-validator-client:multiarch-latest"[-constants.MAX_LABEL_LENGTH:],
                connected_client="charon-node-" + str(node_index),
                extra_labels=participant.vc_extra_labels if hasattr(participant, "vc_extra_labels") else {},
                supernode=participant.supernode if hasattr(participant, "supernode") else False,
            ),
            tolerations=tolerations,
            node_selectors=node_selectors,
            user=User(uid=0, gid=0),
        ),
    )

    return vc_service

def new_charon_launcher(el_cl_genesis_data, jwt_file):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
    )
