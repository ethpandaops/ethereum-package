def new_vc_context(
    client_name,
    service_name,
    metrics_info,
):
    return struct(
        client_name=client_name,
        service_name=service_name,
        metrics_info=metrics_info,
    )
