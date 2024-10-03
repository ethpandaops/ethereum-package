constants = import_module("../package_io/constants.star")

TCP_PROTOCOL = "TCP"
UDP_PROTOCOL = "UDP"
HTTP_APPLICATION_PROTOCOL = "http"
NOT_PROVIDED_APPLICATION_PROTOCOL = ""
NOT_PROVIDED_WAIT = "not-provided-wait"

MAX_PORTS_PER_CL_NODE = 5
MAX_PORTS_PER_EL_NODE = 5
MAX_PORTS_PER_VC_NODE = 3
MAX_PORTS_PER_ADDITIONAL_SERVICE = 2


def new_template_and_data(template, template_data_json):
    return struct(template=template, data=template_data_json)


def path_join(*args):
    joined_path = "/".join(args)
    return joined_path.replace("//", "/")


def path_base(path):
    split_path = path.split("/")
    return split_path[-1]


def path_dir(path):
    split_path = path.split("/")
    if len(split_path) <= 1:
        return "."
    split_path = split_path[:-1]
    return "/".join(split_path) or "/"


def new_port_spec(
    number,
    transport_protocol,
    application_protocol=NOT_PROVIDED_APPLICATION_PROTOCOL,
    wait=NOT_PROVIDED_WAIT,
):
    if wait == NOT_PROVIDED_WAIT:
        return PortSpec(
            number=number,
            transport_protocol=transport_protocol,
            application_protocol=application_protocol,
        )

    return PortSpec(
        number=number,
        transport_protocol=transport_protocol,
        application_protocol=application_protocol,
        wait=wait,
    )


def read_file_from_service(plan, service_name, filename):
    output = plan.exec(
        service_name=service_name,
        description="Reading {} from {}".format(filename, service_name),
        recipe=ExecRecipe(
            command=["/bin/sh", "-c", "cat {} | tr -d '\n'".format(filename)]
        ),
    )
    return output["output"]


def zfill_custom(value, width):
    return ("0" * (width - len(str(value)))) + str(value)


def label_maker(client, client_type, image, connected_client, extra_labels):
    # Extract sha256 hash if present
    sha256 = ""
    if "@sha256:" in image:
        sha256 = image.split("@sha256:")[-1][:8]

    # Create the labels dictionary
    labels = {
        "ethereum-package.client": client,
        "ethereum-package.client-type": client_type,
        "ethereum-package.client-image": image.replace("/", "-")
        .replace(":", "_")
        .split("@")[0],  # drop the sha256 part of the image from the label
        "ethereum-package.sha256": sha256,
        "ethereum-package.connected-client": connected_client,
    }

    # Add extra_labels to the labels dictionary
    labels.update(extra_labels)

    return labels


def get_devnet_enodes(plan, filename):
    enode_list = plan.run_python(
        description="Getting devnet enodes",
        files={constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: filename},
        wait=None,
        run="""
with open("/network-configs/enodes.txt") as bootnode_file:
    bootnodes = []
    for line in bootnode_file:
        line = line.strip()
        bootnodes.append(line)
print(",".join(bootnodes), end="")
            """,
    )
    return enode_list.output


def get_devnet_enrs_list(plan, filename):
    enr_list = plan.run_python(
        description="Creating devnet enrs list",
        files={constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: filename},
        wait=None,
        run="""
with open("/network-configs/bootstrap_nodes.txt") as bootnode_file:
    bootnodes = []
    for line in bootnode_file:
        line = line.strip()
        bootnodes.append(line)
print(",".join(bootnodes), end="")
            """,
    )
    return enr_list.output


def read_genesis_timestamp_from_config(plan, filename):
    value = plan.run_python(
        description="Reading genesis timestamp from config",
        files={constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: filename},
        wait=None,
        packages=["PyYAML"],
        run="""
import yaml
with open("/network-configs/config.yaml", "r") as f:
    yaml_data = yaml.safe_load(f)

min_genesis_time = int(yaml_data.get("MIN_GENESIS_TIME", 0))
genesis_delay = int(yaml_data.get("GENESIS_DELAY", 0))
print(min_genesis_time + genesis_delay, end="")
        """,
    )
    return value.output


def read_genesis_network_id_from_config(plan, filename):
    value = plan.run_python(
        description="Reading genesis network id from config",
        files={constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: filename},
        wait=None,
        packages=["PyYAML"],
        run="""
import yaml
with open("/network-configs/config.yaml", "r") as f:
    yaml_data = yaml.safe_load(f)
network_id = int(yaml_data.get("DEPOSIT_NETWORK_ID", 0))
print(network_id, end="")
        """,
    )
    return value.output


def get_network_name(network):
    network_name = network
    if (
        network != constants.NETWORK_NAME.kurtosis
        and network != constants.NETWORK_NAME.ephemery
        and constants.NETWORK_NAME.shadowfork not in network
        and network not in constants.PUBLIC_NETWORKS
    ):
        network_name = "devnets"

    if constants.NETWORK_NAME.shadowfork in network:
        network_name = network.split("-shadowfork")[0]

    return network_name


# this is a python procedure so that Kurtosis can do idempotent runs
# time.now() runs everytime bringing non determinism
# note that the timestamp it returns is a string
def get_final_genesis_timestamp(plan, padding):
    result = plan.run_python(
        description="Getting final genesis timestamp",
        run="""
import time
import sys
padding = int(sys.argv[1])
print(int(time.time()+padding), end="")
""",
        args=[str(padding)],
        store=[StoreSpec(src="/tmp", name="final-genesis-timestamp")],
    )
    return result.output


