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
        files={"/data": filename},
        wait=None,
        run="""
with open("/data/bootnode.txt") as bootnode_file:
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
        files={"/data": filename},
        wait=None,
        run="""
with open("/data/bootstrap_nodes.txt") as bootnode_file:
    bootnodes = []
    for line in bootnode_file:
        line = line.strip()
        bootnodes.append(line)
print(",".join(bootnodes), end="")
            """,
    )
    return enr_list.output

# Prysm and Nimbus needs to have the enrs in a list format
# Can't figure out how to pass each item as a list, as I can't return an array from the starlark function
# So for now I'm just returning the last item in the list
def get_devnet_enr(plan, filename):
    enr_items = plan.run_python(
        files={"/data": filename},
        wait=None,
        run="""
with open("/data/bootstrap_nodes.txt") as bootnode_file:
    last_enr = bootnode_file.read().splitlines()[-1]
    print(last_enr, end="")
            """,
    )
    return enr_items.output
