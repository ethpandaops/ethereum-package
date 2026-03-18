#!/usr/bin/env python3
"""
Compares default consensus spec values in input_parser.star against
the upstream ethereum/consensus-specs configs.

Exits non-zero if any tracked fields have different values or are missing
from our defaults relative to the upstream spec.
"""

import argparse
import re
import sys
import urllib.request

import yaml

FAR_FUTURE_EPOCH = 18446744073709551615

# Mapping from consensus-spec YAML keys to input_parser.star field names.
# Only fields that are directly hardcoded in the defaults dicts are tracked.
SPEC_TO_STARLARK = {
    "AGGREGATE_DUE_BPS_GLOAS": "aggregate_due_bps_gloas",
    "ATTESTATION_DUE_BPS_GLOAS": "attestation_due_bps_gloas",
    "CHURN_LIMIT_QUOTIENT": "churn_limit_quotient",
    "CONTRIBUTION_DUE_BPS_GLOAS": "contribution_due_bps_gloas",
    "CUSTODY_REQUIREMENT": "custody_requirement",
    "DATA_COLUMN_SIDECAR_SUBNET_COUNT": "data_column_sidecar_subnet_count",
    "EJECTION_BALANCE": "ejection_balance",
    "ETH1_FOLLOW_DISTANCE": "eth1_follow_distance",
    "INCLUSION_LIST_SUBMISSION_DUE_BPS": "inclusion_list_submission_due_bps",
    "MAX_BLOBS_PER_BLOCK_ELECTRA": "max_blobs_per_block_electra",
    "MAX_PAYLOAD_SIZE": "max_payload_size",
    "MAX_PER_EPOCH_ACTIVATION_CHURN_LIMIT": "max_per_epoch_activation_churn_limit",
    "MAX_REQUEST_BLOCKS_DENEB": "max_request_blocks_deneb",
    "MIN_BUILDER_WITHDRAWABILITY_DELAY": "min_builder_withdrawability_delay",
    "MIN_EPOCHS_FOR_DATA_COLUMN_SIDECARS_REQUESTS": "min_epochs_for_data_column_sidecars_requests",
    "MIN_VALIDATOR_WITHDRAWABILITY_DELAY": "min_validator_withdrawability_delay",
    "PAYLOAD_ATTESTATION_DUE_BPS": "payload_attestation_due_bps",
    "PROPOSER_INCLUSION_LIST_CUTOFF_BPS": "proposer_inclusion_list_cutoff_bps",
    "SAMPLES_PER_SLOT": "samples_per_slot",
    "SHARD_COMMITTEE_PERIOD": "shard_committee_period",
    "SLOT_DURATION_MS": "slot_duration_ms",
    "SYNC_MESSAGE_DUE_BPS_GLOAS": "sync_message_due_bps_gloas",
    "VIEW_FREEZE_CUTOFF_BPS": "view_freeze_cutoff_bps",
}

FUNC_FOR_PRESET = {
    "mainnet": "default_network_params",
    "minimal": "default_minimal_network_params",
}


def extract_function_body(star_content: str, func_name: str) -> str:
    """Return the text between 'return {' and the matching closing '}' for func_name."""
    func_pattern = re.compile(
        rf"^def {re.escape(func_name)}\(\):", re.MULTILINE
    )
    match = func_pattern.search(star_content)
    if not match:
        raise ValueError(f"Function {func_name!r} not found in Starlark file")

    tail = star_content[match.start():]
    return_match = re.search(r"\n    return \{", tail)
    if not return_match:
        raise ValueError(f"No 'return {{' found in {func_name!r}")

    body_start = return_match.end()
    depth = 1
    pos = body_start
    while pos < len(tail) and depth > 0:
        c = tail[pos]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        pos += 1

    return tail[body_start : pos - 1]


def extract_defaults(star_content: str, preset: str) -> dict:
    """Extract integer default values for the given preset from input_parser.star."""
    func_name = FUNC_FOR_PRESET[preset]
    body = extract_function_body(star_content, func_name)

    # Replace the FAR_FUTURE_EPOCH constant so integer regex can match it
    body = body.replace("constants.FAR_FUTURE_EPOCH", str(FAR_FUTURE_EPOCH))

    result = {}
    # Match lines like:   "key": 12345,
    for m in re.finditer(r'"(\w+)":\s*(\d+)', body):
        result[m.group(1)] = int(m.group(2))
    return result


def load_yaml(path_or_url: str) -> dict:
    if path_or_url.startswith("http://") or path_or_url.startswith("https://"):
        with urllib.request.urlopen(path_or_url) as response:
            return yaml.safe_load(response.read().decode())
    with open(path_or_url) as f:
        return yaml.safe_load(f)


def compare(starlark_defaults: dict, spec_config: dict) -> bool:
    failures = []

    for spec_key, starlark_key in sorted(SPEC_TO_STARLARK.items()):
        if spec_key not in spec_config:
            # Field not present in this version of the spec — skip silently
            continue

        spec_val = spec_config[spec_key]

        if starlark_key not in starlark_defaults:
            failures.append(
                f"  MISSING {starlark_key!r} in input_parser.star"
                f"  (spec has {spec_key}: {spec_val!r})"
            )
            continue

        our_val = starlark_defaults[starlark_key]
        if our_val != spec_val:
            failures.append(
                f"  MISMATCH {spec_key!r}:\n"
                f"    ours ({starlark_key}): {our_val!r}\n"
                f"    spec: {spec_val!r}"
            )

    if failures:
        print(f"FAILED: {len(failures)} issue(s) found:")
        for f in failures:
            print(f)
        return False

    print(f"OK: all {len(SPEC_TO_STARLARK)} tracked spec fields match.")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Compare input_parser.star defaults against the upstream consensus-specs config"
    )
    parser.add_argument(
        "--star-file",
        required=True,
        help="Path to src/package_io/input_parser.star",
    )
    parser.add_argument(
        "--preset",
        required=True,
        choices=list(FUNC_FOR_PRESET),
        help="Preset to check (mainnet or minimal)",
    )
    parser.add_argument(
        "--spec-config",
        required=True,
        help="Path or HTTPS URL to the upstream consensus-spec config.yaml",
    )
    args = parser.parse_args()

    with open(args.star_file) as f:
        star_content = f.read()

    starlark_defaults = extract_defaults(star_content, args.preset)
    spec_config = load_yaml(args.spec_config)

    if not compare(starlark_defaults, spec_config):
        sys.exit(1)


if __name__ == "__main__":
    main()
