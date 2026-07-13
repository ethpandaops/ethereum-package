shared_utils = import_module("../shared_utils/shared_utils.star")
constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
vc_shared = import_module("./shared.star")

# Where the prebuilt ethdo wallet artifact is mounted in the Vouch container.
VOUCH_WALLET_DIRPATH = "/vouch-wallet"

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
}


def get_config(
    plan,
    participant,
    image,
    global_log_level,
    beacon_http_urls,
    cl_context,
    vouch_wallet_artifact,
    tolerations,
    node_selectors,
):
    """
    Vouch validator client config.

    The ethdo wallet is built up-front by the caller and passed in as
    vouch_wallet_artifact, so this container needs no ethdo/apt/download: it just
    writes ~/.vouch.yml pointing at the mounted wallet and the beacon API, then
    runs vouch.

    The wallet artifact contains:
      wallets/                  the ethdo wallet store
      accounts.txt              one account path per line
      account-passphrase.txt    the account passphrase
    """
    log_level = input_parser.get_client_log_level_or_default(
        participant.vc_log_level, global_log_level, VERBOSITY_LEVELS
    )

    startup_script = (
        """#!/usr/bin/env bash
set -e

# Turn the account list shipped with the wallet into the YAML the wallet
# account manager expects.
accounts_yaml=$(sed 's/^/      - /' """
        + VOUCH_WALLET_DIRPATH
        + """/accounts.txt)

cat > ~/.vouch.yml <<EOF
beacon-node-address: """
        + beacon_http_urls[0]
        + """
log-level: \""""
        + log_level
        + """\"
accountmanager:
  wallet:
    locations:
      - """
        + VOUCH_WALLET_DIRPATH
        + """/wallets
    accounts:
${accounts_yaml}
    passphrases:
      - file://"""
        + VOUCH_WALLET_DIRPATH
        + """/account-passphrase.txt
blockrelay:
  fallback-fee-recipient: \""""
        + constants.VALIDATING_REWARDS_ACCOUNT
        + """\"
metrics:
  prometheus:
    listen-address: "0.0.0.0:"""
        + str(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM)
        + """"
EOF

# vouch binary lives at /app/vouch in the attestant/vouch image (not on PATH).
exec /app/vouch
"""
    )

    env_vars = {}
    if participant.vc_extra_env_vars:
        env_vars.update(participant.vc_extra_env_vars)

    files = {
        VOUCH_WALLET_DIRPATH: vouch_wallet_artifact,
    }

    ports = {
        constants.METRICS_PORT_ID: PortSpec(
            number=vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM,
            transport_protocol="TCP",
            application_protocol="http",
            # The wallet is built up-front, so this container starts quickly;
            # keep a modest readiness margin for vouch itself.
            wait="5m",
        ),
    }

    config_args = {
        "image": image,
        "ports": ports,
        "cmd": [startup_script],
        "entrypoint": ["bash", "-c"],
        "env_vars": env_vars,
        "files": files,
        "labels": shared_utils.label_maker(
            client=constants.VC_TYPE.vouch,
            client_type=constants.CLIENT_TYPES.validator,
            image=image[-constants.MAX_LABEL_LENGTH :],
            connected_client=cl_context.client_name,
            extra_labels=participant.vc_extra_labels,
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
        "user": User(uid=0, gid=0),
    }

    if participant.vc_min_cpu > 0:
        config_args["min_cpu"] = participant.vc_min_cpu
    if participant.vc_max_cpu > 0:
        config_args["max_cpu"] = participant.vc_max_cpu
    if participant.vc_min_mem > 0:
        config_args["min_memory"] = participant.vc_min_mem
    if participant.vc_max_mem > 0:
        config_args["max_memory"] = participant.vc_max_mem

    return ServiceConfig(**config_args)
