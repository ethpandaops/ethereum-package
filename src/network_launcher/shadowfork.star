shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")


# The snapshot is streamed straight into tar so nothing but the extracted datadir
# ever touches disk. One stream from R2 through Cloudflare tops out ~95 MB/s, so the
# archive is fetched as parallel ranged GETs and emitted in order (16 workers
# measured 382 MB/s). At most 2 x workers chunks are staged in /tmp. Each chunk is
# retried until it holds exactly its range, so a dropped connection costs one chunk,
# not the stream. --max-filesize refuses a Range answered with 200 and the whole
# body -- what a cold, cache-eligible object on Cloudflare returns -- before a byte
# lands. The emitter's progress counter is renamed into place: a torn read is an
# arithmetic error, which silently exits sh.
SNAPSHOT_DOWNLOAD_MAX_ATTEMPTS = 500
SNAPSHOT_DOWNLOAD_WORKERS = 16
SNAPSHOT_DOWNLOAD_CHUNK_BYTES = 64 * 1024 * 1024
SNAPSHOT_DOWNLOAD_SCRIPT = r"""
set -eu
apk add --no-cache curl tar zstd
BLOCK_HEIGHT=$(cat /shared/block_height.txt)
echo "Using block height: $BLOCK_HEIGHT"
SNAPSHOT_URL="__SNAPSHOT_BASE__/$BLOCK_HEIGHT/snapshot.tar.zst"
TOTAL=$(curl -sfIL "$SNAPSHOT_URL" | tr -d '\r' | awk 'tolower($1)=="content-length:"{n=$2} END{print n}')
[ -n "$TOTAL" ] || { echo "cannot read the snapshot size from $SNAPSHOT_URL"; exit 1; }
P=__WORKERS__; C=__CHUNK__; N=$(( (TOTAL + C - 1) / C ))
echo "snapshot is $TOTAL bytes: $N chunks, $P workers"
T=$(mktemp -d); echo 0 > "$T/emitted"; PIDS=""
trap 'kill $PIDS 2>/dev/null || true; rm -rf "$T"' EXIT INT TERM
fetch() {
  s=$(( $1 * C )); e=$(( s + C - 1 )); [ "$e" -lt "$TOTAL" ] || e=$(( TOTAL - 1 ))
  want=$(( e - s + 1 )); tries=0
  while :; do
    curl -sf --connect-timeout 20 --speed-limit 1024 --speed-time 120 --max-filesize "$want" \
      -r "$s-$e" -o "$T/$1.part" "$SNAPSHOT_URL" || true
    [ "$(wc -c 2>/dev/null < "$T/$1.part" || echo 0)" -eq "$want" ] && { mv "$T/$1.part" "$T/$1"; return; }
    tries=$(( tries + 1 ))
    [ "$tries" -lt __MAX_ATTEMPTS__ ] || { echo "chunk $1 failed $tries times" >&2; touch "$T/failed"; return 1; }
    echo "chunk $1 (byte $s) incomplete, retrying ($tries)" >&2; sleep 5
  done
}
k=0
while [ "$k" -lt "$P" ]; do
  { ( i=$k
    while [ "$i" -lt "$N" ]; do
      while [ $(( i - $(cat "$T/emitted") )) -ge $(( 2 * P )) ]; do sleep 0.1; done
      fetch "$i" || exit 1
      i=$(( i + P ))
    done ) || touch "$T/failed"; } &
  PIDS="$PIDS $!"; k=$(( k + 1 ))
done
stream() {
  i=0
  while [ "$i" -lt "$N" ]; do
    while [ ! -f "$T/$i" ]; do [ ! -f "$T/failed" ] || return 1; sleep 0.05; done
    cat "$T/$i"; rm -f "$T/$i"; i=$(( i + 1 ))
    echo "$i" > "$T/emitted.tmp"; mv "$T/emitted.tmp" "$T/emitted"
  done
}
stream | tar -I zstd -xf - -C "__DATA_DIR__"
touch /tmp/finished
tail -f /dev/null
"""


