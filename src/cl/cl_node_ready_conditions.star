def get_ready_conditions(port_id):
    recipe = GetHttpRequestRecipe(endpoint="/eth/v1/node/health", port_id=port_id)

    ready_conditions = ReadyCondition(
        recipe=recipe,
        field="code",
        assertion="IN",
        target_value=[200, 206],
        timeout="15m",
    )

    return ready_conditions
