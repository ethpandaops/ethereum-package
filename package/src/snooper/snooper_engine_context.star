def new_snooper_engine_client_context(ip_addr, engine_rpc_port_num):
    return struct(
        ip_addr=ip_addr,
        engine_rpc_port_num=engine_rpc_port_num,
    )
