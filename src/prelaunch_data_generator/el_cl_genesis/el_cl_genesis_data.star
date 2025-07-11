def new_el_cl_genesis_data(
    files_artifact_uuid,
    genesis_validators_root,
    osaka_time=0,
    osaka_enabled=False,
):
    return struct(
        files_artifact_uuid=files_artifact_uuid,
        genesis_validators_root=genesis_validators_root,
        osaka_time=osaka_time,
        osaka_enabled=osaka_enabled,
    )
