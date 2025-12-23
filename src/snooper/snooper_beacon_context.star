def new_snooper_beacon_client_context(ip_addr, beacon_rpc_port_num, dns_name):
    return struct(
        ip_addr=ip_addr,
        beacon_rpc_port_num=beacon_rpc_port_num,
        dns_name=dns_name,
    )
