def new_remote_signer_context(
    http_url,
    client_name,
    service_name,
    metrics_info,
):
    return struct(
        http_url=http_url,
        client_name=client_name,
        service_name=service_name,
        metrics_info=metrics_info,
    )
