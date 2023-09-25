# MEV Params
FLASHBOTS_MEV_BOOST_PORT = 18550
MEV_BOOST_SERVICE_NAME_PREFIX = "mev-boost-"
DEFAULT_ADDITIONAL_SERVICES = [
    "tx_spammer",
    "blob_spammer",
    "cl_forkmon",
    "el_forkmon",
    "beacon_metrics_gazer",
    "light_beaconchain_explorer",
    "prometheus_grafana",
]

ATTR_TO_BE_SKIPPED_AT_ROOT = (
    "network_params",
    "participants",
    "mev_params",
    "tx_spammer_params",
)

package_io_constants = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/constants.star"
)
package_io_parser = import_module(
    "github.com/kurtosis-tech/eth-network-package/package_io/input_parser.star"
)
genesis_constants = import_module(
    "github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/genesis_constants/genesis_constants.star"
)


def parse_input(plan, input_args):
    result = package_io_parser.parse_input(input_args)

    # we do this as the count has already been accounted for by the `package_io_parser`
    # and we end up sending the same args to `package_io_parser` again when we do eth_network_package.run()
    # that we have to do as we want to send in MEV participants
    # this will all be cleaner post merge
    for participant in result["participants"]:
        participant["count"] = 1

    # add default eth2 input params
    result["mev_type"] = None
    result["mev_params"] = get_default_mev_params()
    result["launch_additional_services"] = True
    result["additional_services"] = DEFAULT_ADDITIONAL_SERVICES

    for attr in input_args:
        value = input_args[attr]
        # if its inserted we use the value inserted
        if attr not in ATTR_TO_BE_SKIPPED_AT_ROOT and attr in input_args:
            result[attr] = value
        # custom eth2 attributes config
        elif attr == "mev_params":
            for sub_attr in input_args["mev_params"]:
                sub_value = input_args["mev_params"][sub_attr]
                result["mev_params"][sub_attr] = sub_value

    if result.get("mev_type") in ("mock", "full"):
        result = enrich_mev_extra_params(
            result,
            MEV_BOOST_SERVICE_NAME_PREFIX,
            FLASHBOTS_MEV_BOOST_PORT,
            result.get("mev_type"),
        )

    result["tx_spammer_params"] = get_default_tx_spammer_params()

    return (
        struct(
            participants=[
                struct(
                    el_client_type=participant["el_client_type"],
                    el_client_image=participant["el_client_image"],
                    el_client_log_level=participant["el_client_log_level"],
                    cl_client_type=participant["cl_client_type"],
                    cl_client_image=participant["cl_client_image"],
                    cl_client_log_level=participant["cl_client_log_level"],
                    beacon_extra_params=participant["beacon_extra_params"],
                    el_extra_params=participant["el_extra_params"],
                    validator_extra_params=participant["validator_extra_params"],
                    builder_network_params=participant["builder_network_params"],
                    validator_count=participant["validator_count"],
                )
                for participant in result["participants"]
            ],
            network_params=struct(
                preregistered_validator_keys_mnemonic=result["network_params"][
                    "preregistered_validator_keys_mnemonic"
                ],
                num_validator_keys_per_node=result["network_params"][
                    "num_validator_keys_per_node"
                ],
                network_id=result["network_params"]["network_id"],
                deposit_contract_address=result["network_params"][
                    "deposit_contract_address"
                ],
                seconds_per_slot=result["network_params"]["seconds_per_slot"],
                slots_per_epoch=result["network_params"]["slots_per_epoch"],
                genesis_delay=result["network_params"]["genesis_delay"],
                capella_fork_epoch=result["network_params"]["capella_fork_epoch"],
                deneb_fork_epoch=result["network_params"]["deneb_fork_epoch"],
                electra_fork_epoch=result["network_params"]["electra_fork_epoch"],
            ),
            mev_params=struct(
                mev_relay_image=result["mev_params"]["mev_relay_image"],
                mev_builder_image=result["mev_params"]["mev_builder_image"],
                mev_boost_image=result["mev_params"]["mev_boost_image"],
                mev_relay_api_extra_args=result["mev_params"][
                    "mev_relay_api_extra_args"
                ],
                mev_relay_housekeeper_extra_args=result["mev_params"][
                    "mev_relay_housekeeper_extra_args"
                ],
                mev_relay_website_extra_args=result["mev_params"][
                    "mev_relay_website_extra_args"
                ],
                mev_builder_extra_args=result["mev_params"]["mev_builder_extra_args"],
                mev_flood_image=result["mev_params"]["mev_flood_image"],
                mev_flood_extra_args=result["mev_params"]["mev_flood_extra_args"],
                mev_flood_seconds_per_bundle=result["mev_params"][
                    "mev_flood_seconds_per_bundle"
                ],
                launch_custom_flood=result["mev_params"]["launch_custom_flood"],
            ),
            tx_spammer_params=struct(
                tx_spammer_extra_args=result["tx_spammer_params"][
                    "tx_spammer_extra_args"
                ],
            ),
            launch_additional_services=result["launch_additional_services"],
            additional_services=result["additional_services"],
            wait_for_finalization=result["wait_for_finalization"],
            global_client_log_level=result["global_client_log_level"],
            mev_type=result["mev_type"],
        ),
        result,
    )


