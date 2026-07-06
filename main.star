input_parser = import_module("./src/package_io/input_parser.star")
constants = import_module("./src/package_io/constants.star")
participant_network = import_module("./src/participant_network.star")
shared_utils = import_module("./src/shared_utils/shared_utils.star")
static_files = import_module("./src/static_files/static_files.star")
genesis_constants = import_module(
    "./src/prelaunch_data_generator/genesis_constants/genesis_constants.star"
)

validator_ranges = import_module(
    "./src/prelaunch_data_generator/validator_keystores/validator_ranges_generator.star"
)

tx_fuzz = import_module("./src/tx_fuzz/tx_fuzz.star")
rakoon = import_module("./src/rakoon/rakoon.star")
forkmon = import_module("./src/forkmon/forkmon_launcher.star")

dora = import_module("./src/dora/dora_launcher.star")
checkpointz = import_module("./src/checkpointz/checkpointz_launcher.star")
dugtrio = import_module("./src/dugtrio/dugtrio_launcher.star")
blutgang = import_module("./src/blutgang/blutgang_launcher.star")
erpc = import_module("./src/erpc/erpc_launcher.star")
blobscan = import_module("./src/blobscan/blobscan_launcher.star")
forky = import_module("./src/forky/forky_launcher.star")
tracoor = import_module("./src/tracoor/tracoor_launcher.star")
nginx = import_module("./src/nginx/nginx_launcher.star")
full_beaconchain_explorer = import_module(
    "./src/full_beaconchain/full_beaconchain_launcher.star"
)
blockscout = import_module("./src/blockscout/blockscout_launcher.star")
prometheus = import_module("./src/prometheus/prometheus_launcher.star")
grafana = import_module("./src/grafana/grafana_launcher.star")
tempo = import_module("./src/tempo/tempo_launcher.star")
commit_boost_mev_boost = import_module(
    "./src/mev/commit-boost/mev_boost/mev_boost_launcher.star"
)
mev_rs_mev_boost = import_module("./src/mev/mev-rs/mev_boost/mev_boost_launcher.star")
mev_rs_mev_relay = import_module("./src/mev/mev-rs/mev_relay/mev_relay_launcher.star")
mev_rs_mev_builder = import_module(
    "./src/mev/mev-rs/mev_builder/mev_builder_launcher.star"
)
flashbots_mev_rbuilder = import_module(
    "./src/mev/flashbots/mev_builder/mev_builder_launcher.star"
)

flashbots_mev_boost = import_module(
    "./src/mev/flashbots/mev_boost/mev_boost_launcher.star"
)
flashbots_mev_relay = import_module(
    "./src/mev/flashbots/mev_relay/mev_relay_launcher.star"
)
helix_relay = import_module("./src/mev/helix/helix_relay_launcher.star")
mock_mev = import_module("./src/mev/flashbots/mock_mev/mock_mev_launcher.star")
buildoor = import_module("./src/mev/buildoor/buildoor_launcher.star")
mev_custom_flood = import_module(
    "./src/mev/flashbots/mev_custom_flood/mev_custom_flood_launcher.star"
)
broadcaster = import_module("./src/broadcaster/broadcaster.star")
mempool_bridge = import_module("./src/mempool_bridge/mempool_bridge_launcher.star")
assertoor = import_module("./src/assertoor/assertoor_launcher.star")
get_prefunded_accounts = import_module(
    "./src/prefunded_accounts/get_prefunded_accounts.star"
)
spamoor = import_module("./src/spamoor/spamoor.star")
disruptoor = import_module("./src/disruptoor/disruptoor_launcher.star")
slashoor = import_module("./src/slashoor/slashoor_launcher.star")
zkboost = import_module("./src/zkboost/zkboost_launcher.star")
trueblocks = import_module("./src/trueblocks/trueblocks_launcher.star")

GRAFANA_USER = "admin"
GRAFANA_PASSWORD = "admin"
GRAFANA_DASHBOARD_PATH_URL = "/d/QdTOwy-nz/eth2-merge-kurtosis-module-dashboard?orgId=1"

FIRST_NODE_FINALIZATION_FACT = "cl-boot-finalization-fact"
HTTP_PORT_ID_FOR_FACT = "http"

MEV_BOOST_SHOULD_CHECK_RELAY = True
PATH_TO_PARSED_BEACON_STATE = "/genesis/output/parsedBeaconState.json"

# Non-default ports so the engine OTel stack does not collide with a host-level
# OTLP collector (4317/4318) or ClickHouse (8123). Must match `kurtosis otel start`.
ENGINE_OTEL_OTLP_GRPC_PORT = 14317
ENGINE_OTEL_OTLP_HTTP_PORT = 14318
ENGINE_OTEL_CLICKHOUSE_HTTP_PORT = 18123
ENGINE_OTEL_DISCOVERY_OUTPUT_FILE = "/tmp/engine-otel-discovery.json"
ENGINE_OTEL_DISCOVERY_ARTIFACT_NAME = "engine-otel-discovery"
ENGINE_OTEL_DISCOVERY_MOUNT_DIR = "/engine-otel-discovery"
ENGINE_OTEL_DISCOVERY_SCRIPT_FILENAME = "engine-otel-discovery.sh"
ENGINE_OTEL_DISCOVERY_SCRIPT_ARTIFACT_NAME = "engine-otel-discovery-script"
ENGINE_OTEL_DISCOVERY_SCRIPT_MOUNT_DIR = "/engine-otel-discovery-script"

