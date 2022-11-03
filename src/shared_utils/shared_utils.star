def new_template_and_data(template, template_data_json):
	return {"template": template, "template_data_json": template_data_json}


def path_join(*args):
	joined_path = "/".join(args)
	return joined_path.replace("//", "/")


def path_base(path):
	split_path = path.split("/")
	return split_path[-1]


def new_port_spec(number, protocol):
	return struct(number = number, protocol = protocol)
