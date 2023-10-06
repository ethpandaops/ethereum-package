DEFAULT_EL_IMAGES = {
    "geth": "ethereum/client-go:latest",
    "erigon": "thorax/erigon:devel",
    "nethermind": "nethermind/nethermind:latest",
    "besu": "hyperledger/besu:develop",
    "reth": "ghcr.io/paradigmxyz/reth",
    "ethereumjs": "ethpandaops/ethereumjs:master",
}

DEFAULT_CL_IMAGES = {
    "lighthouse": "sigp/lighthouse:latest",
    "teku": "consensys/teku:latest",
    "nimbus": "statusim/nimbus-eth2:multiarch-latest",
    "prysm": "prysmaticlabs/prysm-beacon-chain:latest,prysmaticlabs/prysm-validator:latest",
    "lodestar": "chainsafe/lodestar:latest",
}

MEV_BOOST_RELAY_DEFAULT_IMAGE = "flashbots/mev-boost-relay:0.26"

NETHERMIND_NODE_NAME = "nethermind"
NIMBUS_NODE_NAME = "nimbus"

# Placeholder value for the deneb fork epoch if electra is being run
# TODO: This is a hack, and should be removed once we electra is rebased on deneb
HIGH_DENEB_VALUE_FORK_VERKLE = 20000

# MEV Params
FLASHBOTS_MEV_BOOST_PORT = 18550
MEV_BOOST_SERVICE_NAME_PREFIX = "mev-boost-"

DEFAULT_ADDITIONAL_SERVICES = [
    "tx_spammer",
    "blob_spammer",
    "cl_forkmon",
    "el_forkmon",
    "beacon_metrics_gazer",
    "explorer",
    "prometheus_grafana",
]

ATTR_TO_BE_SKIPPED_AT_ROOT = (
    "network_params",
    "participants",
    "mev_params",
    "tx_spammer_params",
)

DEFAULT_EXPLORER_VERSION = "dora"

package_io_constants = import_module("../package_io/constants.star")

genesis_constants = import_module(
    "../prelaunch_data_generator/genesis_constants/genesis_constants.star"
)


def parse_input(plan, input_args):
    result = parse_network_params(input_args)

    # add default eth2 input params
    result["mev_type"] = None
    result["mev_params"] = get_default_mev_params()
    result["launch_additional_services"] = True
    result["additional_services"] = DEFAULT_ADDITIONAL_SERVICES
    result["explorer_version"] = DEFAULT_EXPLORER_VERSION
    result["grafana_additional_dashboards"] = []

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

    if (
        result.get("mev_type") == "full"
        and result["network_params"]["capella_fork_epoch"] == 0
        and result["mev_params"]["mev_relay_image"] == MEV_BOOST_RELAY_DEFAULT_IMAGE
    ):
        fail(
            "The default MEV image {0} requires a non-zero value for capella fork epoch set via network_params.capella_fork_epoch".format(
                MEV_BOOST_RELAY_DEFAULT_IMAGE
            )
        )

    result["tx_spammer_params"] = get_default_tx_spammer_params()

    return struct(
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
                el_extra_env_vars=participant["el_extra_env_vars"],
                validator_extra_params=participant["validator_extra_params"],
                builder_network_params=participant["builder_network_params"],
                el_min_cpu=participant["el_min_cpu"],
                el_max_cpu=participant["el_max_cpu"],
                el_min_mem=participant["el_min_mem"],
                el_max_mem=participant["el_max_mem"],
                bn_min_cpu=participant["bn_min_cpu"],
                bn_max_cpu=participant["bn_max_cpu"],
                bn_min_mem=participant["bn_min_mem"],
                bn_max_mem=participant["bn_max_mem"],
                v_min_cpu=participant["v_min_cpu"],
                v_max_cpu=participant["v_max_cpu"],
                v_min_mem=participant["v_min_mem"],
                v_max_mem=participant["v_max_mem"],
                validator_count=participant["validator_count"],
                snooper_enabled=participant["snooper_enabled"],
                count=participant["count"],
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
            mev_relay_api_extra_args=result["mev_params"]["mev_relay_api_extra_args"],
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
            tx_spammer_extra_args=result["tx_spammer_params"]["tx_spammer_extra_args"],
        ),
        launch_additional_services=result["launch_additional_services"],
        additional_services=result["additional_services"],
        wait_for_finalization=result["wait_for_finalization"],
        global_client_log_level=result["global_client_log_level"],
        mev_type=result["mev_type"],
        snooper_enabled=result["snooper_enabled"],
        parallel_keystore_generation=result["parallel_keystore_generation"],
        explorer_version=result["explorer_version"],
        grafana_additional_dashboards=result["grafana_additional_dashboards"],
    )


