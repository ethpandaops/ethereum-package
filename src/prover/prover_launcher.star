constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
node_metrics = import_module("../node_metrics_info.star")
prover_context = import_module("./prover_context.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

dummy = import_module("./dummy.star")
prover_shared = import_module("./shared.star")


def get_prover_config(
    participant,
    prover_type,
    image,
    service_name,
    beacon_http_url,
    tolerations,
    node_selectors,
    prover_index,
):
    if prover_type == constants.PROVER_TYPE.dummy:
        config = dummy.get_config(
            participant=participant,
            image=image,
            service_name=service_name,
            beacon_http_url=beacon_http_url,
            tolerations=tolerations,
            node_selectors=node_selectors,
            prover_index=prover_index,
        )
    else:
        fail("Unsupported prover_type: {0}".format(prover_type))

    return config


def get_prover_context(
    plan,
    service_name,
    service,
    client_name,
):
    prover_metrics_port = service.ports[constants.METRICS_PORT_ID]
    prover_metrics_url = "{0}:{1}".format(
        service.name, prover_metrics_port.number
    )
    prover_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, prover_shared.METRICS_PATH, prover_metrics_url
    )

    return prover_context.new_prover_context(
        client_name=client_name,
        service_name=service_name,
        metrics_info=prover_node_metrics_info,
    )
