def new_el_client_context(client_name, enr, enode, ip_addr, rpc_port_num, ws_port_num, engine_rpc_port_num):
	return struct(
		client_name = client_name,
		enr = enr,
		enode = enode,
		ip_addr = ip_addr,
		rpc_port_num = rpc_port_num,
		ws_port_num = ws_port_num,
		engine_rpc_port_num = engine_rpc_port_num 
	)
