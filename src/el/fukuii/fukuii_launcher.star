shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_context = import_module("../../el/el_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")
node_metrics = import_module("../../node_metrics_info.star")
constants = import_module("../../package_io/constants.star")
el_shared = import_module("../el_shared.star")

# Fukuii (https://github.com/chippr-robotics/fukuii) is a JVM execution client. It has no
# geth-genesis mode: a devnet runs on fukuii's built-in "hive" network (plain Ethereum rules),
# with the chain id, fork schedule, blob schedule and genesis taken from the generated
# genesis.json. A run_sh step translates that file (the same mapping fukuii's hive adapter
# uses) into a fukuii genesis and a list of -D overrides, which the node reads at start.

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

METRICS_PATH = "/metrics"
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/fukuii/execution-data"
FUKUII_CONFIG_DIRPATH_ON_CLIENT_CONTAINER = "/fukuii-config"

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
}

# genesis.json `config` keys -> fukuii `fukuii.blockchains.hive.*` keys. A fork key the
# genesis sets but this table does not know fails the step: a fork fukuii is not told about
# changes its fork id and its rules, and the node would silently split from the devnet.
GENESIS_TO_FUKUII_SCRIPT = """
set -eu
G=/network-configs/genesis.json
OUT=/fukuii-config
mkdir -p "$OUT"
P=fukuii.blockchains.hive

# fukuii reads header quantities as hex; the generator writes some (timestamp) as decimal
# strings. q turns a decimal string or number into 0x-hex and leaves 0x-values alone.
jq 'def tohex: if . == 0 then "0x0" else "0x" + ([recurse(if . >= 16 then (. / 16 | floor) else empty end) | . % 16] | reverse | map("0123456789abcdef"[.:.+1]) | join("")) end;
    def q: if type == "number" then tohex elif type == "string" and . != "" and (startswith("0x") | not) then (tonumber | tohex) else . end;
{
  difficulty: (.difficulty | q), gasLimit: (.gasLimit | q),
  nonce: (.nonce // "0x0000000000000000"), timestamp: ((.timestamp // "0x0") | q),
  coinbase: (.coinbase // "0x0000000000000000000000000000000000000000"),
  mixHash: (.mixHash // .mixhash // "0x0000000000000000000000000000000000000000000000000000000000000000"),
  extraData: (if (.extraData // "") == "" then "0x" else .extraData end), gasUsed: ((.gasUsed // "0x0") | q),
  parentHash: (.parentHash // "0x0000000000000000000000000000000000000000000000000000000000000000"),
  baseFeePerGas: (.baseFeePerGas | q), excessBlobGas: (.excessBlobGas | q), blobGasUsed: (.blobGasUsed | q),
  slotNumber: .slotNumber,
  alloc: ((.alloc // {}) | to_entries | map({key: .key, value: ({balance: (.value.balance // "0"),
    code: .value.code, nonce: .value.nonce, storage: .value.storage} | with_entries(select(.value != null)))}) | from_entries)
} | with_entries(select(.value != null))' "$G" > "$OUT/genesis.json"

KNOWN='chainId homesteadBlock eip150Block eip155Block eip158Block byzantiumBlock constantinopleBlock petersburgBlock istanbulBlock muirGlacierBlock berlinBlock londonBlock arrowGlacierBlock grayGlacierBlock mergeNetsplitBlock terminalTotalDifficulty terminalTotalDifficultyPassed shanghaiTime cancunTime pragueTime osakaTime bpo1Time bpo2Time amsterdamTime depositContractAddress blobSchedule ethash daoForkSupport'
for k in $(jq -r '.config | keys[]' "$G"); do
  case " $KNOWN " in
    *" $k "*) ;;
    *) case "$k" in
         *Block|*Time) echo "fukuii: genesis sets $k, which this launcher does not map" >&2; exit 1 ;;
       esac ;;
  esac
done
# A fork scheduled at or past 2^63 is the generator's "never" (a far-future epoch); fukuii
# reads fork times as signed 64-bit, so leave it unset rather than pass an overflowing value.
get() { jq -r --arg k "$1" '.config[$k] // empty | if type == "number" and . >= 9223372036854775807 then empty else tostring end' "$G"; }
for k in bpo3Time bpo4Time bpo5Time; do
  if [ -n "$(get "$k")" ]; then
    echo "fukuii: genesis schedules $k; fukuii supports bpo1 and bpo2 only" >&2; exit 1
  fi
done
F="$OUT/flags"
: > "$F"
put() { [ -n "$2" ] && echo "-D$P.$1=$2" >> "$F"; return 0; }
CHAIN_ID=$(get chainId)
put chain-id "$CHAIN_ID"
put network-id "$CHAIN_ID"
put custom-genesis-file "$OUT/genesis.json"
put homestead-block-number "$(get homesteadBlock)"
put eip150-block-number "$(get eip150Block)"
put eip155-block-number "$(get eip155Block)"
put eip160-block-number "$(get eip158Block)"
put eip161-block-number "$(get eip158Block)"
put byzantium-block-number "$(get byzantiumBlock)"
put constantinople-block-number "$(get constantinopleBlock)"
put petersburg-block-number "$(get petersburgBlock)"
put istanbul-block-number "$(get istanbulBlock)"
put muir-glacier-block-number "$(get muirGlacierBlock)"
put berlin-block-number "$(get berlinBlock)"
put olympia-block-number "$(get londonBlock)"
put arrow-glacier-block-number "$(get arrowGlacierBlock)"
put gray-glacier-block-number "$(get grayGlacierBlock)"
put merge-netsplit-block-number "$(get mergeNetsplitBlock)"
put terminal-total-difficulty "$(get terminalTotalDifficulty)"
put shanghai-timestamp "$(get shanghaiTime)"
put cancun-timestamp "$(get cancunTime)"
put prague-timestamp "$(get pragueTime)"
put osaka-timestamp "$(get osakaTime)"
put bpo1-timestamp "$(get bpo1Time)"
put bpo2-timestamp "$(get bpo2Time)"
put amsterdam-timestamp "$(get amsterdamTime)"
DEPOSIT=$(get depositContractAddress)
put deposit-contract-address "${DEPOSIT#0x}"
for fork in cancun prague bpo1 bpo2; do
  put "blob-schedule.$fork.target" "$(jq -r --arg f $fork '.config.blobSchedule[$f].target // empty' "$G")"
  put "blob-schedule.$fork.max" "$(jq -r --arg f $fork '.config.blobSchedule[$f].max // empty' "$G")"
  put "blob-schedule.$fork.base-fee-update-fraction" "$(jq -r --arg f $fork '.config.blobSchedule[$f].baseFeeUpdateFraction // empty' "$G")"
done
cat "$F"
"""


