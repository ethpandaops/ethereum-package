def new_xatu_sentry_context(
    ip_addr,
    metrics_port_num,
):
    return struct(
        ip_addr=ip_addr,
        metrics_port_num=metrics_port_num,
    )
