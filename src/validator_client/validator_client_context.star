def new_validator_client_context(
    service_name,
    client_name,
    metrics_info,
):
    return struct(
        service_name=service_name,
        client_name=client_name,
        metrics_info=metrics_info,
    )
