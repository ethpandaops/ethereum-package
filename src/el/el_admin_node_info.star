def get_enode_enr_for_node(plan, service_name, port_id):
    recipe = PostHttpRequestRecipe(
        endpoint="",
        body='{"method":"admin_nodeInfo","params":[],"id":1,"jsonrpc":"2.0"}',
        content_type="application/json",
        port_id=port_id,
        extract={
            "enode": """.result.enode | split("?") | .[0]""",
            # `// ""` so clients whose admin_nodeInfo lacks an enr (or returns
            # null before discovery is up) don't fail the extract and wedge the
            # readiness wait until it times out
            "enr": '.result.enr // ""',
        },
    )
    response = plan.wait(
        recipe=recipe,
        field="extract.enode",
        assertion="!=",
        target_value="",
        timeout="30m",
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
        timeout="30m",
        service_name=service_name,
    )
    return response["extract.enode"]
