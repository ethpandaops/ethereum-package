VALIDATOR_RANGES_FILE_NAME = "validator-ranges.yaml"
VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"

shared_utils = import_module("../../shared_utils/shared_utils.star")
constants = import_module("../../package_io/constants.star")

# Python that runs at execution time. It reads the client segments (passed via a
# rendered JSON file) and, if the genesis generator emitted a validator names
# mapping (validator shuffling enabled), translates the on-chain ranges to client
# names; otherwise it falls back to the legacy direct index mapping. The mapping
# and the segments are only available at execution time, so this can't be done in
# Starlark (which would only see Kurtosis runtime-value placeholders).
#
# NOTE: keep this brace-free ("{" / "}") so it survives Go-template rendering.
GENERATE_RANGES_PY = """
import json, os, yaml

OUTPUT_PATH = "{{ .OutputPath }}"
MAIN_MNEMONIC_SRC = "main-mnemonic"

# The mapping lives at the artifact root
MAPPING_PATH = "/genesis/validator_names.yaml"

with open("/input/client_segments.json") as f:
    segments = json.load(f)

mapping = None
if os.path.isfile(MAPPING_PATH):
    with open(MAPPING_PATH) as f:
        mapping = yaml.safe_load(f)

lines = []


def emit(range_start, range_end, name):
    lines.append("%d-%d: %s" % (range_start, range_end, name))


if mapping:
    for entry in mapping:
        for onchain_range, value in entry.items():
            parts = str(onchain_range).split("-")
            onchain_start = int(parts[0])
            onchain_end = int(parts[1])
            src = value["src"]
            deriv_from = value["from"]
            deriv_to = value["to"]

            if src != MAIN_MNEMONIC_SRC:
                # Not derived from the main mnemonic; pass the source through
                # as-is without resolving it to a participant client name.
                emit(onchain_start, onchain_end, src)
                continue

            # The on-chain range and the mnemonic-derivation range have equal
            # length and order, so walk the derivation range and split it on the
            # client boundaries (mapping groups and client boundaries may not
            # align), translating each sub-range back to on-chain indices.
            cursor = deriv_from
            while cursor <= deriv_to:
                client_name = None
                sub_end = deriv_to
                for seg in segments:
                    if seg["start"] <= cursor and cursor <= seg["end"]:
                        client_name = seg["name"]
                        sub_end = min(seg["end"], deriv_to)
                        break

                if client_name is None:
                    # No client owns this derivation index (e.g. builder or extra
                    # pre-registered keys). Keep the source name and skip ahead to
                    # the next client boundary so nothing is dropped.
                    client_name = src
                    sub_end = deriv_to
                    for seg in segments:
                        if cursor < seg["start"] and seg["start"] <= deriv_to:
                            sub_end = min(sub_end, seg["start"] - 1)

                emit(
                    onchain_start + (cursor - deriv_from),
                    onchain_start + (sub_end - deriv_from),
                    client_name,
                )
                cursor = sub_end + 1
else:
    for seg in segments:
        emit(seg["start"], seg["end"], seg["name"])

os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
with open(OUTPUT_PATH, "w") as f:
    f.write("\\n".join(lines))
    if lines:
        f.write("\\n")
"""


def generate_validator_ranges(
    plan,
    participant_contexts,
    participant_configs,
    genesis_files_artifact=None,
    global_tolerations=[],
    global_node_selectors={},
):
    # Build the contiguous mnemonic-derivation segments per client, in
    # participant order. The keystore generator derives each participant's keys
    # from contiguous mnemonic indices in this same order, so a segment maps a
    # mnemonic-derivation index range to the client that owns it. Without
    # shuffling the derivation index equals the on-chain validator index, so
    # these segments also describe the legacy direct mapping.
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

    # Stage the generator script and the client segments as files for the
    # execution-time run (the genesis mapping can only be read at execution time).
    input_artifact = plan.render_templates(
        {
            "generate_ranges.py": shared_utils.new_template_and_data(
                GENERATE_RANGES_PY,
                {"OutputPath": "/output/" + VALIDATOR_RANGES_FILE_NAME},
            ),
            "client_segments.json": shared_utils.new_template_and_data(
                "{{ .Json }}", {"Json": json.encode(client_segments)}
            ),
        },
        "validator-ranges-input",
    )

    files = {"/input": input_artifact}
    if genesis_files_artifact != None:
        files["/genesis"] = genesis_files_artifact

    result = plan.run_sh(
        name="generate-validator-ranges",
        description="Generating validator ranges from genesis validator names mapping (if available)",
        run="python3 /input/generate_ranges.py",
        image=constants.DEFAULT_YQ_IMAGE,
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
