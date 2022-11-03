# One of these will be created per node we're trying to start
def new_keystore_files(files_artifact_uuid, raw_keys_relative_dirpath, raw_secrets_relative_dirpath, nimbus_keys_relative_dirpath, prysm_relative_dirpath, teku_keys_relative_dirpath, teku_secrets_relative_dirpath):
	return struct(
		FilesArtifactUUID =  files_artifact_uuid,
		# ------------ All directories below are relative to the root of the files artifact ----------------
		RawKeysRelativeDirpath =  raw_keys_relative_dirpath,
		RawSecretsRelativeDirpath =  raw_secrets_relative_dirpath,
		NimbusKeysRelativeDirpath =  nimbus_keys_relative_dirpath,
		PrysmRelativeDirpath =  prysm_relative_dirpath,
		TekuKeysRelativeDirpath =  teku_keys_relative_dirpath,
		TekuSecretsRelativeDirpath =  teku_secrets_relative_dirpath 
	)
