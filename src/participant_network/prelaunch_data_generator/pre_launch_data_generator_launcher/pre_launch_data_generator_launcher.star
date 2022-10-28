IMAGE = "ethpandaops/ethereum-genesis-generator:latest"

SERVICE_ID_PREFIX = "prelaunch-data-generator-"

# We use Docker exec commands to run the commands we need, so we override the default
ENTRYPOINT_ARGS = [
	"sleep",
	"999999",
]

# Launches a prelaunch data generator IMAGE, for use in various of the genesis generation
def launch_prelaunch_data_generator(
	files_artifact_mountpoints,
):

	service_config = get_service_config(files_artifact_mountpoints)

	service_id = "%v%v".format(
		SERVICE_ID_PREFIX,
		time.unix(),
	)

	add_service(service_id, service_config)

	return service_id

def get_service_config(
	files_artifact_mountpoints,
):
	return = struct(
		# TODO used ports is supposed to be empty
		used_ports = {},
		container_image_name = IMAGE,
		entry_point_args = ENTRYPOINT_ARGS,
		files_artifact_mount_dirpaths = files_artifact_mountpoints,
	)