def wait_for_healthy(service_id, port_id):
	recipe = struct(
        service_id = service_id,
        method= "GET",
        endpoint = "/eth/v1/node/health",
        content_type = "application/json",
        port_id = port_id
    )
	return plan.wait(recipe, "code", "IN", [200, 206, 503])