def get_default_mev_params():
    return {
        "mev_relay_image": "flashbots/mev-boost-relay:latest",
        # TODO replace with flashbots/builder when they publish an arm64 image as mentioned in flashbots/builder#105
        "mev_builder_image": "ethpandaops/flashbots-builder:main",
        "mev_boost_image": "flashbots/mev-boost",
        "mev_relay_api_extra_args": [],
        "mev_relay_housekeeper_extra_args": [],
        "mev_relay_website_extra_args": [],
        "mev_builder_extra_args": [],
        "mev_flood_image": "flashbots/mev-flood",
        "mev_flood_extra_args": [],
        "mev_flood_seconds_per_bundle": 15,
        # this is a simple script that increases the balance of the coinbase address at a cadence
        "launch_custom_flood": False,
    }


def get_default_tx_spammer_params():
    return {"tx_spammer_extra_args": []}


# TODO perhaps clean this up into a map
def enrich_mev_extra_params(parsed_arguments_dict, mev_prefix, mev_port, mev_type):
    for index, participant in enumerate(parsed_arguments_dict["participants"]):
        mev_url = "http://{0}{1}:{2}".format(mev_prefix, index, mev_port)

        if participant["cl_client_type"] == "lighthouse":
            participant["validator_extra_params"].append("--builder-proposals")
            participant["beacon_extra_params"].append("--builder={0}".format(mev_url))
        if participant["cl_client_type"] == "lodestar":
            participant["beacon_extra_params"].append("--builder")
            participant["beacon_extra_params"].append(
                "--builder.urls={0}".format(mev_url)
            )
        if participant["cl_client_type"] == "nimbus":
            participant["validator_extra_params"].append("--payload-builder=true")
            participant["beacon_extra_params"].append(
                "--payload-builder=true", "--payload-builder-url={0}".format(mev_url)
            )
        if participant["cl_client_type"] == "teku":
            participant["validator_extra_params"].append(
                "--validators-builder-registration-default-enabled=true"
            )
            participant["beacon_extra_params"].append(
                "--builder-endpoint={0}".format(mev_url)
            )
        if participant["cl_client_type"] == "prysm":
            participant["validator_extra_params"].append("--enable-builder")
            participant["beacon_extra_params"].append(
                "--http-mev-relay={0}".format(mev_url)
            )

    num_participants = len(parsed_arguments_dict["participants"])

    if mev_type == "full":

        mev_participant = {
            "el_client_type": "geth",
            # TODO replace with actual when flashbots/builder is published
            "el_client_image": parsed_arguments_dict["mev_params"]["mev_builder_image"],
            "el_client_log_level":    "",
            "cl_client_type":         "lighthouse",
            # THIS overrides the beacon image
            "cl_client_image":        "sigp/lighthouse",
            "cl_client_log_level":    "",
            "beacon_extra_params":    [
                "--always-prepare-payload",
                "--prepare-payload-lookahead",
                "12000"
                ],
            # TODO(maybe) make parts of this more passable like the mev-relay-endpoint & forks
            "el_extra_params": [
                "--builder",
                "--builder.remote_relay_endpoint=http://mev-relay-api:9062",
                "--builder.beacon_endpoints=http://cl-{0}-lighthouse-geth:4000".format(num_participants+1),
                "--builder.bellatrix_fork_version=0x30000038",
                "--builder.genesis_fork_version=0x10000038",
                "--builder.genesis_validators_root={0}".format(package_io_constants.GENESIS_VALIDATORS_ROOT_PLACEHOLDER),
                "--miner.extradata=\"Illuminate Dmocratize Dstribute\"",
                "--builder.algotype=greedy"
                ] + parsed_arguments_dict["mev_params"]["mev_builder_extra_args"],
            "el_extra_env_vars": {"BUILDER_TX_SIGNING_KEY": "0x" + genesis_constants.PRE_FUNDED_ACCOUNTS[0].private_key},
            "validator_extra_params": [],
            "builder_network_params": None,
            "validator_count": 0
        }

        parsed_arguments_dict["participants"].append(mev_participant)

    return parsed_arguments_dict
