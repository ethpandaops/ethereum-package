shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "alloy"

# Alloy ports
HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 12345

ALLOY_CONFIG_FILENAME = "config.alloy"
ALLOY_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/etc/alloy"

PPROF_PORT_NUM = 6060

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}


def launch_alloy(
    plan,
    config_template,
    el_contexts,
    cl_contexts,
    pyroscope_url,
    global_node_selectors,
    global_tolerations,
    alloy_params,
    port_publisher,
    index,
):
    """
    Launch Grafana Alloy for continuous pprof profiling.
    Alloy scrapes pprof endpoints from Go clients and pushes to Pyroscope.
    """
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    # Collect pprof targets from Go clients
    pprof_targets = get_pprof_targets(el_contexts, cl_contexts)

    if len(pprof_targets) == 0:
        plan.print("Alloy: No pprof targets found, skipping Alloy deployment")
        return None

    plan.print("Alloy: Configuring pprof scraping for {} targets".format(len(pprof_targets)))
    for target in pprof_targets:
        plan.print("  - {}: {}".format(target["name"], target["address"]))

    config_files_artifact_name = get_alloy_config_artifact(
        plan,
        config_template,
        pprof_targets,
        pyroscope_url,
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
        alloy_params,
        public_ports,
    )

    service = plan.add_service(SERVICE_NAME, config)

    return struct(
        service_name=SERVICE_NAME,
        ip_addr=service.ip_address,
        http_port_num=HTTP_PORT_NUMBER,
        pprof_targets=pprof_targets,
    )


def get_pprof_targets(el_contexts, cl_contexts):
    """Collect pprof endpoint URLs from all Go clients that support it."""
    targets = []

    # Go EL clients with pprof support that need scraping
    # Note: Geth is excluded because it uses native Pyroscope SDK (push mode)
    go_el_clients_needing_scrape = ["erigon"]
    for ctx in el_contexts:
        if ctx.client_name in go_el_clients_needing_scrape:
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
            # Use beacon_service_name for DNS resolution within Kurtosis
            targets.append({
                "name": ctx.beacon_service_name,
                "address": "{}:{}".format(ctx.beacon_service_name, PPROF_PORT_NUM),
                "client_type": "cl",
                "client_name": ctx.client_name,
            })

    return targets


def get_alloy_config_artifact(
    plan,
    config_template,
    pprof_targets,
    pyroscope_url,
):
    # Build targets list for Alloy config using River/Alloy syntax
    # Each target is an object like: {"__address__" = "host:port", "service_name" = "name"}
    targets_river = []
    for target in pprof_targets:
        # River syntax: curly braces with = for assignment
        targets_river.append('{"__address__" = "' + target["address"] + '", "service_name" = "' + target["name"] + '"}')

    # Add trailing comma to each target for River syntax compatibility
    targets_with_commas = [t + "," for t in targets_river]

    template_data = {
        "HTTPPort": HTTP_PORT_NUMBER,
        "PyroscopeURL": pyroscope_url,
        "PProfTargets": "\n    ".join(targets_with_commas),
    }

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )

    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[ALLOY_CONFIG_FILENAME] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "alloy-config"
    )

    return config_files_artifact_name


def get_config(
    config_files_artifact_name,
    node_selectors,
    tolerations,
    alloy_params,
    public_ports,
):
    config_file_path = shared_utils.path_join(
        ALLOY_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        ALLOY_CONFIG_FILENAME,
    )

    return ServiceConfig(
        image=alloy_params.image if alloy_params else "grafana/alloy:latest",
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            ALLOY_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
        },
        cmd=[
            "run",
            config_file_path,
            "--server.http.listen-addr=0.0.0.0:{}".format(HTTP_PORT_NUMBER),
        ],
        min_cpu=alloy_params.min_cpu if alloy_params else 100,
        max_cpu=alloy_params.max_cpu if alloy_params else 1000,
        min_memory=alloy_params.min_mem if alloy_params else 128,
        max_memory=alloy_params.max_mem if alloy_params else 512,
        node_selectors=node_selectors,
        tolerations=tolerations,
    )
