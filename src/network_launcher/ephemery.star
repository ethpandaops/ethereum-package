shared_utils = import_module("../shared_utils/shared_utils.star")
el_cl_genesis_data = import_module(
    "../prelaunch_data_generator/el_cl_genesis/el_cl_genesis_data.star"
)


def launch(plan, prague_time):
    el_cl_genesis_data_uuid = plan.run_sh(
        name="fetch_ephemery_genesis_data",
        description="Creating network configs",
        run="mkdir -p /network-configs/ && \
            curl -o latest.tar.gz https://ephemery.dev/latest.tar.gz && \
            tar xvzf latest.tar.gz -C /network-configs && \
            cat /network-configs/genesis_validators_root.txt",
        image="badouralix/curl-jq",
        store=[StoreSpec(src="/network-configs/", name="el_cl_genesis_data")],
    )
    genesis_validators_root = el_cl_genesis_data_uuid.output
    el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
        el_cl_genesis_data_uuid.files_artifacts[0],
        genesis_validators_root,
        prague_time,
    )
    final_genesis_timestamp = shared_utils.read_genesis_timestamp_from_config(
        plan, el_cl_genesis_data_uuid.files_artifacts[0]
    )
    network_id = shared_utils.read_genesis_network_id_from_config(
        plan, el_cl_genesis_data_uuid.files_artifacts[0]
    )
    validator_data = None
    return el_cl_data, final_genesis_timestamp, network_id, validator_data
