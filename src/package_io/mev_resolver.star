# MEV Component Resolver
#
# Decomposes mev_type (a preset shortcut) into three independent components:
#   - relay: which relay(s) to launch (flashbots, helix, mev-rs, mock, none)
#   - sidecar: which per-validator boost/PBS service to use (mev-boost, commit-boost, mev-rs, none)
#   - builder: which block builder to run (flashbots, mev-rs, buildoor, mock, none)
#
# This allows mix-and-match configurations (e.g., helix relay + commit-boost sidecar)
# without patching the code.

constants = import_module("./constants.star")

# Preset expansion table: mev_type -> (relay, sidecar, builder)
MEV_PRESETS = {
    constants.FLASHBOTS_MEV_TYPE: {
        "relay": "flashbots",
        "sidecar": "mev-boost",
        "builder": "flashbots",
    },
    constants.HELIX_MEV_TYPE: {
        "relay": "helix",
        "sidecar": "mev-boost",
        "builder": "flashbots",
    },
    constants.COMMIT_BOOST_MEV_TYPE: {
        "relay": "flashbots",
        "sidecar": "commit-boost",
        "builder": "flashbots",
    },
    constants.MEV_RS_MEV_TYPE: {
        "relay": "mev-rs",
        "sidecar": "mev-rs",
        "builder": "mev-rs",
    },
    constants.MOCK_MEV_TYPE: {
        "relay": "mock",
        "sidecar": "mev-boost",
        "builder": "mock",
    },
    constants.BUILDOOR_MEV_TYPE: {
        "relay": "none",
        "sidecar": "mev-boost",
        "builder": "buildoor",
    },
    constants.EPBS_MEV_TYPE: {
        "relay": "none",
        "sidecar": "none",
        "builder": "buildoor",
    },
}

VALID_RELAYS = ["flashbots", "helix", "mev-rs", "mock", "none"]
VALID_SIDECARS = ["mev-boost", "commit-boost", "mev-rs", "none"]
VALID_BUILDERS = ["flashbots", "mev-rs", "buildoor", "mock", "none"]


def resolve_mev_components(mev_type, mev_params):
    if mev_type == None:
        return None

    if mev_type == constants.CUSTOM_MEV_TYPE:
        relay = mev_params.get("mev_relay")
        sidecar = mev_params.get("mev_sidecar")
        builder = mev_params.get("mev_builder")
        if not relay or not sidecar or not builder:
            fail(
                "mev_type 'custom' requires explicit mev_params.mev_relay, "
                + "mev_params.mev_sidecar, and mev_params.mev_builder to be set"
            )
    elif mev_type in MEV_PRESETS:
        preset = MEV_PRESETS[mev_type]
        # Allow user to override individual components via mev_params
        relay = (
            mev_params.get("mev_relay")
            if mev_params.get("mev_relay")
            else preset["relay"]
        )
        sidecar = (
            mev_params.get("mev_sidecar")
            if mev_params.get("mev_sidecar")
            else preset["sidecar"]
        )
        builder = (
            mev_params.get("mev_builder")
            if mev_params.get("mev_builder")
            else preset["builder"]
        )
    else:
        fail(
            "Unsupported mev_type: '{0}'. Valid options: mock, flashbots, mev-rs, commit-boost, helix, buildoor, epbs, custom".format(
                mev_type
            )
        )

    # Legacy: run_multiple_relays overrides relay to a list
    if mev_params.get("run_multiple_relays", False):
        relay = ["flashbots", "helix"]

    # Normalize relay to always be a list internally
    if type(relay) == "string":
        relay_list = [relay]
    else:
        relay_list = [r for r in relay]

    # Validate relay values
    for r in relay_list:
        if r not in VALID_RELAYS:
            fail("Invalid mev_relay value: '{0}'. Valid: {1}".format(r, VALID_RELAYS))

    # Validate sidecar value
    if sidecar not in VALID_SIDECARS:
        fail(
            "Invalid mev_sidecar value: '{0}'. Valid: {1}".format(
                sidecar, VALID_SIDECARS
            )
        )

    # Validate builder value
    if builder not in VALID_BUILDERS:
        fail(
            "Invalid mev_builder value: '{0}'. Valid: {1}".format(
                builder, VALID_BUILDERS
            )
        )

    # Cross-component validation (hard errors for impossible combinations)
    all_none_relays = len([r for r in relay_list if r != "none"]) == 0

    if all_none_relays and builder == "flashbots":
        fail(
            "Invalid MEV config: mev_builder='flashbots' (rbuilder) requires at least one relay "
            + "to submit blocks to, but mev_relay is 'none'. Use mev_builder='buildoor' for ePBS "
            + "or set a relay."
        )

    if all_none_relays and sidecar != "none" and builder != "buildoor":
        fail(
            "Invalid MEV config: mev_sidecar='{0}' needs relay endpoints to connect to, ".format(
                sidecar
            )
            + "but mev_relay is 'none' and builder is not 'buildoor' (which provides its own endpoint). "
            + "Set a relay, use builder='buildoor', or set sidecar='none' for ePBS."
        )

    return struct(
        relay=relay_list,
        sidecar=sidecar,
        builder=builder,
    )


def get_sidecar_service_prefix(sidecar):
    if sidecar == "none":
        fail("BUG: get_sidecar_service_prefix called with sidecar='none'")
    if sidecar == "commit-boost":
        return constants.COMMIT_BOOST_SERVICE_NAME_PREFIX
    return constants.MEV_BOOST_SERVICE_NAME_PREFIX


def get_relay_image(relay_name, mev_params):
    if relay_name == "helix":
        return mev_params.helix_relay_image or constants.DEFAULT_HELIX_RELAY_IMAGE
    elif relay_name == "flashbots":
        return mev_params.mev_relay_image or constants.DEFAULT_FLASHBOTS_RELAY_IMAGE
    elif relay_name == "mev-rs":
        return mev_params.mev_relay_image or constants.DEFAULT_MEV_RS_IMAGE
    else:
        return mev_params.mev_relay_image
