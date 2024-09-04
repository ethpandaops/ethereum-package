IMAGE_NAME = "nethermind/broadcaster:latest"
SERVICE_NAME = "broadcaster"
PORT = 8545

# The min/max CPU/memory that broadcaster can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 2048


def launch_broadcaster(plan, all_el_contexts, global_node_selectors):
    config = get_config(all_el_contexts, global_node_selectors)
    return plan.add_service(SERVICE_NAME, config)


def get_config(
    all_el_contexts,
    node_selectors,
):
    return ServiceConfig(
        image=IMAGE_NAME,
        cmd=[
            "http://{0}:{1}".format(context.ip_addr, context.rpc_port_num)
            for context in all_el_contexts
        ],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
