def new_cl_genesis_data(
	files_artifact_uuid,
	jwt_secret_rel_filepath,
	config_yml_rel_filepath,
	genesis_ssz_rel_filepath):

	return struct(
		files_artifact_uuid = files_artifact_uuid,
		jwt_secret_rel_filepath = jwt_secret_rel_filepath,
		config_yml_rel_filepath = config_yml_rel_filepath,
		genesis_ssz_rel_filepath = genesis_ssz_rel_filepath,
	)