def shadowfork_prep(
    plan,
    network_params,
    participants,
    global_tolerations,
    global_node_selectors,
):
    base_network = shared_utils.get_network_name(network_params.network)
    # overload the network name to remove the shadowfork suffix
    if constants.NETWORK_NAME.ephemery in base_network:
        ephemery_config = plan.upload_files(
            src="https://ephemery.dev/latest/config.yaml",
            name="ephemery-config",
        )
        chain_id = plan.run_sh(
            name="read-chain-id",
            description="Reading the chain id from ephemery config",
            run="yq .DEPOSIT_CHAIN_ID /ephemery/config.yaml | tr -d '\n'",
            image=constants.DEFAULT_YQ_IMAGE,
            files={"/ephemery": ephemery_config},
            tolerations=shared_utils.get_tolerations(
                global_tolerations=global_tolerations
            ),
            node_selectors=global_node_selectors,
        )
        network_id = chain_id.output
    else:
        network_id = constants.NETWORK_ID[
            base_network
        ]  # overload the network id to match the network name

    # Fetch block data and determine block height
    if network_params.shadowfork_block_height == "latest":
        latest_block = plan.run_sh(
            name="fetch-latest-block-data-sf",
            description="Fetching the latest block data",
            run="mkdir -p /shadowfork && \
            BASE_URL='"
            + network_params.network_sync_base_url
            + base_network
            + '\' && \
            LATEST_BLOCK=$(curl -s "${BASE_URL}/geth/latest") && \
            echo "Latest block number: $LATEST_BLOCK" && \
            echo $LATEST_BLOCK > /shadowfork/block_height.txt && \
            URL="${BASE_URL}/geth/$LATEST_BLOCK/_snapshot_eth_getBlockByNumber.json" && \
            echo "Fetching from URL: $URL" && \
            curl -s -f -o /shadowfork/latest_block.json "$URL" || { echo "Curl failed with exit code $?"; exit 1; } && \
            cat /shadowfork/latest_block.json',
            store=[StoreSpec(src="/shadowfork", name="latest_blocks")],
            tolerations=shared_utils.get_tolerations(
                global_tolerations=global_tolerations
            ),
            node_selectors=global_node_selectors,
        )
    else:
        latest_block = plan.run_sh(
            name="fetch-block-data-sf",
            description="Fetching block data for specific block",
            run="mkdir -p /shadowfork && \
            BLOCK_HEIGHT='"
            + str(network_params.shadowfork_block_height)
            + "' && \
            echo $BLOCK_HEIGHT > /shadowfork/block_height.txt && \
            BASE_URL='"
            + network_params.network_sync_base_url
            + base_network
            + '\' && \
            URL="${BASE_URL}/geth/$BLOCK_HEIGHT/_snapshot_eth_getBlockByNumber.json" && \
            echo "Fetching from URL: $URL" && \
            curl -s -f -o /shadowfork/latest_block.json "$URL" || { echo "Curl failed with exit code $?"; exit 1; } && \
            cat /shadowfork/latest_block.json',
            store=[StoreSpec(src="/shadowfork", name="latest_blocks")],
            tolerations=shared_utils.get_tolerations(
                global_tolerations=global_tolerations
            ),
            node_selectors=global_node_selectors,
        )

    for index, participant in enumerate(participants):
        tolerations = shared_utils.get_tolerations(
            specific_container_tolerations=participant.el_tolerations,
            participant_tolerations=participant.tolerations,
            global_tolerations=global_tolerations,
        )
        node_selectors = input_parser.get_client_node_selectors(
            participant.node_selectors,
            global_node_selectors,
        )

        cl_type = participant.cl_type
        el_type = participant.el_type

        # Zero-pad the index using the calculated zfill value
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        el_service_name = "el-{0}-{1}-{2}".format(index_str, el_type, cl_type)
        plan.add_service(
            name="shadowfork-{0}".format(el_service_name),
            config=ServiceConfig(
                image="alpine:3.19.1",
                cmd=[
                    SNAPSHOT_DOWNLOAD_SCRIPT.replace(
                        "__SNAPSHOT_BASE__",
                        network_params.network_sync_base_url
                        + base_network
                        + "/"
                        + el_type,
                    )
                    .replace("__DATA_DIR__", "/data/" + el_type + "/execution-data")
                    .replace("__MAX_ATTEMPTS__", str(SNAPSHOT_DOWNLOAD_MAX_ATTEMPTS))
                    .replace("__WORKERS__", str(SNAPSHOT_DOWNLOAD_WORKERS))
                    .replace("__CHUNK__", str(SNAPSHOT_DOWNLOAD_CHUNK_BYTES))
                ],
                entrypoint=["/bin/sh", "-c"],
                files={
                    "/data/"
                    + el_type
                    + "/execution-data": Directory(
                        persistent_key="data-{0}".format(el_service_name),
                        size=constants.VOLUME_SIZE[base_network][
                            el_type + "_volume_size"
                        ],
                    ),
                    "/shared": "latest_blocks",
                },
                tolerations=tolerations,
                node_selectors=node_selectors,
            ),
        )
    for index, participant in enumerate(participants):
        cl_type = participant.cl_type
        el_type = participant.el_type

        # Zero-pad the index using the calculated zfill value
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        el_service_name = "el-{0}-{1}-{2}".format(index_str, el_type, cl_type)
        plan.wait(
            service_name="shadowfork-{0}".format(el_service_name),
            recipe=ExecRecipe(command=["cat", "/tmp/finished"]),
            field="code",
            assertion="==",
            target_value=0,
            interval="1s",
            timeout="24h",  # mainnet erigon+reth (370 GB + 815 GB) share one uplink; 6h was not enough
        )
    return latest_block, network_id
