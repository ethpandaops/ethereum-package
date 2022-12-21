IMAGE = "ethpandaops/ethereum-genesis-generator:1.0.6"

SERVICE_ID_PREFIX = "prelaunch-data-generator-"

# We use Docker exec commands to run the commands we need, so we override the default
ENTRYPOINT_ARGS = [
	"sleep",
	"999999",
]

# Launches a prelaunch data generator IMAGE, for use in various of the genesis generation
def launch_prelaunch_data_generator(plan, files_artifact_mountpoints):

	config = get_config(files_artifact_mountpoints)

	service_id = "{0}{1}".format(
		SERVICE_ID_PREFIX,
		time.now().unix_nano,
	)

	plan.add_service(service_id, config)

	return service_id

def get_config(
	files_artifact_mountpoints,
):
	return ServiceConfig(
		image = IMAGE,
		entrypoint = ENTRYPOINT_ARGS,
		files = files_artifact_mountpoints,
	)
