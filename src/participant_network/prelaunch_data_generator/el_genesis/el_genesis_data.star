def new_el_genesis_data(
	files_artifact_uuid,
	jwt_secret_relative_filepath,
	geth_genesis_json_relative_filepath,
	erigon_genesis_json_relative_filepath,
	nethermind_genesis_json_relative_filepath,
	besu_genesis_json_relative_filepath):
	return struct(
		files_artifact_uuid = files_artifact_uuid,
		jwt_secret_relative_filepath = jwt_secret_relative_filepath,
		geth_genesis_json_relative_filepath = geth_genesis_json_relative_filepath,
		erigon_genesis_json_relative_filepath = erigon_genesis_json_relative_filepath,
		nethermind_genesis_json_relative_filepath = nethermind_genesis_json_relative_filepath,
		besu_genesis_json_relative_filepath = besu_genesis_json_relative_filepath,
	)
