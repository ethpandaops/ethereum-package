# this is a dictionary as this will get serialzed to JSON
def wait(service_id, port_id):
	recipe = struct(
        service_id = service_id,
        method= "GET",
        endpoint = "/eth/v1/node/health",
        content_type = "application/json",
        port_id = port_id
    )
	return wait(recipe, "code", "IN", [200, 206, 503])