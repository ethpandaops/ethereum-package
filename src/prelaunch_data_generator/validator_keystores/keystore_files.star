# One of these will be created per node we're trying to start
def new_keystore_files(
    files_artifact_uuid,
    raw_root_dirpath,
    raw_keys_relative_dirpath,
    raw_secrets_relative_dirpath,
    nimbus_keys_relative_dirpath,
    prysm_relative_dirpath,
    teku_keys_relative_dirpath,
    teku_secrets_relative_dirpath,
):
    return struct(
        files_artifact_uuid=files_artifact_uuid,
        # ------------ All directories below are relative to the root of the files artifact ----------------
        raw_root_dirpath=raw_root_dirpath,
        raw_keys_relative_dirpath=raw_keys_relative_dirpath,
        raw_secrets_relative_dirpath=raw_secrets_relative_dirpath,
        nimbus_keys_relative_dirpath=nimbus_keys_relative_dirpath,
        prysm_relative_dirpath=prysm_relative_dirpath,
        teku_keys_relative_dirpath=teku_keys_relative_dirpath,
        teku_secrets_relative_dirpath=teku_secrets_relative_dirpath,
    )