def calculate_devnet_url(network, repo):
    sf_suffix_mapping = {"hsf": "-hsf-", "gsf": "-gsf-", "ssf": "-ssf-"}
    shadowfork = "sf-" in network

    if shadowfork:
        for suffix, delimiter in sf_suffix_mapping.items():
            if delimiter in network:
                network_parts = network.split(delimiter, 1)
                network_type = suffix
    else:
        network_parts = network.split("-devnet-", 1)
        network_type = "devnet"

    devnet_name, devnet_number = network_parts[0], network_parts[1]
    devnet_category = devnet_name.split("-")[0]
    devnet_subname = (
        devnet_name.split("-")[1] + "-" if len(devnet_name.split("-")) > 1 else ""
    )

    return "github.com/{0}/{1}-devnets/network-configs/{2}{3}-{4}/metadata".format(
        repo, devnet_category, devnet_subname, network_type, devnet_number
    )


def get_client_names(participant, index, participant_contexts, participant_configs):
    index_str = zfill_custom(index + 1, len(str(len(participant_contexts))))
    participant_config = participant_configs[index]
    cl_client = participant.cl_context
    el_client = participant.el_context
    vc_client = participant.vc_context
    full_name = (
        "{0}-{1}-{2}".format(index_str, el_client.client_name, cl_client.client_name)
        + "-{0}".format(vc_client.client_name)
        if vc_client != None and cl_client.client_name != vc_client.client_name
        else "{0}-{1}-{2}".format(
            index_str, el_client.client_name, cl_client.client_name
        )
    )
    return full_name, cl_client, el_client, participant_config


def get_public_ports_for_component(
    component, port_publisher_params, participant_index=None
):
    public_port_range = ()
    if component == "cl":
        public_port_range = __get_port_range(
            port_publisher_params.cl_public_port_start,
            MAX_PORTS_PER_CL_NODE,
            participant_index,
        )
    elif component == "el":
        public_port_range = __get_port_range(
            port_publisher_params.el_public_port_start,
            MAX_PORTS_PER_EL_NODE,
            participant_index,
        )
    elif component == "vc":
        public_port_range = __get_port_range(
            port_publisher_params.vc_public_port_start,
            MAX_PORTS_PER_VC_NODE,
            participant_index,
        )
    elif component == "additional_services":
        public_port_range = __get_port_range(
            port_publisher_params.additional_services_public_port_start,
            MAX_PORTS_PER_ADDITIONAL_SERVICE,
            participant_index,
        )
    return [port for port in range(public_port_range[0], public_port_range[1], 1)]


def __get_port_range(port_start, max_ports_per_component, participant_index):
    if participant_index == 0:
        public_port_start = port_start
        public_port_end = public_port_start + max_ports_per_component
    else:
        public_port_start = port_start + (max_ports_per_component * participant_index)
        public_port_end = public_port_start + max_ports_per_component
    return (public_port_start, public_port_end)


def get_port_specs(port_assignments):
    ports = {}
    for port_id, port in port_assignments.items():
        if port_id in [
            constants.TCP_DISCOVERY_PORT_ID,
            constants.RPC_PORT_ID,
            constants.ENGINE_RPC_PORT_ID,
            constants.ENGINE_WS_PORT_ID,
            constants.WS_RPC_PORT_ID,
            constants.LITTLE_BIGTABLE_PORT_ID,
            constants.WS_PORT_ID,
            constants.PROFILING_PORT_ID,
        ]:
            ports.update({port_id: new_port_spec(port, TCP_PROTOCOL)})
        elif port_id == constants.UDP_DISCOVERY_PORT_ID:
            ports.update({port_id: new_port_spec(port, UDP_PROTOCOL)})
        elif port_id in [
            constants.HTTP_PORT_ID,
            constants.METRICS_PORT_ID,
            constants.VALIDATOR_HTTP_PORT_ID,
            constants.ADMIN_PORT_ID,
            constants.VALDIATOR_GRPC_PORT_ID,
        ]:
            ports.update(
                {port_id: new_port_spec(port, TCP_PROTOCOL, HTTP_APPLICATION_PROTOCOL)}
            )
    return ports


def get_additional_service_standard_public_port(
    port_publisher, port_id, additional_service_index, port_index
):
    public_ports = {}
    if port_publisher.additional_services_enabled:
        public_ports_for_component = get_public_ports_for_component(
            "additional_services", port_publisher, additional_service_index
        )
        public_ports = get_port_specs({port_id: public_ports_for_component[port_index]})
    return public_ports


def get_cpu_mem_resource_limits(
    min_cpu, max_cpu, min_mem, max_mem, volume_size, network_name, client_type
):
    min_cpu = int(min_cpu) if int(min_cpu) > 0 else 0
    max_cpu = int(max_cpu) if int(max_cpu) > 0 else 0
    min_mem = int(min_mem) if int(min_mem) > 0 else 0
    max_mem = int(max_mem) if int(max_mem) > 0 else 0
    volume_size = (
        int(volume_size)
        if int(volume_size) > 0
        else constants.VOLUME_SIZE[network_name][client_type + "_volume_size"]
    )
    return min_cpu, max_cpu, min_mem, max_mem, volume_size
