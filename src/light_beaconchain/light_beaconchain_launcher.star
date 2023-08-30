shared_utils = import_module("github.com/kurtosis-tech/eth2-package/src/shared_utils/shared_utils.star")


SERVICE_NAME = "light-beaconchain"
IMAGE_NAME = "pk910/light-beaconchain-explorer:latest"

HTTP_PORT_ID     = "http"
HTTP_PORT_NUMBER = 8080

LIGHT_BEACONCHAIN_CONFIG_FILENAME = "light-beaconchain-config.yaml"

LIGHT_BEACONCHAIN_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE = "/validator-ranges"
VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"

CL_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/cl-genesis-data"
CL_CONFIG_ARTIFACT_NAME = "cl-genesis-data"


USED_PORTS = {
	HTTP_PORT_ID:shared_utils.new_port_spec(HTTP_PORT_NUMBER, shared_utils.TCP_PROTOCOL, shared_utils.HTTP_APPLICATION_PROTOCOL)
}


def launch_light_beacon(
		plan,
		config_template,
		cl_client_contexts,
	):

	all_cl_client_info = []
	for index, client in enumerate(cl_client_contexts):
		all_cl_client_info.append(new_cl_client_info(client.ip_addr, client.http_port_num, client.beacon_service_name))

	template_data = new_config_template_data(HTTP_PORT_NUMBER, all_cl_client_info)

	template_and_data = shared_utils.new_template_and_data(config_template, template_data)
	template_and_data_by_rel_dest_filepath = {}
	template_and_data_by_rel_dest_filepath[LIGHT_BEACONCHAIN_CONFIG_FILENAME] = template_and_data

	config_files_artifact_name = plan.render_templates(template_and_data_by_rel_dest_filepath, "light-beaconchain-config")

	config = get_config(config_files_artifact_name)

	plan.add_service(SERVICE_NAME, config)

def get_config(config_files_artifact_name):
	config_file_path = shared_utils.path_join(LIGHT_BEACONCHAIN_CONFIG_MOUNT_DIRPATH_ON_SERVICE, LIGHT_BEACONCHAIN_CONFIG_FILENAME)
	return ServiceConfig(
		image = IMAGE_NAME,
		ports = USED_PORTS,
		files = {
			LIGHT_BEACONCHAIN_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
			VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE: VALIDATOR_RANGES_ARTIFACT_NAME,
			CL_CONFIG_MOUNT_DIRPATH_ON_SERVICE: CL_CONFIG_ARTIFACT_NAME

		},
		cmd = [
			"-config",
			config_file_path
			]
	)


def new_config_template_data(listen_port_num, cl_client_info):
	return {
		"ListenPortNum": listen_port_num,
		"CLClientInfo": cl_client_info,
	}


def new_cl_client_info(ip_addr, port_num, service_name):
	return {
		"IPAddr": ip_addr,
		"PortNum": port_num,
		"Name": service_name
	}
