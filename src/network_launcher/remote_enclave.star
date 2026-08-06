shared_utils = import_module("../shared_utils/shared_utils.star")
el_cl_genesis_data = import_module(
    "../prelaunch_data_generator/el_cl_genesis/el_cl_genesis_data.star"
)


def parse_remote_enclave_url(network):
    # Accepts forms like:
    #   kt-<host>:<port>
    #   kt-http://<host>:<port>
    #   kt-https://<host>:<port>
    if not network.startswith("kt-"):
        fail("Remote enclave network must start with 'kt-', got: {0}".format(network))
    target = network[len("kt-") :]
    if target.startswith("http://") or target.startswith("https://"):
        return target.rstrip("/")
    return "http://{0}".format(target.rstrip("/"))


def launch(plan, network, global_tolerations=[], global_node_selectors={}):
    base_url = parse_remote_enclave_url(network)
    plan.print(
        "[remote_enclave] Syncing genesis bundle from {0}/network-config.tar".format(
            base_url
        )
    )
    remote_tar_artifact = plan.upload_files(
        src="{0}/network-config.tar".format(base_url),
        name="remote-enclave-network-config-tar",
    )
    el_cl_genesis_data_uuid = plan.run_sh(
        name="extract-remote-enclave-genesis",
        description="Extracting network-config.tar from remote enclave",
        run="mkdir -p /network-configs/ && tar -xf /tar/network-config.tar -C /network-configs/ && cat /network-configs/genesis_validators_root.txt",
        files={"/tar": remote_tar_artifact},
        store=[StoreSpec(src="/network-configs/", name="el_cl_genesis_data")],
        tolerations=shared_utils.get_tolerations(global_tolerations=global_tolerations),
        node_selectors=global_node_selectors,
    )
    genesis_validators_root = el_cl_genesis_data_uuid.output

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
