def new_el_client_context(
    client_name,
    enr,
    enode,
    ip_addr,
    rpc_port_num,
    ws_port_num,
    engine_rpc_port_num,
    jwt_secret,
    service_name="",
    el_metrics_info=None,
):
    return struct(
        service_name=service_name,
        client_name=client_name,
        enr=enr,
        enode=enode,
        ip_addr=ip_addr,
        rpc_port_num=rpc_port_num,
        ws_port_num=ws_port_num,
        engine_rpc_port_num=engine_rpc_port_num,
        jwt_secret=jwt_secret,
        el_metrics_info=el_metrics_info,
    )
