shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")


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
        chain_id = plan.run_sh(
            name="fetch-chain-id",
            description="Fetching the chain id",
            run="curl -s https://ephemery.dev/latest/config.yaml | yq .DEPOSIT_CHAIN_ID | tr -d '\n'",
            image=constants.DEFAULT_YQ_IMAGE,
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
                    "apk add --no-cache curl tar zstd && "
                    + "BLOCK_HEIGHT=$(cat /shared/block_height.txt) && "
                    + 'echo "Using block height: $BLOCK_HEIGHT" && '
                    + "curl -s -L "
                    + network_params.network_sync_base_url
                    + base_network
                    + "/"
                    + el_type
                    + "/$BLOCK_HEIGHT/snapshot.tar.zst"
                    + " | tar -I zstd -xvf - -C /data/"
                    + el_type
                    + "/execution-data"
                    + " && touch /tmp/finished"
                    + " && tail -f /dev/null"
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
            timeout="6h",  # 6 hours should be enough for the biggest network
        )
    return latest_block, network_id
