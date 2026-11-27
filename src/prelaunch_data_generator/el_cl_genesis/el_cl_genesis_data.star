def new_el_cl_genesis_data(
    files_artifact_uuid,
    genesis_validators_root,
    osaka_time="",
    shadowfork_block_height="",
    eip8141_at_bogota=False,
):
    return struct(
        files_artifact_uuid=files_artifact_uuid,
        genesis_validators_root=genesis_validators_root,
        osaka_time=osaka_time,
        shadowfork_block_height=shadowfork_block_height,
        eip8141_at_bogota=eip8141_at_bogota,
    )
