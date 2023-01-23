def wait_for_healthy(plan, service_name, port_id):
	recipe = struct(
        service_name = service_name,
        method= "GET",
        endpoint = "/eth/v1/node/health",
        content_type = "application/json",
        port_id = port_id
    )
	return plan.wait(recipe, "code", "IN", [200, 206, 503])
