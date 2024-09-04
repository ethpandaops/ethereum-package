def get_enode_enr_for_node(plan, service_name, port_id):
    recipe = PostHttpRequestRecipe(
        endpoint="",
        body='{"method":"admin_nodeInfo","params":[],"id":1,"jsonrpc":"2.0"}',
        content_type="application/json",
        port_id=port_id,
        extract={
            "enode": """.result.enode | split("?") | .[0]""",
            "enr": ".result.enr",
        },
    )
    response = plan.wait(
        recipe=recipe,
        field="extract.enode",
        assertion="!=",
        target_value="",
        timeout="15m",
        service_name=service_name,
    )
    return (response["extract.enode"], response["extract.enr"])


def get_enode_for_node(plan, service_name, port_id):
    recipe = PostHttpRequestRecipe(
        endpoint="",
        body='{"method":"admin_nodeInfo","params":[],"id":1,"jsonrpc":"2.0"}',
        content_type="application/json",
        port_id=port_id,
        extract={
            "enode": """.result.enode | split("?") | .[0]""",
        },
    )
    response = plan.wait(
        recipe=recipe,
        field="extract.enode",
        assertion="!=",
        target_value="",
        timeout="15m",
        service_name=service_name,
    )
    return response["extract.enode"]
