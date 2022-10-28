# Package object containing information about the keystores that were generated for validators 
# during genesis creation
def new_generate_keystores_result(prysm_password_artifact_uuid, prysm_password_relative_filepath, per_node_keystores):
	return struct(
		#Files artifact UUID where the Prysm password is stored
		PrysmPasswordArtifactUUid = prysm_password_artifact_uuid,

		# Relative to root of files artifact
		PrysmPasswordRelativeFilepath = prysm_password_relative_filepath,

		# Contains keystores-per-client-type for each node in the network
		PerNodeKeystores = per_node_keystores
	)