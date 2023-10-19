def new_el_cl_genesis_data(
    files_artifact_uuid,
    genesis_validators_root,
    jwt_secret_contents,
):
    return struct(
        files_artifact_uuid=files_artifact_uuid,
        genesis_validators_root=genesis_validators_root,
        jwt_secret_contents=jwt_secret_contents,
    )
