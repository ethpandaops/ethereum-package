shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")

SERVICE_NAME = "shark-snooper"
IMAGE_NAME = "bbusa/wireshark:latest"

HTTP_PORT_NUMBER = 3000

USED_PORTS = {
    constants.HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 256
MAX_MEMORY = 1024


def launch_shark_snooper(
    plan,
    global_node_selectors,
    global_tolerations,
    port_publisher,
    additional_service_index,
    docker_cache_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        additional_service_index,
        0,
    )

    config = ServiceConfig(
        image=shared_utils.docker_cache_image_calc(
            docker_cache_params,
            IMAGE_NAME,
        ),
        ports=USED_PORTS,
        public_ports=public_ports,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=global_node_selectors,
        tolerations=tolerations,
    )

    plan.add_service(SERVICE_NAME, config)


def start_key_fetcher(plan, all_participants):
    key_sources = []
    for participant in all_participants:
        cl_context = participant.cl_context
        if cl_context == None or cl_context.client_name != "prysm":
            continue
        key_sources.append(cl_context.beacon_service_name)

    if len(key_sources) == 0:
        return

    fetch_cmds = []
    for source in key_sources:
        fetch_cmds.append("wget -q -O - http://{0}:9999/tls-keys.log >> /captures/tls-keys.log.tmp 2>/dev/null || true".format(source))
        fetch_cmds.append("wget -q -O /captures/capture-{0}.pcap http://{0}:9999/capture.pcap 2>/dev/null || true".format(source))

    fetch_all = "; ".join(fetch_cmds)

    plan.exec(
        service_name=SERVICE_NAME,
        recipe=ExecRecipe(
            command=[
                "sh", "-c",
                "nohup sh -c 'while true; do > /captures/tls-keys.log.tmp; {0}; mv /captures/tls-keys.log.tmp /captures/tls-keys.log; mergecap -w /captures/capture.pcap.tmp /captures/capture-*.pcap 2>/dev/null && mv /captures/capture.pcap.tmp /captures/capture.pcap || true; sleep 10; done' > /dev/null 2>&1 &".format(fetch_all),
            ],
        ),
    )
    plan.print("Started capture fetcher for: {0}".format(", ".join(key_sources)))