ENGINE_OTEL_DISCOVERY_SCRIPT = r"""#!/bin/sh
set -eu

route_line=$(awk "\$2 == \"00000000\" { print \$1 \" \" \$3; exit }" /proc/net/route)
if [ -z "$route_line" ]; then
    echo "default route not found" >&2
    exit 1
fi

iface=$(printf "%s" "$route_line" | awk "{ print \$1 }")
gateway_hex=$(printf "%s" "$route_line" | awk "{ print \$2 }")
if [ -z "$gateway_hex" ]; then
    echo "default gateway not found" >&2
    exit 1
fi

gateway=$(printf "%d.%d.%d.%d" \
    "0x$(printf "%s" "$gateway_hex" | cut -c7-8)" \
    "0x$(printf "%s" "$gateway_hex" | cut -c5-6)" \
    "0x$(printf "%s" "$gateway_hex" | cut -c3-4)" \
    "0x$(printf "%s" "$gateway_hex" | cut -c1-2)")

own_ip=""
if command -v ip >/dev/null 2>&1; then
    own_ip=$(ip -4 -o addr show dev "$iface" scope global | awk "{ split(\$4, a, \"/\"); print a[1]; exit }")
fi
if [ -z "$own_ip" ]; then
    own_ip=$(hostname -i 2>/dev/null | tr " " "\n" | awk "split(\$1, a, \".\") == 4 && a[1] != \"127\" { print; exit }")
fi
if [ -z "$own_ip" ]; then
    echo "probe IPv4 not found" >&2
    exit 1
fi

clickhouse_ping_url="http://${gateway}:{{ .ClickHousePort }}/ping"
if ! curl -fsS "$clickhouse_ping_url" >/dev/null; then
    echo "engine OTel stack is not reachable at ${clickhouse_ping_url}; run 'kurtosis otel start' before adding 'otel' to additional_services" >&2
    exit 1
fi

enclaves_json=$(curl -fsS -XPOST \
    -H "Content-Type: application/json" \
    -d "{}" \
    "http://${gateway}:9710/engine_api.EngineService/GetEnclaves")

cat > /tmp/engine-otel-discovery.jq <<\JQ
def prefix16($ip):
    ($ip | split(".")[0:2] | join("."));

def prefix22($ip):
    ($ip | split(".")) as $octets
    | "\($octets[0]).\($octets[1]).\((($octets[2] | tonumber) / 4 | floor) * 4)";

(.enclaveInfo // {})
| to_entries
| map(.value | select(.apiContainerInfo.ipInsideEnclave != null))
| (
    map(select(prefix22(.apiContainerInfo.ipInsideEnclave) == prefix22($own_ip))) as $matches22
    | if ($matches22 | length) == 1 then
        $matches22[0]
      else
        map(select(prefix16(.apiContainerInfo.ipInsideEnclave) == prefix16($own_ip))) as $matches16
        | if ($matches16 | length) == 1 then
            $matches16[0]
          else
            error("unable to identify enclave for probe IP \($own_ip)")
          end
      end
  )
| {
    gateway: $gateway,
    enclave_uuid: .enclaveUuid,
    enclave_name: .name
  }
JQ

printf "%s" "$enclaves_json" | jq -c \
    --arg gateway "$gateway" \
    --arg own_ip "$own_ip" \
    -f /tmp/engine-otel-discovery.jq > /tmp/engine-otel-discovery.json
cat /tmp/engine-otel-discovery.json
"""


def new_engine_otel_endpoints(gateway=None, enclave_uuid=None, enclave_name=None):
    if gateway == None:
        return struct(
            gateway=None,
            enclave_uuid=None,
            enclave_name=None,
            resource_attributes=None,
            otlp_grpc_url=None,
            otlp_http_traces_url=None,
            clickhouse_host=None,
            clickhouse_port=None,
        )

    return struct(
        gateway=gateway,
        enclave_uuid=enclave_uuid,
        enclave_name=enclave_name,
        resource_attributes="kurtosis.enclave.name={},kurtosis.enclave.uuid={}".format(
            enclave_name,
            enclave_uuid,
        ),
        otlp_grpc_url="http://{}:{}".format(gateway, ENGINE_OTEL_OTLP_GRPC_PORT),
        otlp_http_traces_url="http://{}:{}/v1/traces".format(
            gateway,
            ENGINE_OTEL_OTLP_HTTP_PORT,
        ),
        clickhouse_host=gateway,
        clickhouse_port=ENGINE_OTEL_CLICKHOUSE_HTTP_PORT,
    )


def detect_engine_otel_endpoints(plan, global_tolerations, global_node_selectors):
    script_artifact = plan.render_templates(
        {
            ENGINE_OTEL_DISCOVERY_SCRIPT_FILENAME: shared_utils.new_template_and_data(
                ENGINE_OTEL_DISCOVERY_SCRIPT,
                {"ClickHousePort": ENGINE_OTEL_CLICKHOUSE_HTTP_PORT},
            ),
        },
        name=ENGINE_OTEL_DISCOVERY_SCRIPT_ARTIFACT_NAME,
    )
    result = plan.run_sh(
        name="detect-engine-otel",
        description="Detecting enclave identity and engine OTel endpoints",
        run="/bin/sh {}/{}".format(
            ENGINE_OTEL_DISCOVERY_SCRIPT_MOUNT_DIR,
            ENGINE_OTEL_DISCOVERY_SCRIPT_FILENAME,
        ),
        files={
            ENGINE_OTEL_DISCOVERY_SCRIPT_MOUNT_DIR: script_artifact,
        },
        store=[
            StoreSpec(
                src=ENGINE_OTEL_DISCOVERY_OUTPUT_FILE,
                name=ENGINE_OTEL_DISCOVERY_ARTIFACT_NAME,
            ),
        ],
        tolerations=shared_utils.get_tolerations(global_tolerations=global_tolerations),
        node_selectors=global_node_selectors,
    )
    discovery_artifact = result.files_artifacts[0]
    gateway = read_engine_otel_discovery_field(
        plan,
        discovery_artifact,
        "gateway",
        global_tolerations,
        global_node_selectors,
    )
    enclave_uuid = read_engine_otel_discovery_field(
        plan,
        discovery_artifact,
        "enclave_uuid",
        global_tolerations,
        global_node_selectors,
    )
    enclave_name = read_engine_otel_discovery_field(
        plan,
        discovery_artifact,
        "enclave_name",
        global_tolerations,
        global_node_selectors,
    )
    plan.print(
        "Using engine-level OTel collector via enclave gateway {} for enclave {} ({})".format(
            gateway,
            enclave_name,
            enclave_uuid,
        )
    )
    return new_engine_otel_endpoints(gateway, enclave_uuid, enclave_name)


def read_engine_otel_discovery_field(
    plan,
    discovery_artifact,
    field,
    global_tolerations,
    global_node_selectors,
):
    result = plan.run_sh(
        name="read-engine-otel-{}".format(field.replace("_", "-")),
        description="Reading engine OTel discovery field {}".format(field),
        run='value=$(jq -er ".{}" {}/engine-otel-discovery.json) && printf "%s" "$value"'.format(
            field,
            ENGINE_OTEL_DISCOVERY_MOUNT_DIR,
        ),
        files={
            ENGINE_OTEL_DISCOVERY_MOUNT_DIR: discovery_artifact,
        },
        tolerations=shared_utils.get_tolerations(global_tolerations=global_tolerations),
        node_selectors=global_node_selectors,
    )
    return result.output


def append_otel_resource_attributes(env_vars, resource_attributes):
    existing = env_vars.get("OTEL_RESOURCE_ATTRIBUTES", "")
    if existing == "":
        env_vars["OTEL_RESOURCE_ATTRIBUTES"] = resource_attributes
    elif resource_attributes not in existing:
        env_vars["OTEL_RESOURCE_ATTRIBUTES"] = "{},{}".format(
            existing,
            resource_attributes,
        )


