load("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star", "new_port_spec", "new_template_and_data", "path_join")


SERVICE_ID = "forkmon"
IMAGE_NAME = "ralexstokes/ethereum_consensus_monitor:latest"

HTTP_PORT_ID     = "http"
HTTP_PORT_NUMBER = uint16(80)
HTTP_PROTOCOL = "TCP"

FORKMON_CONFIG_FILENAME = "forkmon-config.toml"

FORKMON_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"

USED_PORTS = {
	HTTP_PORT_ID: new_port_spec(HTTP_PORT_NUMBER, HTTP_PROTOCOL)
}


def launch_forkmon(
		config_template,
		cl_client_contexts,
		genesis_unix_timestamp,
		seconds_per_slot,
		slots_per_epoch
	):
	
	all_cl_client_info = []
	for client in cl_client_contexts:
		client_info = new_cl_client_info(client.ip_addr, client.http_port_num)
		all_cl_client_info.append(client_info)

	template_data = new_config_template_data(HTTP_PORT_NUMBER, all_cl_client_info, seconds_per_slot, slots_per_epoch, genesis_unix_timestamp)
	template_data_json = json.encode(template_data)

	template_and_data = new_template_and_data(config_template, template_data_json)
	template_and_data_by_rel_dest_filepath[FORKMON_CONFIG_FILENAME] = template_and_data

	config_files_artifact_uuid = render_templates(template_and_data_by_rel_dest_filepath)

	service_config = get_service_config(config_files_artifact_uuid)

	add_service(SERVICE_ID, service_config)


def get_service_config(config_files_artifact_uuid):
	config_file_path = path_join(FORKMON_CONFIG_MOUNT_DIRPATH_ON_SERVICE, FORKMON_CONFIG_FILENAME)
	return struct(
		container_image_name = IMAGE_NAME,
		used_ports = USED_PORTS,
		files_artifact_mount_dirpaths = {
			config_files_artifact_uuid: FORKMON_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
		}
		cmd_args = ["--config-path", config_file_path]
	)


def new_config_template_data():
	return {
		"ListenPortNum": listen_port_num,
		"CLClientInfo": cl_client_info,
		"SecondsPerSlot": seconds_per_slot,
		"SlotsPerEpoch": slots_per_epoch,
		"GenesisUnixTimestamp": genesis_unix_timestamp,
	}


def new_cl_client_info(ip_addr, port_num):
	return {
		"IPAddr": ip_addr,
		"PortNum": port_num
	}