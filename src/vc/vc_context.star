def new_vc_context(
    service_name,
    client_name,
    metrics_info,
):
    return struct(
        service_name=service_name,
        client_name=client_name,
        metrics_info=metrics_info,
    )
