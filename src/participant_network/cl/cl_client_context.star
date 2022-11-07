# differs from kurtosis-tech/eth2-merge-kurtosis-module in the sense it dosen't have the rest_client
def new_cl_client_context(client_name, enr, ip_addr, http_port_num, cl_nodes_metrics_info):
	return struct(
		client_name = client_name,
		enr = enr,
		ip_addr = ip_addr,
		http_port_num = http_port_num,
		cl_nodes_metrics_info = cl_nodes_metrics_info,
	)
