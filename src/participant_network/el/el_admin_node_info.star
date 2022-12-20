
def get_enode_enr_for_node(plan, service_id, port_id):
    recipe = struct(
        service_id = service_id,
        method= "POST",
        endpoint = "",
        body = '{"method":"admin_nodeInfo","params":[],"id":1,"jsonrpc":"2.0"}',
        content_type = "application/json",
        port_id = port_id,
        extract = {
            "enode": ".result.enode",
			"enr": ".result.enr",
        }
    )
    response = plan.wait(recipe, "extract.enode", "!=", "")
    return (response["extract.enode"], response["extract.enr"])

def get_enode_for_node(plan, service_id, port_id):
    recipe = struct(
        service_id = service_id,
        method= "POST",
        endpoint = "",
        body = '{"method":"admin_nodeInfo","params":[],"id":1,"jsonrpc":"2.0"}',
        content_type = "application/json",
        port_id = port_id,
        extract = {
            "enode": ".result.enode",
        }
    )
    response = plan.wait(recipe, "extract.enode", "!=", "")
    return response["extract.enode"]
