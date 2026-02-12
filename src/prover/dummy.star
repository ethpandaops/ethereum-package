constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
prover_shared = import_module("./shared.star")


def get_config(
    participant,
    image,
    service_name,
    beacon_http_url,
    tolerations,
    node_selectors,
    prover_index,
):
    cmd = [
        "-target-beacon-node=" + beacon_http_url,
    ]

    if len(participant.prover_extra_params) > 0:
        cmd.extend([param for param in participant.prover_extra_params])

    env = {}
    env.update(participant.prover_extra_env_vars)

    ports = {}
    ports.update(prover_shared.PROVER_USED_PORTS)

    config_args = {
        "image": image,
        "ports": ports,
        "entrypoint": ["/dummy-prover"],
        "cmd": cmd,
        "env_vars": env,
        "labels": shared_utils.label_maker(
            client=constants.PROVER_TYPE.dummy,
            client_type=constants.CLIENT_TYPES.prover,
            image=image[-constants.MAX_LABEL_LENGTH:],
            connected_client=participant.cl_type,
            extra_labels=participant.prover_extra_labels
            | {constants.NODE_INDEX_LABEL_KEY: str(prover_index + 1)},
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if participant.prover_min_cpu > 0:
        config_args["min_cpu"] = participant.prover_min_cpu
    if participant.prover_max_cpu > 0:
        config_args["max_cpu"] = participant.prover_max_cpu
    if participant.prover_min_mem > 0:
        config_args["min_memory"] = participant.prover_min_mem
    if participant.prover_max_mem > 0:
        config_args["max_memory"] = participant.prover_max_mem

    return ServiceConfig(**config_args)