def parse_network_params(input_args):
    result = default_input_args()
    for attr in input_args:
        value = input_args[attr]
        # if its insterted we use the value inserted
        if attr not in ATTR_TO_BE_SKIPPED_AT_ROOT and attr in input_args:
            result[attr] = value
        elif attr == "network_params":
            for sub_attr in input_args["network_params"]:
                sub_value = input_args["network_params"][sub_attr]
                result["network_params"][sub_attr] = sub_value
        elif attr == "participants":
            participants = []
            for participant in input_args["participants"]:
                new_participant = default_participant()
                for sub_attr, sub_value in participant.items():
                    # if the value is set in input we set it in participant
                    new_participant[sub_attr] = sub_value
                for _ in range(0, new_participant["count"]):
                    participant_copy = deep_copy_participant(new_participant)
                    participants.append(participant_copy)
            result["participants"] = participants

    total_participant_count = 0
    actual_num_validators = 0
    # validation of the above defaults
    for index, participant in enumerate(result["participants"]):
        el_client_type = participant["el_client_type"]
        cl_client_type = participant["cl_client_type"]

        if cl_client_type in (NIMBUS_NODE_NAME) and (
            result["network_params"]["seconds_per_slot"] < 12
        ):
            fail("nimbus can't be run with slot times below 12 seconds")
        el_image = participant["el_client_image"]
        if el_image == "":
            default_image = DEFAULT_EL_IMAGES.get(el_client_type, "")
            if default_image == "":
                fail(
                    "{0} received an empty image name and we don't have a default for it".format(
                        el_client_type
                    )
                )
            participant["el_client_image"] = default_image

        cl_image = participant["cl_client_image"]
        if cl_image == "":
            default_image = DEFAULT_CL_IMAGES.get(cl_client_type, "")
            if default_image == "":
                fail(
                    "{0} received an empty image name and we don't have a default for it".format(
                        cl_client_type
                    )
                )
            participant["cl_client_image"] = default_image

        snooper_enabled = participant["snooper_enabled"]
        if snooper_enabled == False:
            default_snooper_enabled = result["snooper_enabled"]
            if default_snooper_enabled:
                participant["snooper_enabled"] = default_snooper_enabled

        validator_count = participant["validator_count"]
        if validator_count == None:
            default_validator_count = result["network_params"][
                "num_validator_keys_per_node"
            ]
            participant["validator_count"] = default_validator_count

        actual_num_validators += participant["validator_count"]

        beacon_extra_params = participant.get("beacon_extra_params", [])
        participant["beacon_extra_params"] = beacon_extra_params

        validator_extra_params = participant.get("validator_extra_params", [])
        participant["validator_extra_params"] = validator_extra_params

        total_participant_count += participant["count"]

    if result["network_params"]["network_id"].strip() == "":
        fail("network_id is empty or spaces it needs to be of non zero length")

    if result["network_params"]["deposit_contract_address"].strip() == "":
        fail(
            "deposit_contract_address is empty or spaces it needs to be of non zero length"
        )

    if result["network_params"]["preregistered_validator_keys_mnemonic"].strip() == "":
        fail(
            "preregistered_validator_keys_mnemonic is empty or spaces it needs to be of non zero length"
        )

    if result["network_params"]["slots_per_epoch"] == 0:
        fail("slots_per_epoch is 0 needs to be > 0 ")

    if result["network_params"]["seconds_per_slot"] == 0:
        fail("seconds_per_slot is 0 needs to be > 0 ")

    if result["network_params"]["genesis_delay"] == 0:
        fail("genesis_delay is 0 needs to be > 0 ")

    if result["network_params"]["deneb_fork_epoch"] == 0:
        fail("deneb_fork_epoch is 0 needs to be > 0 ")

    if result["network_params"]["electra_fork_epoch"] != None:
        # if electra is defined, then deneb needs to be set very high
        result["network_params"]["deneb_fork_epoch"] = HIGH_DENEB_VALUE_FORK_VERKLE

    if (
        result["network_params"]["capella_fork_epoch"] > 0
        and result["network_params"]["electra_fork_epoch"] != None
    ):
        fail("electra can only happen with capella genesis not bellatrix")

    required_num_validators = 2 * result["network_params"]["slots_per_epoch"]
    actual_num_validators = (
        total_participant_count
        * result["network_params"]["num_validator_keys_per_node"]
    )
    if required_num_validators > actual_num_validators:
        fail(
            "required_num_validators - {0} is greater than actual_num_validators - {1}".format(
                required_num_validators, actual_num_validators
            )
        )

    return result


