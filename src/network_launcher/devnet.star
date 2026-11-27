shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
static_files = import_module("../static_files/static_files.star")
el_cl_genesis_data = import_module(
    "../prelaunch_data_generator/el_cl_genesis/el_cl_genesis_data.star"
)


def launch(plan, network, repo, global_tolerations=[], global_node_selectors={}):
    # We are running a devnet
    url = shared_utils.calculate_devnet_url(network, repo)
    if url == None:
        # Name outside the -devnet-N / -{hsf,gsf,ssf}-N convention
        # (e.g. glamsterdam-msf-2): locate it through cartographoor
        return launch_from_cartographoor(
            plan, network, repo, global_tolerations, global_node_selectors
        )
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
        tolerations=shared_utils.get_tolerations(global_tolerations=global_tolerations),
        node_selectors=global_node_selectors,
    )
    genesis_validators_root = read_file(url + "/genesis_validators_root.txt")

    el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
        el_cl_genesis_data_uuid.files_artifacts[0],
        genesis_validators_root,
    )
    final_genesis_timestamp = shared_utils.read_genesis_timestamp_from_config(
        plan, el_cl_genesis_data_uuid.files_artifacts[0]
    )
    network_id = shared_utils.read_genesis_network_id_from_config(
        plan, el_cl_genesis_data_uuid.files_artifacts[0]
    )
    validator_data = None
    return el_cl_data, final_genesis_timestamp, network_id, validator_data


# Looks the devnet up in cartographoor's networks.json and fetches its metadata
# bundle from the listed repository. Kurtosis cannot read HTTP at interpretation
# time, so this runs in a task and genesis_validators_root is a runtime value
# (as for kt- remote enclaves).
def launch_from_cartographoor(
    plan, network, repo, global_tolerations, global_node_selectors
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)
    fetch_script = plan.upload_files(
        src=static_files.FETCH_DEVNET_NETWORK_CONFIGS_SCRIPT_FILEPATH,
        name="fetch-devnet-network-configs-script",
    )
    genesis_artifact = plan.run_sh(
        name="fetch-devnet-network-configs",
        description="Fetching {0} network configs".format(network),
        run="sh /script/fetch_network_configs.sh",
        files={"/script": fetch_script},
        env_vars={
            "NETWORK": network,
            "DEVNET_REPO": repo,
            "CARTOGRAPHOOR_URL": constants.CARTOGRAPHOOR_NETWORKS_URL,
        },
        store=[StoreSpec(src="/network-configs/", name="el_cl_genesis_data")],
        tolerations=tolerations,
        node_selectors=global_node_selectors,
    ).files_artifacts[0]
    genesis_validators_root = plan.run_sh(
        name="read-devnet-genesis-validators-root",
        description="Reading genesis validators root",
        run="cat /network-configs/genesis_validators_root.txt",
        files={constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: genesis_artifact},
        wait=None,
        tolerations=tolerations,
        node_selectors=global_node_selectors,
    ).output

    el_cl_data = el_cl_genesis_data.new_el_cl_genesis_data(
        genesis_artifact,
        genesis_validators_root,
    )
    final_genesis_timestamp = shared_utils.read_genesis_timestamp_from_config(
        plan, genesis_artifact
    )
    network_id = shared_utils.read_genesis_network_id_from_config(
        plan, genesis_artifact
    )
    validator_data = None
    return el_cl_data, final_genesis_timestamp, network_id, validator_data
