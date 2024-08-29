def new_el_cl_genesis_data(
    files_artifact_uuid,
    genesis_validators_root,
    cancun_time,
    verkle_time,
):
    return struct(
        files_artifact_uuid=files_artifact_uuid,
        genesis_validators_root=genesis_validators_root,
        cancun_time=cancun_time,
        verkle_time=verkle_time,
    )
