#!/usr/bin/env python3
"""
Compares a generated config.yaml against the upstream consensus-specs config.

Exits non-zero if any non-excluded fields have different values or are missing
from our config relative to the upstream spec.
"""

import argparse
import sys
import urllib.request

import yaml


# Fields that are intentionally testnet-specific or explicitly excluded from comparison.
EXCLUDED_FIELDS = {
    # Network identity - intentionally differs for testnets
    "CONFIG_NAME",
    # Merge transition - testnets start post-merge with TTD=0
    "TERMINAL_TOTAL_DIFFICULTY",
    # Genesis params - testnet-configurable
    "MIN_GENESIS_ACTIVE_VALIDATOR_COUNT",
    "MIN_GENESIS_TIME",
    "GENESIS_FORK_VERSION",
    "GENESIS_DELAY",
    # Fork versions - testnet-specific values
    "ALTAIR_FORK_VERSION",
    "BELLATRIX_FORK_VERSION",
    "CAPELLA_FORK_VERSION",
    "DENEB_FORK_VERSION",
    "ELECTRA_FORK_VERSION",
    "FULU_FORK_VERSION",
    "GLOAS_FORK_VERSION",
    "HEZE_FORK_VERSION",
    "EIP7928_FORK_VERSION",
    # Fork activation epochs - testnets activate all forks at epoch 0
    "ALTAIR_FORK_EPOCH",
    "BELLATRIX_FORK_EPOCH",
    "CAPELLA_FORK_EPOCH",
    "DENEB_FORK_EPOCH",
    "ELECTRA_FORK_EPOCH",
    "FULU_FORK_EPOCH",
    "GLOAS_FORK_EPOCH",
    "HEZE_FORK_EPOCH",
    "EIP7928_FORK_EPOCH",
    # Deposit contract - testnet-configurable
    "DEPOSIT_CHAIN_ID",
    "DEPOSIT_NETWORK_ID",
    "DEPOSIT_CONTRACT_ADDRESS",
    # Blob schedule - explicitly excluded
    "BLOB_SCHEDULE",
    # Deprecated field moved to preset files, not present in spec configs
    "SECONDS_PER_SLOT",
}


def load_yaml(path_or_url: str) -> dict:
    if path_or_url.startswith("http://") or path_or_url.startswith("https://"):
        with urllib.request.urlopen(path_or_url) as response:
            return yaml.safe_load(response.read().decode())
    with open(path_or_url) as f:
        return yaml.safe_load(f)


def compare_configs(our_config: dict, spec_config: dict) -> bool:
    failures = []
    warnings = []

    spec_keys = {k for k in spec_config if k not in EXCLUDED_FIELDS}
    our_keys = {k for k in our_config if k not in EXCLUDED_FIELDS}

    for key in sorted(spec_keys - our_keys):
        failures.append(
            f"  MISSING in our config: {key!r}  (spec has: {spec_config[key]!r})"
        )

    for key in sorted(spec_keys & our_keys):
        spec_val = spec_config[key]
        our_val = our_config[key]
        if spec_val != our_val:
            failures.append(
                f"  MISMATCH {key!r}:\n"
                f"    ours: {our_val!r}\n"
                f"    spec: {spec_val!r}"
            )

    for key in sorted(our_keys - spec_keys):
        warnings.append(
            f"  EXTRA field in our config (not in spec): {key!r} = {our_config[key]!r}"
        )

    if warnings:
        print("Warnings (fields present in our config but not in the upstream spec):")
        for w in warnings:
            print(w)
        print()

    if failures:
        print(f"FAILED: {len(failures)} issue(s) found:")
        for failure in failures:
            print(failure)
        return False

    print(f"OK: all {len(spec_keys & our_keys)} comparable spec fields match.")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Compare our generated config.yaml against the upstream consensus-specs config"
    )
    parser.add_argument(
        "--our-config",
        required=True,
        help="Path to our generated config.yaml",
    )
    parser.add_argument(
        "--spec-config",
        required=True,
        help="Path or HTTPS URL to the upstream consensus-spec config.yaml",
    )
    args = parser.parse_args()

    our_config = load_yaml(args.our_config)
    spec_config = load_yaml(args.spec_config)

    if not compare_configs(our_config, spec_config):
        sys.exit(1)


if __name__ == "__main__":
    main()
