def new_snooper_el_client_context(ip_addr, engine_rpc_port_num, rpc_port_num):
    return struct(
        ip_addr=ip_addr,
        engine_rpc_port_num=engine_rpc_port_num,
        rpc_port_num=rpc_port_num,
    )
