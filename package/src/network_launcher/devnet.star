shared_utils = import_module("../shared_utils/shared_utils.star")
el_cl_genesis_data = import_module(
    "../prelaunch_data_generator/el_cl_genesis/el_cl_genesis_data.star"
)


def launch(plan, network, prague_time, repo):
    # We are running a devnet
    url = shared_utils.calculate_devnet_url(network, repo)
    el_cl_genesis_uuid = plan.upload_files(
        src=url,
        name="el_cl_genesis",
    )
    el_cl_genesis_data_uuid = plan.run_sh(
        name="move-genesis-data",
        description="Creating network configs",
        run="mkdir -p /network-configs/ && mv /opt/* /network-configs/",
        store=[StoreSpec(src="/network-configs/", name="el_cl_genesis_data")],
        files={"/opt": el_cl_genesis_uuid},
    )
    genesis_validators_root = read_file(url + "/genesis_validators_root.txt")

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
