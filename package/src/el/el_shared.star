shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")


def get_general_el_public_port_specs(public_ports_for_component):
    discovery_port = public_ports_for_component[0]
    public_port_assignments = {
        constants.TCP_DISCOVERY_PORT_ID: discovery_port,
        constants.UDP_DISCOVERY_PORT_ID: discovery_port,
        constants.ENGINE_RPC_PORT_ID: public_ports_for_component[1],
    }
    public_ports = shared_utils.get_port_specs(public_port_assignments)
    return public_ports, discovery_port
