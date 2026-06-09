shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

OBSERVOOR_SERVICE_NAME = "observoor"

OBSERVOOR_CONFIG_MOUNT_PATH = "/config"
OBSERVOOR_CONFIG_FILENAME = "config.yaml"
OBSERVOOR_HEALTH_PORT = 9090

OBSERVOOR_PORTS = {
    constants.METRICS_PORT_ID: shared_utils.new_port_spec(
        OBSERVOOR_HEALTH_PORT,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
        wait=None,
    ),
}


def launch_observoor(
    plan,
    config_template,
    clickhouse_native_endpoint,
    all_cl_contexts,
    network_params,
    observoor_params,
    global_node_selectors,
    global_tolerations,
    additional_service_index,
):
    if clickhouse_native_endpoint == None:
        fail(
            "observoor requires the engine OTel ClickHouse native endpoint, but it "
            + "was not discovered. Ensure the engine OTel stack is running "
            + "(`kurtosis otel start`) before adding 'observoor' to additional_services."
        )

    beacon_endpoint = all_cl_contexts[0].beacon_http_url

    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)
    node_selectors = global_node_selectors

    template_data = {
        "ClientName": OBSERVOOR_SERVICE_NAME,
        "NetworkName": network_params.network,
        "BeaconEndpoint": beacon_endpoint,
        "ClickHouseNativeEndpoint": clickhouse_native_endpoint,
    }

    config_artifact = plan.render_templates(
        {
            OBSERVOOR_CONFIG_FILENAME: struct(
                template=config_template,
                data=template_data,
            ),
        },
        "observoor-config",
    )

    observoor_config = _get_observoor_config(
        plan,
        observoor_params,
        config_artifact,
        node_selectors,
        tolerations,
    )

    plan.add_service(OBSERVOOR_SERVICE_NAME, observoor_config)


def _get_observoor_config(
    plan,
    observoor_params,
    config_artifact,
    node_selectors,
    tolerations,
):
    # observoor's eBPF tracer requires tracefs at /sys/kernel/debug/tracing.
    # Kurtosis does not allow bind-mounting host kernel paths, but a privileged
    # container can mount debugfs itself before launching the agent.
    observoor_cmd = (
        "mount -t debugfs none /sys/kernel/debug 2>/dev/null || true; "
        + "exec observoor --config {0}/{1}".format(
            OBSERVOOR_CONFIG_MOUNT_PATH, OBSERVOOR_CONFIG_FILENAME
        )
    )

    config_args = {
        "image": observoor_params.image,
        "ports": OBSERVOOR_PORTS,
        "files": {
            OBSERVOOR_CONFIG_MOUNT_PATH: config_artifact,
        },
        "entrypoint": ["sh", "-c"],
        "cmd": [observoor_cmd],
        "privileged": True,
        "host_pid_namespace": True,
        "node_selectors": node_selectors,
        "tolerations": tolerations,
    }
    if observoor_params.min_cpu > 0:
        config_args["min_cpu"] = observoor_params.min_cpu
    if observoor_params.max_cpu > 0:
        config_args["max_cpu"] = observoor_params.max_cpu
    if observoor_params.min_mem > 0:
        config_args["min_memory"] = observoor_params.min_mem
    if observoor_params.max_mem > 0:
        config_args["max_memory"] = observoor_params.max_mem
    return ServiceConfig(**config_args)
