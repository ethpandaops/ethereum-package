def wait_for_healthy(plan, service_name, port_id):
	recipe = GetHttpRequestRecipe(
        endpoint = "/eth/v1/node/health",
        port_id = port_id
    )
	return plan.wait(recipe, "code", "IN", [200, 206, 503], timeout = "15m", service_name = service_name)
