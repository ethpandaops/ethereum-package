IMAGE_NAME = "nethermind/broadcaster:latest"
SERVICE_NAME = "broadcaster"
PORT = 8545


def launch_broadcaster(plan, all_el_client_contexts):
    config = get_config(all_el_client_contexts)
    return plan.add_service(SERVICE_NAME, config)


def get_config(all_el_client_contexts):
    return ServiceConfig(
        image=IMAGE_NAME,
        cmd=[
            "http://{0}:{1}".format(context.ip_addr, context.rpc_port_num)
            for context in all_el_client_contexts
        ],
    )
