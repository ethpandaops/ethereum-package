constants = import_module("../package_io/constants.star")

TCP_PROTOCOL = "TCP"
UDP_PROTOCOL = "UDP"
HTTP_APPLICATION_PROTOCOL = "http"
NOT_PROVIDED_APPLICATION_PROTOCOL = ""
NOT_PROVIDED_WAIT = "not-provided-wait"


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
        recipe=ExecRecipe(
            command=["/bin/sh", "-c", "cat {} | tr -d '\n'".format(filename)]
        ),
    )
    return output["output"]


def zfill_custom(value, width):
    return ("0" * (width - len(str(value)))) + str(value)


def label_maker(client, client_type, image, connected_client, extra_labels):
    labels = {
        "ethereum-package.client": client,
        "ethereum-package.client-type": client_type,
        "ethereum-package.client-image": image.replace("/", "-").replace(":", "-"),
        "ethereum-package.connected-client": connected_client,
    }
    labels.update(extra_labels)  # Add extra_labels to the labels dictionary
    return labels


def get_devnet_enodes(plan, filename):
    enode_list = plan.run_python(
        files={constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: filename},
        wait=None,
        run="""
with open("/network-configs/network-configs/bootnode.txt") as bootnode_file:
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
        files={constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: filename},
        wait=None,
        run="""
with open("/network-configs/network-configs/bootstrap_nodes.txt") as bootnode_file:
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
        files={constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: filename},
        wait=None,
        packages=["PyYAML"],
        run="""
import yaml
with open("/network-configs/network-configs/config.yaml", "r") as f:
    yaml_data = yaml.safe_load(f)

min_genesis_time = int(yaml_data.get("MIN_GENESIS_TIME", 0))
genesis_delay = int(yaml_data.get("GENESIS_DELAY", 0))
print(min_genesis_time + genesis_delay, end="")
        """,
    )
    return value.output


def read_genesis_network_id_from_config(plan, filename):
    value = plan.run_python(
        files={constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: filename},
        wait=None,
        packages=["PyYAML"],
        run="""
import yaml
with open("/network-configs/network-configs/config.yaml", "r") as f:
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