def get_client_log_level_or_default(
    participant_log_level, global_log_level, client_log_levels
):
    log_level = participant_log_level
    if log_level == "":
        log_level = client_log_levels.get(global_log_level, "")
        if log_level == "":
            fail(
                "No participant log level defined, and the client log level has no mapping for global log level '{0}'".format(
                    global_log_level
                )
            )
    return log_level


def default_input_args():
    network_params = default_network_params()
    participants = [default_participant()]
    return {
        "participants": participants,
        "network_params": network_params,
        "wait_for_finalization": False,
        "global_client_log_level": "info",
        "snooper_enabled": False,
        "parallel_keystore_generation": False,
    }


def default_network_params():
    # this is temporary till we get params working
    return {
        "preregistered_validator_keys_mnemonic": "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete",
        "num_validator_keys_per_node": 64,
        "network_id": "3151908",
        "deposit_contract_address": "0x4242424242424242424242424242424242424242",
        "seconds_per_slot": 12,
        "slots_per_epoch": 32,
        "genesis_delay": 120,
        "capella_fork_epoch": 0,
        "deneb_fork_epoch": 500,
        "electra_fork_epoch": None,
    }


def default_participant():
    return {
        "el_client_type": "geth",
        "el_client_image": "",
        "el_client_log_level": "",
        "cl_client_type": "lighthouse",
        "cl_client_image": "",
        "cl_client_log_level": "",
        "beacon_extra_params": [],
        "el_extra_params": [],
        "el_extra_env_vars": {},
        "validator_extra_params": [],
        "builder_network_params": None,
        "el_min_cpu": 0,
        "el_max_cpu": 0,
        "el_min_mem": 0,
        "el_max_mem": 0,
        "bn_min_cpu": 0,
        "bn_max_cpu": 0,
        "bn_min_mem": 0,
        "bn_max_mem": 0,
        "v_min_cpu": 0,
        "v_max_cpu": 0,
        "v_min_mem": 0,
        "v_max_mem": 0,
        "validator_count": None,
        "snooper_enabled": False,
        "count": 1,
    }


def get_default_mev_params():
    return {
        "mev_relay_image": MEV_BOOST_RELAY_DEFAULT_IMAGE,
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
            participant["beacon_extra_params"].append("--payload-builder=true")
            participant["beacon_extra_params"].append(
                "--payload-builder-url={0}".format(mev_url)
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
        mev_participant = default_participant()
        mev_participant.update(
            {
                # TODO replace with actual when flashbots/builder is published
                "el_client_image": parsed_arguments_dict["mev_params"][
                    "mev_builder_image"
                ],
                "cl_client_image": "sigp/lighthouse",
                "beacon_extra_params": [
                    "--always-prepare-payload",
                    "--prepare-payload-lookahead",
                    "12000",
                    "--disable-peer-scoring",
                ],
                # TODO(maybe) make parts of this more passable like the mev-relay-endpoint & forks
                "el_extra_params": [
                    "--builder",
                    "--builder.remote_relay_endpoint=http://mev-relay-api:9062",
                    "--builder.beacon_endpoints=http://cl-{0}-lighthouse-geth:4000".format(
                        num_participants + 1
                    ),
                    "--builder.bellatrix_fork_version=0x30000038",
                    "--builder.genesis_fork_version=0x10000038",
                    "--builder.genesis_validators_root={0}".format(
                        package_io_constants.GENESIS_VALIDATORS_ROOT_PLACEHOLDER
                    ),
                    '--miner.extradata="Illuminate Dmocratize Dstribute"',
                    "--builder.algotype=greedy",
                ]
                + parsed_arguments_dict["mev_params"]["mev_builder_extra_args"],
                "el_extra_env_vars": {
                    "BUILDER_TX_SIGNING_KEY": "0x"
                    + genesis_constants.PRE_FUNDED_ACCOUNTS[0].private_key
                },
                "validator_count": 0,
            }
        )

        parsed_arguments_dict["participants"].append(mev_participant)

    return parsed_arguments_dict


def deep_copy_participant(participant):
    part = {}
    for k, v in participant.items():
        if type(v) == type([]):
            part[k] = list(v)
        else:
            part[k] = v
    return part
