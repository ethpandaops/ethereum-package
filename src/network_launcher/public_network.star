shared_utils = import_module("../shared_utils/shared_utils.star")
el_cl_genesis_data = import_module(
    "../prelaunch_data_generator/el_cl_genesis/el_cl_genesis_data.star"
)
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")


def launch(
    plan, participants, network_params, global_tolerations, global_node_selectors
):
    if network_params.force_snapshot_sync:
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
            index_str = shared_utils.zfill_custom(
                index + 1, len(str(len(participants)))
            )

            el_service_name = "el-{0}-{1}-{2}".format(index_str, el_type, cl_type)
            el_data = plan.add_service(
                name="snapshot-{0}".format(el_service_name),
                config=ServiceConfig(
                    image="alpine:3.19.1",
                    cmd=[
                        "apk add --no-cache curl tar zstd && curl -s -L "
                        + network_params.network_sync_base_url
                        + network_params.network
                        + "/"
                        + el_type
                        + "/latest"
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
                            size=constants.VOLUME_SIZE[network_params.network][
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
            index_str = shared_utils.zfill_custom(
                index + 1, len(str(len(participants)))
            )

            el_service_name = "el-{0}-{1}-{2}".format(index_str, el_type, cl_type)
            plan.wait(
                service_name="snapshot-{0}".format(el_service_name),
                recipe=ExecRecipe(command=["cat", "/tmp/finished"]),
                field="code",
                assertion="==",
                target_value=0,
                interval="1s",
                timeout="6h",  # 6 hours should be enough for the biggest network
            )
            plan.remove_service(name="snapshot-{0}".format(el_service_name))

    # We are running a public network
    dummy_genesis_data = plan.run_sh(
        name="dummy-genesis-data",
        description="Creating network configs folder",
        run="mkdir /network-configs",
        store=[StoreSpec(src="/network-configs/", name="el_cl_genesis_data")],
    )
    el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
        dummy_genesis_data.files_artifacts[0],
        constants.GENESIS_VALIDATORS_ROOT[network_params.network],
    )
    final_genesis_timestamp = constants.GENESIS_TIME[network_params.network]
    network_id = constants.NETWORK_ID[network_params.network]
    validator_data = None
    return el_cl_data, final_genesis_timestamp, network_id, validator_data
