TCP_PROTOCOL = "TCP"
UDP_PROTOCOL = "UDP"
HTTP_APPLICATION_PROTOCOL = "http"
NOT_PROVIDED_APPLICATION_PROTOCOL = ""
def new_template_and_data(template, template_data_json):
	return struct(template = template, data = template_data_json)


def path_join(*args):
	joined_path = "/".join(args)
	return joined_path.replace("//", "/")


def path_base(path):
	split_path = path.split("/")
	return split_path[-1]


def path_dir(path):
	split_path = path.split("/")
	if len(split_path) <= 1:
		return "."
	split_path = split_path[:-1]
	return "/".join(split_path) or "/"


def new_port_spec(number, transport_protocol, application_protocol= NOT_PROVIDED_APPLICATION_PROTOCOL):
	return PortSpec(number = number, transport_protocol = transport_protocol, application_protocol=application_protocol)
