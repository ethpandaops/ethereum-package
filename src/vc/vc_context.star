def new_vc_context(
    client_name,
    service_name,
    metrics_info,
    http_url,
):
    return struct(
        client_name=client_name,
        service_name=service_name,
        metrics_info=metrics_info,
        http_url=http_url,
    )
