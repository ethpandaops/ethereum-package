shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "disruptoor"
HTTP_PORT_NUMBER = 7700

DISRUPTOOR_CONFIG_FILENAME = "config.json"
DISRUPTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"
DOCKER_SOCKET_PATH = "/var/run/docker.sock"
DEFAULT_COMPONENTS = ["el", "cl"]
ALL_COMPONENTS = ["el", "cl", "vc"]

COMPONENT_TO_CLIENT_TYPE = {
    "el": constants.CLIENT_TYPES.el,
    "execution": constants.CLIENT_TYPES.el,
    "cl": constants.CLIENT_TYPES.cl,
    "beacon": constants.CLIENT_TYPES.cl,
    "vc": constants.CLIENT_TYPES.validator,
    "validator": constants.CLIENT_TYPES.validator,
}

COMPONENT_TO_PARTITION_SCOPE = {
    "el": "el_p2p",
    "execution": "el_p2p",
    "cl": "cl_p2p",
    "beacon": "cl_p2p",
}

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}


def launch_disruptoor(
    plan,
    disruptoor_params,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    disruptoor_state = get_disruptoor_state(disruptoor_params)

    config_files_artifact_name = None
    if disruptoor_state != {}:
        config_template = json.indent(json.encode(disruptoor_state))
        config_files_artifact_name = plan.render_templates(
            {
                DISRUPTOOR_CONFIG_FILENAME: shared_utils.new_template_and_data(
                    config_template, {}
                ),
            },
            "disruptoor-config",
        )

    config = get_config(
        config_files_artifact_name,
        disruptoor_params,
        global_node_selectors,
        tolerations,
        port_publisher,
        additional_service_index,
    )
    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    disruptoor_params,
    node_selectors,
    tolerations,
    port_publisher,
    additional_service_index,
):
    cmd = [
        "--addr=:{0}".format(HTTP_PORT_NUMBER),
        "--log-level={0}".format(disruptoor_params.log_level),
        "--log-format={0}".format(disruptoor_params.log_format),
    ]

    files = {}
    if config_files_artifact_name != None:
        files[DISRUPTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE] = config_files_artifact_name
        cmd.append(
            "--config={0}/{1}".format(
                DISRUPTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
                DISRUPTOOR_CONFIG_FILENAME,
            )
        )

    for extra_arg in disruptoor_params.extra_args:
        cmd.append(extra_arg)

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    config_args = {
        "image": disruptoor_params.image,
        "cmd": cmd,
        "ports": USED_PORTS,
        "public_ports": public_ports,
        "privileged": True,
        "host_pid_namespace": True,
        "bind_mounts": {
            DOCKER_SOCKET_PATH: DOCKER_SOCKET_PATH,
        },
        "min_cpu": disruptoor_params.min_cpu,
        "max_cpu": disruptoor_params.max_cpu,
        "min_memory": disruptoor_params.min_mem,
        "max_memory": disruptoor_params.max_mem,
        "node_selectors": node_selectors,
        "tolerations": tolerations,
    }

    if files != {}:
        config_args["files"] = files

    return ServiceConfig(**config_args)


def get_disruptoor_state(disruptoor_params):
    has_native_config = disruptoor_params.config != None and disruptoor_params.config != {}
    has_friendly_partitions = disruptoor_params.partitions != None and disruptoor_params.partitions != []
    has_friendly_shaping = disruptoor_params.shaping != None and disruptoor_params.shaping != []

    if has_native_config:
        if has_friendly_partitions or has_friendly_shaping:
            fail(
                "disruptoor_params.config cannot be used together with disruptoor_params.partitions or disruptoor_params.shaping"
            )
        return disruptoor_params.config

    state = {}
    if has_friendly_partitions:
        state["partitions"] = translate_partitions(disruptoor_params.partitions)
    if has_friendly_shaping:
        state["shaping"] = translate_shaping(disruptoor_params.shaping)

    return state


def translate_partitions(partitions):
    if type(partitions) != "list":
        fail("disruptoor_params.partitions must be a list")

    native_partitions = []
    for index, partition in enumerate(partitions):
        field_path = "disruptoor_params.partitions[{0}]".format(index)
        if type(partition) != "dict":
            fail("{0} must be a map".format(field_path))

        if "groups" not in partition:
            fail("{0}.groups is required".format(field_path))
        groups = partition["groups"]
        if type(groups) != "list" or len(groups) < 2:
            fail("{0}.groups must contain at least two groups".format(field_path))

        components = get_components(partition, DEFAULT_COMPONENTS, "{0}.components".format(field_path))

        native_groups = []
        for group_index, group in enumerate(groups):
            group_path = "{0}.groups[{1}]".format(field_path, group_index)
            if type(group) != "dict":
                fail("{0} must be a map".format(group_path))
            if "participants" not in group and "labels" not in group and "selector" not in group:
                fail(
                    "{0} must define participants, labels, or selector".format(group_path)
                )
            native_groups.append(get_selector(group, components, group_path))

        native_partition = {
            "name": partition.get("name", "partition-{0}".format(index + 1)),
            "groups": native_groups,
        }

        if "scope" in partition:
            native_partition["scope"] = normalize_list(
                partition["scope"],
                "{0}.scope".format(field_path),
            )
        else:
            native_partition["scope"] = get_partition_scope(
                components,
                "{0}.components".format(field_path),
            )

        if "symmetric" in partition:
            native_partition["symmetric"] = partition["symmetric"]

        native_partitions.append(native_partition)

    return native_partitions


