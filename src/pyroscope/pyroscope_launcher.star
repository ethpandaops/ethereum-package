shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "pyroscope"

# Pyroscope ports
HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 4040

PYROSCOPE_CONFIG_FILENAME = "pyroscope.yaml"
PYROSCOPE_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/etc/pyroscope"
PYROSCOPE_DATA_DIRPATH = "/data"

# pprof port used by Go clients (for reference)
PPROF_PORT_NUM = 6060

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}


def launch_pyroscope(
    plan,
    config_template,
    el_contexts,
    cl_contexts,
    global_node_selectors,
    global_tolerations,
    pyroscope_params,
    port_publisher,
    index,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Log available pprof targets for user reference
    pprof_targets = get_pprof_targets(el_contexts, cl_contexts)
    if len(pprof_targets) > 0:
        plan.print("Pyroscope: pprof endpoints available at:")
        for target in pprof_targets:
            plan.print("  - {}: http://{}/debug/pprof/".format(target["name"], target["address"]))

    config_files_artifact_name = get_pyroscope_config_artifact(
        plan,
        config_template,
    )

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        HTTP_PORT_ID,
        index,
        0,
    )

    config = get_config(
        config_files_artifact_name,
        global_node_selectors,
        tolerations,
        pyroscope_params,
        public_ports,
    )

    service = plan.add_service(SERVICE_NAME, config)

    return struct(
        service_name=SERVICE_NAME,
        ip_addr=service.ip_address,
        http_port_num=HTTP_PORT_NUMBER,
        url="http://{}:{}".format(service.name, HTTP_PORT_NUMBER),
        pprof_targets=pprof_targets,
    )


def get_pprof_targets(el_contexts, cl_contexts):
    """Collect pprof endpoint URLs from all clients that support it."""
    targets = []

    # Go EL clients with pprof support
    go_el_clients = ["geth", "erigon"]
    for ctx in el_contexts:
        if ctx.client_name in go_el_clients:
            targets.append({
                "name": ctx.service_name,
                "address": "{}:{}".format(ctx.dns_name, PPROF_PORT_NUM),
                "client_type": "el",
                "client_name": ctx.client_name,
            })

    # Go CL clients with pprof support (Prysm)
    go_cl_clients = ["prysm"]
    for ctx in cl_contexts:
        if ctx.client_name in go_cl_clients:
            targets.append({
                "name": ctx.beacon_service_name,
                "address": "{}:{}".format(ctx.ip_addr, PPROF_PORT_NUM),
                "client_type": "cl",
                "client_name": ctx.client_name,
            })

    return targets


def get_pyroscope_config_artifact(
    plan,
    config_template,
):
    template_data = {
        "HTTPPort": HTTP_PORT_NUMBER,
    }

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[PYROSCOPE_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "pyroscope-config"
    )

    return config_files_artifact_name


def get_config(
    config_files_artifact_name,
    node_selectors,
    tolerations,
    pyroscope_params,
    public_ports,
):
    config_file_path = shared_utils.path_join(
        PYROSCOPE_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        PYROSCOPE_CONFIG_FILENAME,
    )

    return ServiceConfig(
        image=pyroscope_params.image,
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            PYROSCOPE_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
            PYROSCOPE_DATA_DIRPATH: Directory(
                persistent_key="pyroscope-data",
            ),
        },
        cmd=[
            "-config.file=" + config_file_path,
        ],
        min_cpu=pyroscope_params.min_cpu,
        max_cpu=pyroscope_params.max_cpu,
        min_memory=pyroscope_params.min_mem,
        max_memory=pyroscope_params.max_mem,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )
