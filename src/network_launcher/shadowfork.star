shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")


def shadowfork_prep(
    plan,
    network_params,
    shadowfork_block,
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
            image="linuxserver/yq",
        )
        network_id = chain_id.output
    else:
        network_id = constants.NETWORK_ID[
            base_network
        ]  # overload the network id to match the network name
    latest_block = plan.run_sh(
        name="fetch-latest-block",
        description="Fetching the latest block",
        run="mkdir -p /shadowfork && \
            curl -o /shadowfork/latest_block.json "
        + network_params.network_sync_base_url
        + base_network
        + "/geth/"
        + shadowfork_block
        + "/_snapshot_eth_getBlockByNumber.json",
        store=[StoreSpec(src="/shadowfork", name="latest_blocks")],
    )

    for index, participant in enumerate(participants):
        tolerations = input_parser.get_client_tolerations(
            participant.el_tolerations,
            participant.tolerations,
            global_tolerations,
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
        shadowfork_data = plan.add_service(
            name="shadowfork-{0}".format(el_service_name),
            config=ServiceConfig(
                image="alpine:3.19.1",
                cmd=[
                    "apk add --no-cache curl tar zstd && curl -s -L "
                    + network_params.network_sync_base_url
                    + base_network
                    + "/"
                    + el_type
                    + "/"
                    + shadowfork_block
                    + "/snapshot.tar.zst"
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