def translate_shaping(shaping_rules):
    if type(shaping_rules) != "list":
        fail("disruptoor_params.shaping must be a list")

    native_shaping_rules = []
    for index, shaping_rule in enumerate(shaping_rules):
        field_path = "disruptoor_params.shaping[{0}]".format(index)
        if type(shaping_rule) != "dict":
            fail("{0} must be a map".format(field_path))

        if not has_any_key(shaping_rule, ["delay", "loss", "bandwidth"]):
            fail(
                "{0} must define at least one of delay, loss, or bandwidth".format(field_path)
            )
        if "jitter" in shaping_rule and "delay" not in shaping_rule:
            fail("{0}.jitter requires delay to be set".format(field_path))

        components = get_components(shaping_rule, DEFAULT_COMPONENTS, "{0}.components".format(field_path))
        native_rule = {
            "name": shaping_rule.get("name", "shaping-{0}".format(index + 1)),
            "target": get_shaping_target(shaping_rule, components, field_path),
        }

        if "scope" in shaping_rule:
            scope = normalize_list(shaping_rule["scope"], "{0}.scope".format(field_path))
            if "include_control" not in scope:
                fail("{0}.scope must include include_control".format(field_path))
            native_rule["scope"] = scope
        else:
            if shaping_rule.get("include_control", False) != True:
                fail(
                    "{0}.include_control must be true because disruptoor v0 shaping currently requires control traffic acknowledgement".format(field_path)
                )
            native_rule["scope"] = ["include_control"]

        for optional_attr in ["direction", "delay", "jitter", "loss", "bandwidth"]:
            if optional_attr in shaping_rule:
                native_rule[optional_attr] = shaping_rule[optional_attr]

        native_shaping_rules.append(native_rule)

    return native_shaping_rules


def get_shaping_target(shaping_rule, components, field_path):
    if "target" in shaping_rule:
        if has_any_key(shaping_rule, ["participants", "labels", "selector"]):
            fail(
                "{0}.target cannot be combined with participants, labels, or selector".format(field_path)
            )

        target = shaping_rule["target"]
        if type(target) == "dict" and has_any_key(target, ["participants", "components", "labels", "selector"]):
            return get_selector(target, components, "{0}.target".format(field_path))
        return target

    if not has_any_key(shaping_rule, ["participants", "labels", "selector"]):
        fail(
            "{0} must define participants, labels, selector, or target".format(field_path)
        )

    return get_selector(shaping_rule, components, field_path)


def get_selector(config, default_components, field_path):
    if "selector" in config:
        if has_any_key(config, ["participants", "components", "labels"]):
            fail(
                "{0}.selector cannot be combined with participants, components, or labels".format(field_path)
            )
        return config["selector"]

    labels = config.get("labels", {})
    if labels == None:
        labels = {}
    if type(labels) != "dict":
        fail("{0}.labels must be a map".format(field_path))

    selector = {}
    for key, value in labels.items():
        selector[key] = value

    if "participants" in config:
        if "node-index" in selector:
            fail("{0}.labels cannot include node-index when participants is set".format(field_path))
        participants = config["participants"]
        if participants != "all":
            selector["node-index"] = normalize_list(
                participants,
                "{0}.participants".format(field_path),
            )

    components = get_components(config, default_components, "{0}.components".format(field_path))
    client_types = get_client_types(components, "{0}.components".format(field_path))
    if client_types != []:
        if "client-type" in selector:
            fail("{0}.labels cannot include client-type when components is set".format(field_path))
        selector["client-type"] = client_types

    if selector == {}:
        return "all"
    return selector


def get_components(config, default_components, field_path):
    components = config.get("components", default_components)
    if components == None:
        components = default_components

    if components == "all":
        return ALL_COMPONENTS

    components = normalize_list(components, field_path)
    if "all" in components:
        if len(components) != 1:
            fail("{0} cannot mix all with specific components".format(field_path))
        return ALL_COMPONENTS

    return components


def get_client_types(components, field_path):
    client_types = []
    for component in components:
        if component not in COMPONENT_TO_CLIENT_TYPE:
            fail(
                "{0} contains unsupported component '{1}', expected one of el, cl, vc".format(
                    field_path,
                    component,
                )
            )
        if COMPONENT_TO_CLIENT_TYPE[component] not in client_types:
            client_types.append(COMPONENT_TO_CLIENT_TYPE[component])
    return client_types


def get_partition_scope(components, field_path):
    scope = []
    for component in components:
        if component not in COMPONENT_TO_CLIENT_TYPE:
            fail(
                "{0} contains unsupported component '{1}', expected one of el, cl, vc".format(
                    field_path,
                    component,
                )
            )
        if component in COMPONENT_TO_PARTITION_SCOPE and COMPONENT_TO_PARTITION_SCOPE[component] not in scope:
            scope.append(COMPONENT_TO_PARTITION_SCOPE[component])

    if scope == []:
        fail(
            "{0} must include el or cl for partitions, or set scope explicitly".format(field_path)
        )
    return scope


def normalize_list(value, field_path):
    if value == None:
        return []
    if type(value) == "list":
        return value
    return [value]


def has_any_key(config, keys):
    for key in keys:
        if key in config:
            return True
    return False
