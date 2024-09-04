def new_ethereum_metrics_exporter_context(
    pair_name,
    ip_addr,
    metrics_port_num,
    cl_name,
    el_name,
):
    return struct(
        pair_name=pair_name,
        ip_addr=ip_addr,
        metrics_port_num=metrics_port_num,
        cl_name=cl_name,
        el_name=el_name,
    )