def get_used_ports(discovery_port):
    used_ports = {
        constants.RPC_PORT_ID: shared_utils.new_port_spec(
            RPC_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
        constants.ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(
            ENGINE_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL
        ),
        constants.METRICS_PORT_ID: shared_utils.new_port_spec(
            METRICS_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


def get_config(
    plan,
    launcher,
    participant,
    service_name,
    existing_el_clients,
    cl_client_name,
    global_log_level,
    persistent,
    tolerations,
    node_selectors,
    port_publisher,
    participant_index,
    network_params,
    extra_files_artifacts,
    bootnodoor_el_enr=None,
    el_binary_artifact=None,
    otel_otlp_grpc_url=None,
):
    if el_binary_artifact != None:
        fail(
            "fukuii does not support el_binary; set el_image to a fukuii image instead"
        )

    if network_params.network in constants.PUBLIC_NETWORKS:
        fail(
            "fukuii is supported on kurtosis devnets only; for public networks run fukuii with its built-in network configs"
        )

    public_ports = {}
    public_ports_for_component = None
    if port_publisher.el_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "el", port_publisher, participant_index
        )
        public_ports = el_shared.get_general_el_public_port_specs(
            public_ports_for_component
        )
        additional_public_port_assignments = {
            constants.RPC_PORT_ID: public_ports_for_component[3],
        }
        public_ports.update(
            shared_utils.get_port_specs(additional_public_port_assignments)
        )

    discovery_port_tcp, discovery_port_udp = el_shared.get_discovery_ports(
        public_ports_for_component, DISCOVERY_PORT_NUM
    )

    used_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port_tcp,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port_udp,
        constants.ENGINE_RPC_PORT_ID: ENGINE_RPC_PORT_NUM,
        constants.RPC_PORT_ID: RPC_PORT_NUM,
        constants.METRICS_PORT_ID: METRICS_PORT_NUM,
    }
    used_ports = shared_utils.get_port_specs(used_port_assignments)

    log_level = input_parser.get_client_log_level_or_default(
        participant.el_log_level, global_log_level, VERBOSITY_LEVELS
    )

    # Translate the generated genesis.json into fukuii's genesis and -D overrides. The script is
    # rendered to a file and run with sh: run_sh flattens a multi-line `run` onto one line.
    translate_script = plan.render_templates(
        config={
            "genesis-to-fukuii.sh": struct(template=GENESIS_TO_FUKUII_SCRIPT, data={}),
        },
        name="{0}-genesis-to-fukuii".format(service_name),
        description="Rendering the fukuii genesis translator ({0})".format(
            service_name
        ),
    )
    fukuii_config = plan.run_sh(
        name="{0}-genesis-config".format(service_name),
        description="Translating genesis.json for fukuii ({0})".format(service_name),
        image=constants.DEFAULT_YQ_IMAGE,
        files={
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
            "/fukuii-script": translate_script,
        },
        run="sh /fukuii-script/genesis-to-fukuii.sh",
        store=[
            StoreSpec(
                src=FUKUII_CONFIG_DIRPATH_ON_CLIENT_CONTAINER,
                name="{0}-fukuii-config".format(service_name),
            )
        ],
        tolerations=tolerations,
        node_selectors=node_selectors,
    )

    # fukuii dials static peers from <datadir>/static-nodes.json (enodes; discv4).
    bootnode_arg = el_shared.get_bootnode_enode_arg(
        plan,
        launcher,
        network_params.network,
        existing_el_clients,
        None,
        "",
    )
    static_nodes = ""
    if bootnode_arg != None and bootnode_arg != "":
        static_nodes = bootnode_arg

    flags = [
        "-Dfukuii.datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "-Dfukuii.blockchains.network=hive",
        "-Dlogging.logs-level={0}".format(log_level),
        "-Dfukuii.network.rpc.http.enabled=true",
        "-Dfukuii.network.rpc.http.interface=0.0.0.0",
        "-Dfukuii.network.rpc.http.port={0}".format(RPC_PORT_NUM),
        "-Dfukuii.network.rpc.apis=eth,web3,net,debug,txpool,admin",
        "-Dfukuii.network.engine-api.enabled=true",
        "-Dfukuii.network.engine-api.interface=0.0.0.0",
        "-Dfukuii.network.engine-api.port={0}".format(ENGINE_RPC_PORT_NUM),
        "-Dfukuii.network.engine-api.jwt-secret-path="
        + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "-Dfukuii.mining.protocol=engine-api",
        "-Dfukuii.network.server-address.interface=0.0.0.0",
        "-Dfukuii.network.server-address.port={0}".format(discovery_port_tcp),
        "-Dfukuii.network.server-address.advertised-address="
        + constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "-Dfukuii.network.discovery.interface=0.0.0.0",
        "-Dfukuii.network.discovery.port={0}".format(discovery_port_udp),
        "-Dfukuii.network.discovery.host=" + constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "-Dfukuii.network.discovery.discovery-enabled=true",
        "-Dfukuii.metrics.enabled=true",
        "-Dfukuii.metrics.port={0}".format(METRICS_PORT_NUM),
    ]

    if len(participant.el_extra_params) > 0:
        flags.extend([param for param in participant.el_extra_params])

    start_script = " ".join(
        [
            "set -e;",
            "mkdir -p {0};".format(EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER),
            'if [ -n "{0}" ]; then echo "{0}" | tr "," "\\n" | sed "s/.*/\\"&\\"/" | paste -sd, | sed "s/^/[/;s/$/]/" > {1}/static-nodes.json; fi;'.format(
                static_nodes, EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER
            ),
            "exec java -Xmx2g -Xss8M -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError",
            "-XX:+UnlockDiagnosticVMOptions -XX:-ReduceAllocationMerges",
            "$(cat {0}/flags)".format(FUKUII_CONFIG_DIRPATH_ON_CLIENT_CONTAINER),
            " ".join(flags),
            "-jar /app/fukuii/lib/fukuii-assembly.jar hive",
        ]
    )

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
        FUKUII_CONFIG_DIRPATH_ON_CLIENT_CONTAINER: fukuii_config.files_artifacts[0],
    }

    if persistent:
        files[
            EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER
        ] = el_shared.get_persistent_data_directory(
            participant,
            service_name,
            network_params.network,
            constants.EL_TYPE.fukuii,
        )

    processed_mounts = shared_utils.process_extra_mounts(
        plan, participant.el_extra_mounts, extra_files_artifacts
    )
    for mount_path, artifact in processed_mounts.items():
        files[mount_path] = artifact

    config_args = {
        "image": participant.el_image,
        "ports": used_ports,
        "public_ports": public_ports,
        "publish_udp": port_publisher.el_enabled,
        "entrypoint": ["sh", "-c"],
        "cmd": [start_script],
        "files": files,
        "user": User(uid=0, gid=0),
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": shared_utils.with_otel_env_vars(
            participant.el_extra_env_vars,
            otel_otlp_grpc_url,
            service_name,
        ),
        "labels": shared_utils.label_maker(
            client=constants.EL_TYPE.fukuii,
            client_type=constants.CLIENT_TYPES.el,
            image=participant.el_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=cl_client_name,
            extra_labels=participant.el_extra_labels
            | {constants.NODE_INDEX_LABEL_KEY: str(participant_index + 1)},
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    el_shared.apply_resource_limits(config_args, participant)

    return ServiceConfig(**config_args)


# makes request to [service_name] for enode and enr and returns a full el_context
def get_el_context(
    plan,
    service_name,
    service,
    launcher,
):
    enode, enr = el_admin_node_info.get_enode_enr_for_node(
        plan, service_name, constants.RPC_PORT_ID
    )

    metrics_url = "{0}:{1}".format(service.name, METRICS_PORT_NUM)
    fukuii_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    http_url = "http://{0}:{1}".format(service.name, RPC_PORT_NUM)

    return el_context.new_el_context(
        client_name="fukuii",
        enode=enode,
        dns_name=service.name,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        rpc_http_url=http_url,
        enr=enr,
        service_name=service_name,
        el_metrics_info=[fukuii_metrics_info],
        ip_addr=service.ip_address,
    )


def new_fukuii_launcher(el_cl_genesis_data, jwt_file):
    return struct(el_cl_genesis_data=el_cl_genesis_data, jwt_file=jwt_file)
