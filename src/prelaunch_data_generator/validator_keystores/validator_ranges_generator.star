VALIDATOR_RANGES_FILE_NAME = "validator-ranges.yaml"
VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"

# Validator names mapping emitted by the genesis generator at the root of the
# el_cl genesis data artifact (when validator shuffling / mapping is enabled).
VALIDATOR_NAMES_FILE_NAME = "validator_names.yaml"

# Shared merge script baked into the genesis generator (egg) image. It is also
# used by the ansible inventory role, so the mapping translation lives in a
# single place instead of being reimplemented per consumer.
MERGE_SCRIPT_PATH = "/apps/validator-mapping/merge.sh"

shared_utils = import_module("../../shared_utils/shared_utils.star")


def generate_validator_ranges(
    plan,
    genesis_generator_image,
    participant_contexts,
    participant_configs,
    genesis_files_artifact=None,
    global_tolerations=[],
    global_node_selectors={},
):
    # Build the contiguous mnemonic key-index segments per client, in participant
    # order. The keystore generator derives each participant's keys from
    # contiguous mnemonic indices in this same order, so a segment maps a
    # mnemonic key-index range (inclusive) to the client that owns it.
    client_segments = []
    running_total_validator_count = 0
    for index, participant in enumerate(participant_contexts):
        full_name, _, _, _ = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )
        participant_config = participant_configs[index]
        if participant_config.validator_count == 0:
            continue
        start_index = running_total_validator_count
        running_total_validator_count += participant_config.validator_count
        end_index = start_index + participant_config.validator_count - 1
        client_segments.append(
            {
                "name": full_name,
                "start": start_index,
                "end": end_index,
            }
        )

    # The validator names mapping can only be read at execution time, so the
    # translation runs in the genesis generator image via the shared merge
    # script. We only need to stage the client segments here.
    segments_artifact = plan.render_templates(
        {
            "client_segments.json": shared_utils.new_template_and_data(
                "{{ .Json }}", {"Json": json.encode(client_segments)}
            ),
        },
        "validator-ranges-input",
    )

    files = {"/input": segments_artifact}
    mapping_arg = ""
    if genesis_files_artifact != None:
        files["/genesis"] = genesis_files_artifact
        mapping_arg = " --mapping /genesis/{0}".format(VALIDATOR_NAMES_FILE_NAME)

    result = plan.run_sh(
        name="generate-validator-ranges",
        description="Generating validator ranges from the genesis validator names mapping (if available)",
        run="mkdir -p /output && bash {0}{1} --segments /input/client_segments.json --format yaml > /output/{2}".format(
            MERGE_SCRIPT_PATH, mapping_arg, VALIDATOR_RANGES_FILE_NAME
        ),
        image=genesis_generator_image,
        files=files,
        store=[
            StoreSpec(
                src="/output/" + VALIDATOR_RANGES_FILE_NAME,
                name=VALIDATOR_RANGES_ARTIFACT_NAME,
            )
        ],
        wait=None,
        tolerations=shared_utils.get_tolerations(global_tolerations=global_tolerations),
        node_selectors=global_node_selectors,
    )

    return result.files_artifacts[0]
