# differs from kurtosis-tech/eth2-merge-kurtosis-module in the sense it dosen't have the rest_client
# broader use of the rest client allows for waiting for the first cl context to be heahty in module.go
# TODO remove the above comment when things are working
def new_cl_client_context(client_name, enr, ip_addr, http_port_num, cl_nodes_metrics_info):
	return struct(
		client_name = client_name,
		enr = enr,
		ip_addr = ip_addr,
		http_port_num = http_port_num,
		cl_nodes_metrics_info = cl_nodes_metrics_info,
	)