def add_otel_resource_attributes_to_participants(participants, resource_attributes):
    if resource_attributes == None:
        return
    for participant in participants:
        append_otel_resource_attributes(
            participant.el_extra_env_vars,
            resource_attributes,
        )
        append_otel_resource_attributes(
            participant.cl_extra_env_vars,
            resource_attributes,
        )
        append_otel_resource_attributes(
            participant.vc_extra_env_vars,
            resource_attributes,
        )


def run(plan, args={}):
    """Launches an arbitrarily complex ethereum testnet based on the arguments provided

    Args:
        args: A YAML or JSON argument to configure the network; example https://github.com/ethpandaops/ethereum-package/blob/main/network_params.yaml
    """

    args_with_right_defaults = input_parser.input_parser(plan, args)

    num_participants = len(args_with_right_defaults.participants)
    network_params = args_with_right_defaults.network_params

    detected_backend = plan.get_cluster_type()
    otel_enabled = "otel" in args_with_right_defaults.additional_services
    if otel_enabled and detected_backend != "docker":
        fail(
            "The 'otel' additional_service requires the Docker backend because it uses the engine OTel stack published on the Docker host; detected backend: {}. Run with the Docker backend or remove 'otel' from additional_services.".format(
                detected_backend
            )
        )

    if (
        "disruptoor" in args_with_right_defaults.additional_services
        and detected_backend != "docker"
    ):
        fail(
            "disruptoor requires Kurtosis' Docker backend because it uses privileged mode, /var/run/docker.sock, and the host PID namespace; detected: {0}".format(
                detected_backend
            )
        )

    # Process extra_files - create artifacts from provided content
    extra_files_artifacts = {}
    extra_files = getattr(args_with_right_defaults, "extra_files", {})
    if extra_files:
        for name, content in extra_files.items():
            # Use render_templates to create a file with the content
            # The file inside the artifact will be named after the extra_files key
            template_data = {name: struct(template=content, data={})}
            artifact = plan.render_templates(template_data, name + "_artifact")
            extra_files_artifacts[name] = artifact

    for participant in args_with_right_defaults.participants:
        for bin_path in [
            participant.el_binary_path,
            participant.cl_binary_path,
            participant.vc_binary_path,
        ]:
            if bin_path and detected_backend != "docker":
                fail(
                    "Binary injection (*_binary_path) is only supported with Docker backend, detected: {0}".format(
                        detected_backend
                    )
                )

    mev_params = args_with_right_defaults.mev_params
    parallel_keystore_generation = args_with_right_defaults.parallel_keystore_generation
    persistent = args_with_right_defaults.persistent
    xatu_sentry_params = args_with_right_defaults.xatu_sentry_params
    global_tolerations = args_with_right_defaults.global_tolerations
    global_node_selectors = args_with_right_defaults.global_node_selectors
    keymanager_enabled = args_with_right_defaults.keymanager_enabled
    nginx_port = args_with_right_defaults.nginx_port
    docker_cache_params = args_with_right_defaults.docker_cache_params

    engine_otel_endpoints = new_engine_otel_endpoints()
    if otel_enabled:
        engine_otel_endpoints = detect_engine_otel_endpoints(
            plan,
            global_tolerations,
            global_node_selectors,
        )
        add_otel_resource_attributes_to_participants(
            args_with_right_defaults.participants,
            engine_otel_endpoints.resource_attributes,
        )
    otel_clickhouse_host = engine_otel_endpoints.clickhouse_host
    otel_clickhouse_port = engine_otel_endpoints.clickhouse_port
    otel_otlp_grpc_url = engine_otel_endpoints.otlp_grpc_url
    otel_otlp_http_traces_url = engine_otel_endpoints.otlp_http_traces_url

    for index, participant in enumerate(args_with_right_defaults.participants):
        if (
            num_participants == 1
            and participant.cl_type == constants.CL_TYPE.lighthouse
        ):
            if (
                "--target-peers=0" not in participant.cl_extra_params
                and network_params.network == constants.NETWORK_NAME.kurtosis
            ):
                participant.cl_extra_params.append("--target-peers=0")

    prefunded_accounts = genesis_constants.PRE_FUNDED_ACCOUNTS
    if (
        network_params.preregistered_validator_keys_mnemonic
        != constants.DEFAULT_MNEMONIC
    ):
        prefunded_accounts = get_prefunded_accounts.get_accounts(
            plan,
            network_params.preregistered_validator_keys_mnemonic,
            21,
            global_tolerations,
            global_node_selectors,
        )

    grafana_datasource_config_template = read_file(
        static_files.GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILEPATH
    )
    grafana_dashboards_config_template = read_file(
        static_files.GRAFANA_DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH
    )
    tempo_config_template = read_file(static_files.TEMPO_CONFIG_TEMPLATE_FILEPATH)
    mempool_bridge_config_template = read_file(
        static_files.MEMPOOL_BRIDGE_CONFIG_TEMPLATE_FILEPATH
    )
    prometheus_additional_metrics_jobs = []
    raw_jwt_secret = read_file(static_files.JWT_PATH_FILEPATH)
    jwt_file = plan.upload_files(
        src=static_files.JWT_PATH_FILEPATH,
        name="jwt_file",
    )
    keymanager_file = plan.upload_files(
        src=static_files.KEYMANAGER_PATH_FILEPATH,
        name="keymanager_file",
    )

    if network_params.perfect_peerdas_enabled:
        plan.print("Uploading peerdas node keys")
        for index, participant in enumerate(args_with_right_defaults.participants[:16]):
            if participant.cl_type == constants.CL_TYPE.lodestar:
                raw_node_key = (
                    static_files.PEERDAS_NODE_KEY_FILEPATH
                    + participant.cl_type
                    + "/node-key-file-{0}/peer-id.json".format(index + 1)
                )
            elif (
                participant.cl_type == constants.CL_TYPE.lighthouse
                or participant.cl_type == constants.CL_TYPE.grandine
            ):
                raw_node_key = (
                    static_files.PEERDAS_NODE_KEY_FILEPATH
                    + participant.cl_type
                    + "/node-key-file-{0}/key".format(index + 1)
                )
            elif participant.cl_type == constants.CL_TYPE.nimbus:
                raw_node_key = (
                    static_files.PEERDAS_NODE_KEY_FILEPATH
                    + participant.cl_type
                    + "/node-key-file-{0}.json".format(index + 1)
                )
            else:
                raw_node_key = (
                    static_files.PEERDAS_NODE_KEY_FILEPATH
                    + participant.cl_type
                    + "/node-key-file-{0}".format(index + 1)
                )
            node_key_file = plan.upload_files(
                src=raw_node_key,
                name="node-key-file-{0}".format(index + 1),
            )
    plan.print("Read the prometheus, grafana templates")

    tempo_otlp_grpc_url = None
    tempo_query_url = None
    if "tempo" in args_with_right_defaults.additional_services:
        tempo_otlp_grpc_url = "http://{}:{}".format(
            tempo.SERVICE_NAME, tempo.OTLP_GRPC_PORT_NUMBER
        )
        tempo_query_url = "http://{}:{}".format(
            tempo.SERVICE_NAME, tempo.HTTP_PORT_NUMBER
        )

    if args_with_right_defaults.mev_type == constants.MEV_RS_MEV_TYPE:
        plan.print("Generating mev-rs builder config file")
        mev_rs_builder_config_file = mev_rs_mev_builder.new_builder_config(
            plan,
            constants.MEV_RS_MEV_TYPE,
            network_params.network,
            constants.VALIDATING_REWARDS_ACCOUNT,
            network_params.preregistered_validator_keys_mnemonic,
            args_with_right_defaults.mev_params.mev_builder_extra_data,
            global_node_selectors,
        )
    elif (
        args_with_right_defaults.mev_type == constants.FLASHBOTS_MEV_TYPE
        or args_with_right_defaults.mev_type == constants.COMMIT_BOOST_MEV_TYPE
        or args_with_right_defaults.mev_type == constants.HELIX_MEV_TYPE
    ):
        plan.print("Generating flashbots builder config file")
        flashbots_builder_config_file = flashbots_mev_rbuilder.new_builder_config(
            plan,
            args_with_right_defaults.mev_type,
            network_params,
            constants.VALIDATING_REWARDS_ACCOUNT,
            network_params.preregistered_validator_keys_mnemonic,
            args_with_right_defaults.mev_params,
            enumerate(args_with_right_defaults.participants),
            global_node_selectors,
        )

    plan.print(
        "Launching participant network with {0} participants and the following network params {1}".format(
            num_participants, network_params
        )
    )
    (
        all_participants,
        final_genesis_timestamp,
        genesis_validators_root,
        el_cl_data_files_artifact_uuid,
        network_id,
        osaka_time,
        shadowfork_block_height,
    ) = participant_network.launch_participant_network(
        plan,
        args_with_right_defaults,
        network_params,
        jwt_file,
        keymanager_file,
        persistent,
        xatu_sentry_params,
        global_tolerations,
        global_node_selectors,
        keymanager_enabled,
        parallel_keystore_generation,
        extra_files_artifacts,
        tempo_otlp_grpc_url,
        otel_otlp_grpc_url,
        otel_otlp_http_traces_url,
        detected_backend,
    )

    for p in all_participants:
        if p.el_context != None:
            plan.print(
                "NODE JSON RPC URI: '{0}:{1}'".format(
                    p.el_context.dns_name,
                    p.el_context.rpc_port_num,
                )
            )
            break

    total_validator_count = 0
    for participant in args_with_right_defaults.participants:
        total_validator_count += participant.validator_count

    if network_params.builder_count > 0:
        plan.print(
            "Builder configuration: {0} builder(s) registered at genesis with 0xB0 credentials".format(
                network_params.builder_count
            )
        )
        plan.print(
            "Builder mnemonic: '{0}', keys derived at indices {1}..{2}".format(
                network_params.preregistered_validator_keys_mnemonic,
                total_validator_count,
                total_validator_count + network_params.builder_count - 1,
            )
        )

    all_el_contexts = []
    all_cl_contexts = []
    all_vc_contexts = []
    all_remote_signer_contexts = []
    all_ethereum_metrics_exporter_contexts = []
    all_xatu_sentry_contexts = []
    for participant in all_participants:
        if participant.el_context != None:
            all_el_contexts.append(participant.el_context)
        all_cl_contexts.append(participant.cl_context)
        all_vc_contexts.append(participant.vc_context)
        all_remote_signer_contexts.append(participant.remote_signer_context)
        all_ethereum_metrics_exporter_contexts.append(
            participant.ethereum_metrics_exporter_context
        )
        all_xatu_sentry_contexts.append(participant.xatu_sentry_context)

    # Generate validator ranges (translation runs in the genesis generator image
    # via the shared merge script baked into it).
    ethereum_genesis_generator_image = shared_utils.docker_cache_image_calc(
        args_with_right_defaults.docker_cache_params,
        args_with_right_defaults.ethereum_genesis_generator_params.image,
    )
    ranges = validator_ranges.generate_validator_ranges(
        plan,
        ethereum_genesis_generator_image,
        all_participants,
        args_with_right_defaults.participants,
        el_cl_data_files_artifact_uuid,
        global_tolerations,
        global_node_selectors,
    )

    fuzz_target = "http://{0}:{1}".format(
        all_el_contexts[0].ip_addr,
        all_el_contexts[0].rpc_port_num,
    )

    # Broadcaster forwards requests, sent to it, to all nodes in parallel
    if "broadcaster" in args_with_right_defaults.additional_services:
        args_with_right_defaults.additional_services.remove("broadcaster")
        broadcaster_service = broadcaster.launch_broadcaster(
            plan,
            all_el_contexts,
            global_node_selectors,
            global_tolerations,
        )
        fuzz_target = "http://{0}:{1}".format(
            broadcaster_service.name,
            broadcaster.PORT,
        )

    mev_endpoints = []
    mev_endpoint_names = []
    buildoor_api_urls = []
    # passed external relays get priority
    # perhaps add mev_type External or remove this
    if (
        hasattr(participant, "builder_network_params")
        and participant.builder_network_params != None
    ):
        mev_endpoints = participant.builder_network_params.relay_end_points
        for idx, mev_endpoint in enumerate(mev_endpoints):
            mev_endpoint_names.append("relay-{0}".format(idx + 1))
    # otherwise dummy relays spinup if chosen
    elif (
        args_with_right_defaults.mev_type
        and args_with_right_defaults.mev_type == constants.MOCK_MEV_TYPE
    ):
        el_uri = "{0}:{1}".format(
            all_el_contexts[0].dns_name,
            all_el_contexts[0].engine_rpc_port_num,
        )

        # beacon uri for mock mev needs to use ip address and not dns name
        beacon_uri_for_mock_mev = "{0}:{1}".format(
            all_cl_contexts[0].ip_address,
            all_cl_contexts[0].http_port,
        )

        endpoint = mock_mev.launch_mock_mev(
            plan,
            el_uri,
            beacon_uri_for_mock_mev,
            jwt_file,
            args_with_right_defaults.global_log_level,
            global_node_selectors,
            global_tolerations,
            args_with_right_defaults.mev_params,
        )
        mev_endpoints.append(endpoint)
        mev_endpoint_names.append(constants.MOCK_MEV_TYPE)
    elif (
        args_with_right_defaults.mev_type
        and args_with_right_defaults.mev_type == constants.BUILDOOR_MEV_TYPE
    ):
        beacon_uri = "http://{0}:{1}".format(
            all_cl_contexts[0].beacon_service_name,
            all_cl_contexts[0].http_port,
        )
        el_rpc_uri = "http://{0}:{1}".format(
            all_el_contexts[0].dns_name,
            all_el_contexts[0].rpc_port_num,
        )
        engine_rpc_uri = "http://{0}:{1}".format(
            all_el_contexts[0].dns_name,
            all_el_contexts[0].engine_rpc_port_num,
        )
        buildoor_endpoints = buildoor.launch_buildoor(
            plan,
            beacon_uri,
            el_rpc_uri,
            engine_rpc_uri,
            jwt_file,
            prefunded_accounts[0].private_key,
            args_with_right_defaults.buildoor_params,
            global_node_selectors,
            global_tolerations,
            network_params.preregistered_validator_keys_mnemonic,
            total_validator_count,
            ranges,
            constants.BUILDOOR_SERVICE_NAME,
        )
        mev_endpoints.append(buildoor_endpoints["mev_endpoint"])
        mev_endpoint_names.append(constants.BUILDOOR_MEV_TYPE)
        buildoor_api_urls.append(buildoor_endpoints["api_url"])
    elif args_with_right_defaults.mev_type and (
        args_with_right_defaults.mev_type == constants.FLASHBOTS_MEV_TYPE
        or args_with_right_defaults.mev_type == constants.MEV_RS_MEV_TYPE
        or args_with_right_defaults.mev_type == constants.COMMIT_BOOST_MEV_TYPE
        or args_with_right_defaults.mev_type == constants.HELIX_MEV_TYPE
    ):
        builder_cl_context = all_cl_contexts[-1]
        blocksim_uri = "http://{0}:{1}".format(
            all_el_contexts[-1].dns_name, all_el_contexts[-1].rpc_port_num
        )
        beacon_uri = builder_cl_context.beacon_http_url

        first_cl_client = all_cl_contexts[0]
        first_client_beacon_name = first_cl_client.beacon_service_name

        # Check if we should run multiple relays (flashbots + helix)
        if mev_params.run_multiple_relays:
            plan.print("Launching multiple MEV relays (flashbots + helix)")
            # Launch flashbots relay first
            flashbots_endpoint = flashbots_mev_relay.launch_mev_relay(
                plan,
                mev_params,
                network_id,
                beacon_uri,
                genesis_validators_root,
                blocksim_uri,
                network_params,
                persistent,
                args_with_right_defaults.port_publisher,
                num_participants,
                global_node_selectors,
                global_tolerations,
                builder_cl_context.beacon_service_name,
            )
            mev_endpoints.append(flashbots_endpoint)
            mev_endpoint_names.append("flashbots")

            # Launch helix relay second
            helix_endpoint = helix_relay.launch_helix_relay(
                plan,
                network_params,
                mev_params,
                beacon_uri,
                genesis_validators_root,
                final_genesis_timestamp,
                blocksim_uri,
                persistent,
                args_with_right_defaults.port_publisher,
                num_participants + 1,  # Use different index for port allocation
                global_node_selectors,
                global_tolerations,
                el_cl_data_files_artifact_uuid,
                mev_params.helix_relay_image,  # Use the helix-specific image
            )
            mev_endpoints.append(helix_endpoint)
            mev_endpoint_names.append("helix")
        elif (
            args_with_right_defaults.mev_type == constants.FLASHBOTS_MEV_TYPE
            or args_with_right_defaults.mev_type == constants.COMMIT_BOOST_MEV_TYPE
        ):
            endpoint = flashbots_mev_relay.launch_mev_relay(
                plan,
                mev_params,
                network_id,
                beacon_uri,
                genesis_validators_root,
                blocksim_uri,
                network_params,
                persistent,
                args_with_right_defaults.port_publisher,
                num_participants,
                global_node_selectors,
                global_tolerations,
                builder_cl_context.beacon_service_name,
            )
            mev_endpoints.append(endpoint)
            mev_endpoint_names.append(args_with_right_defaults.mev_type)
        elif args_with_right_defaults.mev_type == constants.MEV_RS_MEV_TYPE:
            endpoint, relay_ip_address, relay_port = mev_rs_mev_relay.launch_mev_relay(
                plan,
                mev_params,
                network_params.network,
                beacon_uri,
                el_cl_data_files_artifact_uuid,
                args_with_right_defaults.port_publisher,
                num_participants,
                global_node_selectors,
                global_tolerations,
            )
            mev_endpoints.append(endpoint)
            mev_endpoint_names.append(args_with_right_defaults.mev_type)
        elif args_with_right_defaults.mev_type == constants.HELIX_MEV_TYPE:
            endpoint = helix_relay.launch_helix_relay(
                plan,
                network_params,
                mev_params,
                beacon_uri,
                genesis_validators_root,
                final_genesis_timestamp,
                blocksim_uri,
                persistent,
                args_with_right_defaults.port_publisher,
                num_participants,
                global_node_selectors,
                global_tolerations,
                el_cl_data_files_artifact_uuid,
            )
            mev_endpoints.append(endpoint)
            mev_endpoint_names.append(args_with_right_defaults.mev_type)
        else:
            fail("Invalid MEV type")

    # buildoor is an additional_service: launch the dedicated buildoor instances
    # declared in buildoor_params.instances only when "buildoor" is in
    # additional_services, each wired to the named participant's own CL/EL.
    # Builders are configured independently of the participants. The CL builder
    # endpoint and payload_attributes flags are already set in
    # enrich_buildoor_per_participant. No global mev_type is required. Each builder
    # derives its key from the network's validator mnemonic and onboards itself
    # after genesis via its lifecycle deposit (so gloas need not be at genesis).
    # Remove it from additional_services so the generic dispatch loop below (which
    # fails on unknown services) skips it.
    if constants.BUILDOOR_SERVICE_NAME in args_with_right_defaults.additional_services:
        args_with_right_defaults.additional_services.remove(
            constants.BUILDOOR_SERVICE_NAME
        )
    buildoor_builder_index = 0
    for buildoor_instance in args_with_right_defaults.buildoor_params.instances:
        index = buildoor_instance.participant - 1
        instance_count = buildoor_instance.count
        participant = all_participants[index]
        participant_config = args_with_right_defaults.participants[index]
        index_str = shared_utils.zfill_custom(
            index + 1, len(str(len(all_participants)))
        )
        cl_context = participant.cl_context
        el_context = participant.el_context
        beacon_uri = "http://{0}:{1}".format(
            cl_context.beacon_service_name,
            cl_context.http_port,
        )
        el_rpc_uri = "http://{0}:{1}".format(
            el_context.dns_name,
            el_context.rpc_port_num,
        )
        engine_rpc_uri = "http://{0}:{1}".format(
            el_context.dns_name,
            el_context.engine_rpc_port_num,
        )
        # Each instance uses a distinct prefunded account so concurrent buildoors
        # do not collide on transaction nonces.
        buildoor_account = prefunded_accounts[index % len(prefunded_accounts)]
        for instance in range(instance_count):
            # Name the instance after the participant it is wired to, e.g.
            # buildoor-lighthouse-geth-1, matching the cl/el naming convention.
            buildoor_service_name = shared_utils.get_buildoor_service_name(
                constants.BUILDOOR_SERVICE_NAME,
                participant_config.cl_type,
                participant_config.el_type,
                index_str,
                instance,
                instance_count,
            )
            # Each instance is its own builder with its own builder BLS key,
            # derived by buildoor from the builder mnemonic at consecutive indices
            # after the validators and any genesis-registered builders, so they do
            # not collide. The builder is onboarded after genesis via its lifecycle
            # deposit (buildoor_params.lifecycle), not registered at genesis.
            instance_builder_key_index = (
                total_validator_count
                + network_params.builder_count
                + buildoor_builder_index
            )
            buildoor_builder_index += 1
            buildoor_endpoints = buildoor.launch_buildoor(
                plan,
                beacon_uri,
                el_rpc_uri,
                engine_rpc_uri,
                jwt_file,
                buildoor_account.private_key,
                args_with_right_defaults.buildoor_params,
                global_node_selectors,
                global_tolerations,
                network_params.preregistered_validator_keys_mnemonic,
                instance_builder_key_index,
                ranges,
                buildoor_service_name,
                image=buildoor_instance.image,
            )
            buildoor_api_urls.append(buildoor_endpoints["api_url"])

    # spin up the mev boost contexts if some endpoints for relays have been passed
    all_mevboost_contexts = []
    if mev_endpoints:
        for index, participant in enumerate(all_participants):
            index_str = shared_utils.zfill_custom(
                index + 1, len(str(len(all_participants)))
            )
            plan.print(
                "args_with_right_defaults.participants[index].validator_count {0}".format(
                    args_with_right_defaults.participants[index].validator_count
                )
            )
            # buildoor needs no per-participant mev-boost sidecar: the CLs talk to
            # the shared buildoor service directly (see enrich_mev_extra_params), so
            # the Gloas builder API reaches buildoor instead of dead-ending at
            # mev-boost (which does not implement execution_payload_bid).
            if (
                args_with_right_defaults.participants[index].validator_count != 0
                and args_with_right_defaults.mev_type != constants.BUILDOOR_MEV_TYPE
            ):
                if (
                    args_with_right_defaults.mev_type == constants.FLASHBOTS_MEV_TYPE
                    or args_with_right_defaults.mev_type == constants.MOCK_MEV_TYPE
                    or args_with_right_defaults.mev_type == constants.HELIX_MEV_TYPE
                ):
                    mev_boost_launcher = flashbots_mev_boost.new_mev_boost_launcher(
                        MEV_BOOST_SHOULD_CHECK_RELAY,
                        mev_endpoints,
                    )
                    mev_boost_service_name = "{0}-{1}-{2}-{3}".format(
                        constants.MEV_BOOST_SERVICE_NAME_PREFIX,
                        index_str,
                        participant.cl_type,
                        participant.el_type,
                    )
                    mev_boost_context = flashbots_mev_boost.launch(
                        plan,
                        mev_boost_launcher,
                        mev_boost_service_name,
                        final_genesis_timestamp,
                        mev_params.mev_boost_image,
                        mev_params.mev_boost_args,
                        args_with_right_defaults.participants[index],
                        network_params.seconds_per_slot,
                        args_with_right_defaults.port_publisher,
                        index,
                        global_node_selectors,
                        global_tolerations,
                    )
                elif args_with_right_defaults.mev_type == constants.MEV_RS_MEV_TYPE:
                    plan.print("Launching mev-rs mev boost")
                    mev_boost_launcher = mev_rs_mev_boost.new_mev_boost_launcher(
                        MEV_BOOST_SHOULD_CHECK_RELAY,
                        mev_endpoints,
                    )
                    mev_boost_service_name = "{0}-{1}-{2}-{3}".format(
                        constants.MEV_BOOST_SERVICE_NAME_PREFIX,
                        index_str,
                        participant.cl_type,
                        participant.el_type,
                    )
                    mev_boost_context = mev_rs_mev_boost.launch(
                        plan,
                        mev_boost_launcher,
                        mev_boost_service_name,
                        network_params.network,
                        mev_params,
                        mev_endpoints,
                        el_cl_data_files_artifact_uuid,
                        args_with_right_defaults.port_publisher,
                        index,
                        global_node_selectors,
                        global_tolerations,
                    )
                elif (
                    args_with_right_defaults.mev_type == constants.COMMIT_BOOST_MEV_TYPE
                ):
                    plan.print("Launching commit-boost PBS service")
                    mev_boost_launcher = commit_boost_mev_boost.new_mev_boost_launcher(
                        MEV_BOOST_SHOULD_CHECK_RELAY,
                        mev_endpoints,
                    )
                    mev_boost_service_name = "{0}-{1}-{2}-{3}".format(
                        constants.COMMIT_BOOST_SERVICE_NAME_PREFIX,
                        index_str,
                        participant.cl_type,
                        participant.el_type,
                    )
                    mev_boost_context = commit_boost_mev_boost.launch(
                        plan,
                        mev_boost_launcher,
                        mev_boost_service_name,
                        network_params.network,
                        mev_params,
                        mev_endpoints,
                        el_cl_data_files_artifact_uuid,
                        args_with_right_defaults.port_publisher,
                        index,
                        global_node_selectors,
                        global_tolerations,
                        final_genesis_timestamp,
                    )
                else:
                    fail("Invalid MEV type")
                all_mevboost_contexts.append(mev_boost_context)

    if len(args_with_right_defaults.additional_services) == 0:
        output = struct(
            all_participants=all_participants,
            pre_funded_accounts=prefunded_accounts,
            network_params=network_params,
            network_id=network_id,
            final_genesis_timestamp=final_genesis_timestamp,
            genesis_validators_root=genesis_validators_root,
        )

        return output

    launch_prometheus_grafana = False
    for index, additional_service in enumerate(
        args_with_right_defaults.additional_services
    ):
        if additional_service == "tx_fuzz":
            plan.print("Launching tx-fuzz")
            tx_fuzz_params = args_with_right_defaults.tx_fuzz_params
            tx_fuzz.launch_tx_fuzz(
                plan,
                prefunded_accounts,
                fuzz_target,
                tx_fuzz_params,
                global_node_selectors,
                global_tolerations,
            )
            plan.print("Successfully launched tx-fuzz")
        elif additional_service == "rakoon":
            plan.print("Launching rakoon transaction fuzzer")
            rakoon_params = args_with_right_defaults.rakoon_params
            rakoon.launch_rakoon(
                plan,
                prefunded_accounts,
                fuzz_target,
                rakoon_params,
                network_params.genesis_delay,
                global_node_selectors,
                global_tolerations,
            )
            plan.print("Successfully launched rakoon")
        elif additional_service == "forkmon":
            plan.print("Launching el forkmon")
            forkmon_config_template = read_file(
                static_files.FORKMON_CONFIG_TEMPLATE_FILEPATH
            )
            forkmon.launch_forkmon(
                plan,
                forkmon_config_template,
                all_el_contexts,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched execution layer forkmon")
        elif additional_service == "blockscout":
            plan.print("Launching blockscout")
            blockscout_sc_verif_url = blockscout.launch_blockscout(
                plan,
                all_el_contexts,
                persistent,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
                args_with_right_defaults.blockscout_params,
                network_params,
                shadowfork_block_height,
            )
            plan.print("Successfully launched blockscout")
        elif additional_service == "dora":
            plan.print("Launching dora")
            dora_config_template = read_file(static_files.DORA_CONFIG_TEMPLATE_FILEPATH)
            dora_params = args_with_right_defaults.dora_params
            dora.launch_dora(
                plan,
                dora_config_template,
                all_participants,
                args_with_right_defaults.participants,
                network_params,
                dora_params,
                global_node_selectors,
                global_tolerations,
                mev_endpoints,
                mev_endpoint_names,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
                el_cl_data_files_artifact_uuid,
                buildoor_api_urls,
            )
            plan.print("Successfully launched dora")
        elif additional_service == "checkpointz":
            plan.print("Launching checkpointz")
            checkpointz_config_template = read_file(
                static_files.CHECKPOINTZ_CONFIG_TEMPLATE_FILEPATH
            )
            checkpointz_params = args_with_right_defaults.checkpointz_params
            checkpointz.launch_checkpointz(
                plan,
                checkpointz_config_template,
                all_participants,
                args_with_right_defaults.participants,
                network_params,
                checkpointz_params,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
                el_cl_data_files_artifact_uuid,
            )
            plan.print("Successfully launched checkpointz")
        elif additional_service == "dugtrio":
            plan.print("Launching dugtrio")
            dugtrio_config_template = read_file(
                static_files.DUGTRIO_CONFIG_TEMPLATE_FILEPATH
            )
            dugtrio.launch_dugtrio(
                plan,
                dugtrio_config_template,
                all_participants,
                args_with_right_defaults.participants,
                network_params,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched dugtrio")
        elif additional_service == "blutgang":
            plan.print("Launching blutgang")
            blutgang_config_template = read_file(
                static_files.BLUTGANG_CONFIG_TEMPLATE_FILEPATH
            )
            blutgang.launch_blutgang(
                plan,
                blutgang_config_template,
                all_participants,
                args_with_right_defaults.participants,
                network_params,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched blutgang")
        elif additional_service == "erpc":
            plan.print("Launching erpc")
            erpc_config_template = read_file(static_files.ERPC_CONFIG_TEMPLATE_FILEPATH)
            erpc.launch_erpc(
                plan,
                erpc_config_template,
                all_participants,
                args_with_right_defaults.participants,
                network_params,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched erpc")
        elif additional_service == "blobscan":
            plan.print("Launching blobscan")
            blobscan.launch_blobscan(
                plan,
                all_cl_contexts,
                all_el_contexts,
                network_id,
                network_params,
                persistent,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched blobscan")
        elif additional_service == "forky":
            plan.print("Launching forky")
            forky_config_template = read_file(
                static_files.FORKY_CONFIG_TEMPLATE_FILEPATH
            )
            forky.launch_forky(
                plan,
                forky_config_template,
                all_participants,
                args_with_right_defaults.participants,
                el_cl_data_files_artifact_uuid,
                network_params,
                global_node_selectors,
                global_tolerations,
                final_genesis_timestamp,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched forky")
        elif additional_service == "tracoor":
            plan.print("Launching tracoor")
            tracoor_config_template = read_file(
                static_files.TRACOOR_CONFIG_TEMPLATE_FILEPATH
            )
            tracoor.launch_tracoor(
                plan,
                tracoor_config_template,
                all_participants,
                args_with_right_defaults.participants,
                el_cl_data_files_artifact_uuid,
                network_params,
                global_node_selectors,
                global_tolerations,
                final_genesis_timestamp,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched tracoor")
        elif additional_service == "nginx" or additional_service == "apache":
            plan.print("Launching nginx")
            nginx.launch_nginx(
                plan,
                el_cl_data_files_artifact_uuid,
                nginx_port,
                all_participants,
                args_with_right_defaults.participants,
                args_with_right_defaults.port_publisher,
                index,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched nginx")
        elif additional_service == "full_beaconchain_explorer":
            plan.print("Launching full-beaconchain-explorer")
            full_beaconchain_explorer_config_template = read_file(
                static_files.FULL_BEACONCHAIN_CONFIG_TEMPLATE_FILEPATH
            )
            full_beaconchain_explorer.launch_full_beacon(
                plan,
                full_beaconchain_explorer_config_template,
                el_cl_data_files_artifact_uuid,
                all_cl_contexts,
                all_el_contexts,
                persistent,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
            )
            plan.print("Successfully launched full-beaconchain-explorer")
        elif additional_service == "prometheus":
            plan.print("Launching prometheus...")
            prometheus_private_url = prometheus.launch_prometheus(
                plan,
                all_el_contexts,
                all_cl_contexts,
                all_vc_contexts,
                network_params,
                all_remote_signer_contexts,
                prometheus_additional_metrics_jobs,
                all_ethereum_metrics_exporter_contexts,
                all_xatu_sentry_contexts,
                global_node_selectors,
                args_with_right_defaults.prometheus_params,
                args_with_right_defaults.port_publisher,
                index,
            )
            plan.print("Successfully launched prometheus")
        elif additional_service == "grafana":
            plan.print("Launching grafana...")
            grafana.launch_grafana(
                plan,
                grafana_datasource_config_template,
                grafana_dashboards_config_template,
                prometheus_private_url,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.grafana_params,
                args_with_right_defaults.port_publisher,
                index,
                tempo_query_url,
                otel_clickhouse_host,
                otel_clickhouse_port,
            )
            plan.print("Successfully launched grafana")
        elif additional_service == "tempo":
            plan.print("Launching tempo...")
            tempo.launch_tempo(
                plan,
                tempo_config_template,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.tempo_params,
                args_with_right_defaults.port_publisher,
                index,
            )
            plan.print("Successfully launched tempo")
        elif additional_service == "prometheus_grafana":
            # Allow prometheus to be launched last so is able to collect metrics from other services
            launch_prometheus_grafana = True
            prometheus_grafana_index = index
        elif additional_service == "assertoor":
            plan.print("Launching assertoor")
            assertoor_config_template = read_file(
                static_files.ASSERTOOR_CONFIG_TEMPLATE_FILEPATH
            )
            assertoor_params = args_with_right_defaults.assertoor_params
            assertoor.launch_assertoor(
                plan,
                assertoor_config_template,
                all_participants,
                args_with_right_defaults.participants,
                network_params,
                assertoor_params,
                args_with_right_defaults.port_publisher,
                index,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched assertoor")
        elif additional_service == "custom_flood":
            mev_custom_flood.spam_in_background(
                plan,
                prefunded_accounts[-1].private_key,
                prefunded_accounts[0].address,
                fuzz_target,
                args_with_right_defaults.custom_flood_params,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.docker_cache_params,
            )
        elif additional_service == "mempool_bridge":
            plan.print("Launching mempool-bridge")
            mempool_bridge.launch_mempool_bridge(
                plan,
                mempool_bridge_config_template,
                all_el_contexts,
                args_with_right_defaults.mempool_bridge_params,
                args_with_right_defaults.network_params,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
                args_with_right_defaults.global_log_level,
            )
            plan.print("Successfully launched mempool-bridge")
        elif additional_service == "spamoor":
            plan.print("Launching spamoor")
            spamoor_config_template = read_file(
                static_files.SPAMOOR_CONFIG_TEMPLATE_FILEPATH
            )
            spamoor_hosts_template = read_file(
                static_files.SPAMOOR_HOSTS_TEMPLATE_FILEPATH
            )
            spamoor.launch_spamoor(
                plan,
                spamoor_config_template,
                spamoor_hosts_template,
                prefunded_accounts,
                all_participants,
                args_with_right_defaults.participants,
                args_with_right_defaults.spamoor_params,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.network_params,
                args_with_right_defaults.port_publisher,
                index,
                osaka_time,
            )
            plan.print("Successfully launched spamoor")
        elif additional_service == "disruptoor":
            plan.print("Launching disruptoor")
            disruptoor.launch_disruptoor(
                plan,
                args_with_right_defaults.disruptoor_params,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched disruptoor")
        elif additional_service == "slashoor":
            plan.print("Launching slashoor")
            slashoor_config_template = read_file(
                static_files.SLASHOOR_CONFIG_TEMPLATE_FILEPATH
            )
            slashoor.launch_slashoor(
                plan,
                slashoor_config_template,
                all_participants,
                args_with_right_defaults.participants,
                args_with_right_defaults.slashoor_params,
                global_node_selectors,
                global_tolerations,
                network_params,
                args_with_right_defaults.additional_services,
            )
            plan.print("Successfully launched slashoor")
        elif additional_service == "zkboost":
            plan.print("Launching zkboost")
            zkboost_config_template = read_file(
                static_files.ZKBOOST_CONFIG_TEMPLATE_FILEPATH
            )
            zkboost_metrics_jobs = zkboost.launch_zkboost(
                plan,
                zkboost_config_template,
                all_participants,
                args_with_right_defaults.zkboost_params,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
                network_params,
                tempo_otlp_grpc_url,
            )
            prometheus_additional_metrics_jobs.extend(zkboost_metrics_jobs)
            plan.print("Successfully launched zkboost")
        elif additional_service == "trueblocks":
            plan.print("Launching trueblocks")
            trueblocks_config_template = read_file(
                static_files.TRUEBLOCKS_CONFIG_TEMPLATE_FILEPATH
            )
            trueblocks.launch_trueblocks(
                plan,
                trueblocks_config_template,
                all_el_contexts,
                network_params,
                args_with_right_defaults.trueblocks_params,
                prefunded_accounts,
                global_node_selectors,
                global_tolerations,
                args_with_right_defaults.port_publisher,
                index,
                args_with_right_defaults.docker_cache_params,
            )
            plan.print("Successfully launched trueblocks")
        elif additional_service == "otel":
            # Engine OTel reachability is enforced earlier via detect_engine_otel_endpoints();
            # if discovery succeeded, the per-client OTLP env vars are already wired.
            plan.print("OTel tracing wired to engine collector")
        else:
            fail("Invalid additional service %s" % (additional_service))
    if launch_prometheus_grafana:
        plan.print("Launching prometheus...")
        prometheus_private_url = prometheus.launch_prometheus(
            plan,
            all_el_contexts,
            all_cl_contexts,
            all_vc_contexts,
            network_params,
            all_remote_signer_contexts,
            prometheus_additional_metrics_jobs,
            all_ethereum_metrics_exporter_contexts,
            all_xatu_sentry_contexts,
            global_node_selectors,
            args_with_right_defaults.prometheus_params,
            args_with_right_defaults.port_publisher,
            prometheus_grafana_index,
        )
        plan.print("Launching grafana...")
        grafana.launch_grafana(
            plan,
            grafana_datasource_config_template,
            grafana_dashboards_config_template,
            prometheus_private_url,
            global_node_selectors,
            global_tolerations,
            args_with_right_defaults.grafana_params,
            args_with_right_defaults.port_publisher,
            prometheus_grafana_index,
            tempo_query_url,
            otel_clickhouse_host,
            otel_clickhouse_port,
        )
        plan.print("Successfully launched grafana")

    if args_with_right_defaults.wait_for_finalization:
        plan.print("Waiting for the first finalized epoch")
        first_cl_client = all_cl_contexts[0]
        first_client_beacon_name = first_cl_client.beacon_service_name
        epoch_recipe = GetHttpRequestRecipe(
            endpoint="/eth/v1/beacon/states/head/finality_checkpoints",
            port_id=HTTP_PORT_ID_FOR_FACT,
            extract={"finalized_epoch": ".data.finalized.epoch"},
        )
        plan.wait(
            recipe=epoch_recipe,
            field="extract.finalized_epoch",
            assertion="!=",
            target_value="0",
            timeout="40m",
            service_name=first_client_beacon_name,
        )
        plan.print("First finalized epoch occurred successfully")

    grafana_info = struct(
        dashboard_path=GRAFANA_DASHBOARD_PATH_URL,
        user=GRAFANA_USER,
        password=GRAFANA_PASSWORD,
    )

    output = struct(
        grafana_info=grafana_info,
        blockscout_sc_verif_url=(
            None
            if ("blockscout" in args_with_right_defaults.additional_services) == False
            else blockscout_sc_verif_url
        ),
        all_participants=all_participants,
        pre_funded_accounts=prefunded_accounts,
        network_params=network_params,
        network_id=network_id,
        final_genesis_timestamp=final_genesis_timestamp,
        genesis_validators_root=genesis_validators_root,
    )

    return output
