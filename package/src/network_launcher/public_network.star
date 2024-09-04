shared_utils = import_module("../shared_utils/shared_utils.star")
el_cl_genesis_data = import_module(
    "../prelaunch_data_generator/el_cl_genesis/el_cl_genesis_data.star"
)
constants = import_module("../package_io/constants.star")


def launch(plan, network, prague_time):
    # We are running a public network
    dummy_genesis_data = plan.run_sh(
        name="dummy-genesis-data",
        description="Creating network configs folder",
        run="mkdir /network-configs",
        store=[StoreSpec(src="/network-configs/", name="el_cl_genesis_data")],
    )
    el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
        dummy_genesis_data.files_artifacts[0],
        constants.GENESIS_VALIDATORS_ROOT[network],
        prague_time,
    )
    final_genesis_timestamp = constants.GENESIS_TIME[network]
    network_id = constants.NETWORK_ID[network]
    validator_data = None
    return el_cl_data, final_genesis_timestamp, network_id, validator_data
