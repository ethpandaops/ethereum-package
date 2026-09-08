shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")


# The snapshot is streamed straight into tar so nothing but the extracted datadir
# ever touches disk. A single curl cannot survive a dropped connection, and a
# mainnet snapshot is a multi-hour, hundreds-of-GiB stream (erigon: 370 GB), so
# the download resumes by byte offset instead of restarting: curl reports the
# bytes it delivered (%{size_download}, on stderr so the stream stays clean) and
# each retry continues exactly there. curl -C <offset> exits 33 rather than
# restarting from zero if the server ignores the Range header, so a
# non-ranging server fails loudly, not silently. A stream that stalls without
# closing would hang forever (curl only times out the connect); under 1 KB/s for
# 120 s -- zero progress, not a slow link -- curl exits 28 and the loop resumes.
SNAPSHOT_DOWNLOAD_MAX_ATTEMPTS = 500
SNAPSHOT_DOWNLOAD_SCRIPT = r"""
set -e
apk add --no-cache curl tar zstd
BLOCK_HEIGHT=$(cat /shared/block_height.txt)
echo "Using block height: $BLOCK_HEIGHT"
SNAPSHOT_URL="__SNAPSHOT_BASE__/$BLOCK_HEIGHT/snapshot.tar.zst"
TOTAL=$(curl -sfIL "$SNAPSHOT_URL" | tr -d '\r' | awk 'tolower($1)=="content-length:"{n=$2} END{print n}')
[ -n "$TOTAL" ] || { echo "cannot read the snapshot size from $SNAPSHOT_URL"; exit 1; }
echo "snapshot is $TOTAL bytes"
stream() {
  off=0
  n=0
  while [ "$off" -lt "$TOTAL" ]; do
    n=$((n + 1))
    [ "$n" -gt __MAX_ATTEMPTS__ ] && { echo "giving up at byte $off after $n attempts" >&2; return 1; }
    echo "fetching from byte $off (attempt $n)" >&2
    rc=0
    curl -sfL --connect-timeout 20 --speed-limit 1024 --speed-time 120 -C "$off" -w '%{stderr}%{size_download}' "$SNAPSHOT_URL" 2>/tmp/got || rc=$?
    off=$((off + $(cat /tmp/got)))
    case "$rc" in
      0) ;;
      22|33) echo "fatal curl error $rc at byte $off" >&2; return 1 ;;
      *) echo "stream broke (curl $rc) at byte $off, resuming" >&2; sleep 5 ;;
    esac
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
