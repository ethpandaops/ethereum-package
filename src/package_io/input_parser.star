constants = import_module("./constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
genesis_constants = import_module(
    "../prelaunch_data_generator/genesis_constants/genesis_constants.star"
)

DEFAULT_EL_IMAGES = {
    "geth": "ethereum/client-go:latest",
    "erigon": "ethpandaops/erigon:devel",
    "nethermind": "nethermindeth/nethermind:master",
    "besu": "hyperledger/besu:latest",
    "reth": "ghcr.io/paradigmxyz/reth",
    "ethereumjs": "ethpandaops/ethereumjs:master",
}

DEFAULT_CL_IMAGES = {
    "lighthouse": "sigp/lighthouse:latest",
    "teku": "consensys/teku:latest",
    "nimbus": "statusim/nimbus-eth2:multiarch-latest",
    "prysm": "gcr.io/prysmaticlabs/prysm/beacon-chain:latest,gcr.io/prysmaticlabs/prysm/validator:latest",
    "lodestar": "chainsafe/lodestar:latest",
}

MEV_BOOST_RELAY_DEFAULT_IMAGE = "flashbots/mev-boost-relay:0.27"

MEV_BOOST_RELAY_IMAGE_NON_ZERO_CAPELLA = "flashbots/mev-boost-relay:0.26"

NETHERMIND_NODE_NAME = "nethermind"
NIMBUS_NODE_NAME = "nimbus"

# Placeholder value for the deneb fork epoch if electra is being run
# TODO: This is a hack, and should be removed once we electra is rebased on deneb
HIGH_DENEB_VALUE_FORK_VERKLE = 20000

# MEV Params
FLASHBOTS_MEV_BOOST_PORT = 18550
MEV_BOOST_SERVICE_NAME_PREFIX = "mev-boost"

# Minimum number of validators required for a network to be valid is 64
MIN_VALIDATORS = 64

DEFAULT_ADDITIONAL_SERVICES = [
    "tx_spammer",
    "blob_spammer",
    "el_forkmon",
    "beacon_metrics_gazer",
    "dora",
    "blockscout",    
    "prometheus_grafana",
]

ATTR_TO_BE_SKIPPED_AT_ROOT = (
    "network_params",
    "participants",
    "mev_params",
    "assertoor_params",
    "goomy_blob_params",
    "tx_spammer_params",
    "custom_flood_params",
    "xatu_sentry_params",
)


def input_parser(plan, input_args):
    result = parse_network_params(input_args)

    # add default eth2 input params
    result["mev_type"] = None
    result["mev_params"] = get_default_mev_params()
    if result["network_params"]["network"] == "kurtosis":
        result["additional_services"] = DEFAULT_ADDITIONAL_SERVICES
    else:
        result["additional_services"] = []
    result["grafana_additional_dashboards"] = []
    result["tx_spammer_params"] = get_default_tx_spammer_params()
    result["custom_flood_params"] = get_default_custom_flood_params()
    result["disable_peer_scoring"] = False
    result["goomy_blob_params"] = get_default_goomy_blob_params()
    result["assertoor_params"] = get_default_assertoor_params()
    result["xatu_sentry_params"] = get_default_xatu_sentry_params()
    result["persistent"] = False

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
        elif attr == "tx_spammer_params":
            for sub_attr in input_args["tx_spammer_params"]:
                sub_value = input_args["tx_spammer_params"][sub_attr]
                result["tx_spammer_params"][sub_attr] = sub_value
        elif attr == "custom_flood_params":
            for sub_attr in input_args["custom_flood_params"]:
                sub_value = input_args["custom_flood_params"][sub_attr]
                result["custom_flood_params"][sub_attr] = sub_value
        elif attr == "goomy_blob_params":
            for sub_attr in input_args["goomy_blob_params"]:
                sub_value = input_args["goomy_blob_params"][sub_attr]
                result["goomy_blob_params"][sub_attr] = sub_value
        elif attr == "assertoor_params":
            for sub_attr in input_args["assertoor_params"]:
                sub_value = input_args["assertoor_params"][sub_attr]
                result["assertoor_params"][sub_attr] = sub_value
        elif attr == "xatu_sentry_params":
            for sub_attr in input_args["xatu_sentry_params"]:
                sub_value = input_args["xatu_sentry_params"][sub_attr]
                result["xatu_sentry_params"][sub_attr] = sub_value

    if result.get("disable_peer_scoring"):
        result = enrich_disable_peer_scoring(result)

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
        and result["mev_params"]["mev_relay_image"]
        == MEV_BOOST_RELAY_IMAGE_NON_ZERO_CAPELLA
    ):
        fail(
            "The default MEV image {0} requires a non-zero value for capella fork epoch set via network_params.capella_fork_epoch".format(
                MEV_BOOST_RELAY_IMAGE_NON_ZERO_CAPELLA
            )
        )

    return struct(
        participants=[
            struct(
                el_client_type=participant["el_client_type"],
                el_client_image=participant["el_client_image"],
                el_client_log_level=participant["el_client_log_level"],
                el_client_volume_size=participant["el_client_volume_size"],
                el_extra_params=participant["el_extra_params"],
                el_extra_env_vars=participant["el_extra_env_vars"],
                el_extra_labels=participant["el_extra_labels"],
                cl_client_type=participant["cl_client_type"],
                cl_client_image=participant["cl_client_image"],
                cl_client_log_level=participant["cl_client_log_level"],
                cl_client_volume_size=participant["cl_client_volume_size"],
                cl_split_mode_enabled=participant["cl_split_mode_enabled"],
                beacon_extra_params=participant["beacon_extra_params"],
                beacon_extra_labels=participant["beacon_extra_labels"],
                validator_extra_params=participant["validator_extra_params"],
                validator_extra_labels=participant["validator_extra_labels"],
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
                ethereum_metrics_exporter_enabled=participant[
                    "ethereum_metrics_exporter_enabled"
                ],
                xatu_sentry_enabled=participant["xatu_sentry_enabled"],
                prometheus_config=struct(
                    scrape_interval=participant["prometheus_config"]["scrape_interval"],
                    labels=participant["prometheus_config"]["labels"],
                ),
                blobber_enabled=participant["blobber_enabled"],
                blobber_extra_params=participant["blobber_extra_params"],
            )
            for participant in result["participants"]
        ],
        network_params=struct(
            preregistered_validator_keys_mnemonic=result["network_params"][
                "preregistered_validator_keys_mnemonic"
            ],
            preregistered_validator_count=result["network_params"][
                "preregistered_validator_count"
            ],
            num_validator_keys_per_node=result["network_params"][
                "num_validator_keys_per_node"
            ],
            network_id=result["network_params"]["network_id"],
            deposit_contract_address=result["network_params"][
                "deposit_contract_address"
            ],
            seconds_per_slot=result["network_params"]["seconds_per_slot"],
            genesis_delay=result["network_params"]["genesis_delay"],
            max_churn=result["network_params"]["max_churn"],
            ejection_balance=result["network_params"]["ejection_balance"],
            eth1_follow_distance=result["network_params"]["eth1_follow_distance"],
            capella_fork_epoch=result["network_params"]["capella_fork_epoch"],
            deneb_fork_epoch=result["network_params"]["deneb_fork_epoch"],
            electra_fork_epoch=result["network_params"]["electra_fork_epoch"],
            network=result["network_params"]["network"],
        ),
        mev_params=struct(
            mev_relay_image=result["mev_params"]["mev_relay_image"],
            mev_builder_image=result["mev_params"]["mev_builder_image"],
            mev_builder_cl_image=result["mev_params"]["mev_builder_cl_image"],
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
        ),
        tx_spammer_params=struct(
            tx_spammer_extra_args=result["tx_spammer_params"]["tx_spammer_extra_args"],
        ),
        goomy_blob_params=struct(
            goomy_blob_args=result["goomy_blob_params"]["goomy_blob_args"],
        ),
        assertoor_params=struct(
            run_stability_check=result["assertoor_params"]["run_stability_check"],
            run_block_proposal_check=result["assertoor_params"][
                "run_block_proposal_check"
            ],
            run_lifecycle_test=result["assertoor_params"]["run_lifecycle_test"],
            run_transaction_test=result["assertoor_params"]["run_transaction_test"],
            run_blob_transaction_test=result["assertoor_params"][
                "run_blob_transaction_test"
            ],
            run_opcodes_transaction_test=result["assertoor_params"][
                "run_opcodes_transaction_test"
            ],
            tests=result["assertoor_params"]["tests"],
        ),
        custom_flood_params=struct(
            interval_between_transactions=result["custom_flood_params"][
                "interval_between_transactions"
            ],
        ),
        additional_services=result["additional_services"],
        wait_for_finalization=result["wait_for_finalization"],
        global_client_log_level=result["global_client_log_level"],
        mev_type=result["mev_type"],
        snooper_enabled=result["snooper_enabled"],
        ethereum_metrics_exporter_enabled=result["ethereum_metrics_exporter_enabled"],
        xatu_sentry_enabled=result["xatu_sentry_enabled"],
        parallel_keystore_generation=result["parallel_keystore_generation"],
        grafana_additional_dashboards=result["grafana_additional_dashboards"],
        disable_peer_scoring=result["disable_peer_scoring"],
        persistent=result["persistent"],
        xatu_sentry_params=struct(
            xatu_sentry_image=result["xatu_sentry_params"]["xatu_sentry_image"],
            xatu_server_addr=result["xatu_sentry_params"]["xatu_server_addr"],
            xatu_server_headers=result["xatu_sentry_params"]["xatu_server_headers"],
            beacon_subscriptions=result["xatu_sentry_params"]["beacon_subscriptions"],
            xatu_server_tls=result["xatu_sentry_params"]["xatu_server_tls"],
        ),
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

        if participant["cl_split_mode_enabled"] and cl_client_type not in (
            "nimbus",
            "teku",
        ):
            fail(
                "split mode is only supported for nimbus and teku clients, but you specified {0}".format(
                    cl_client_type
                )
            )

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

        ethereum_metrics_exporter_enabled = participant[
            "ethereum_metrics_exporter_enabled"
        ]

        xatu_sentry_enabled = participant["xatu_sentry_enabled"]

        blobber_enabled = participant["blobber_enabled"]
        if blobber_enabled:
            # unless we are running lighthouse, we don't support blobber
            if participant["cl_client_type"] != "lighthouse":
                fail(
                    "blobber is not supported for {0} client".format(
                        participant["cl_client_type"]
                    )
                )

        if ethereum_metrics_exporter_enabled == False:
            default_ethereum_metrics_exporter_enabled = result[
                "ethereum_metrics_exporter_enabled"
            ]
            if default_ethereum_metrics_exporter_enabled:
                participant[
                    "ethereum_metrics_exporter_enabled"
                ] = default_ethereum_metrics_exporter_enabled

        if xatu_sentry_enabled == False:
            default_xatu_sentry_enabled = result["xatu_sentry_enabled"]
            if default_xatu_sentry_enabled:
                participant["xatu_sentry_enabled"] = default_xatu_sentry_enabled

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

    if result["network_params"]["network"] == "kurtosis":
        if (
            result["network_params"]["preregistered_validator_keys_mnemonic"].strip()
            == ""
        ):
            fail(
                "preregistered_validator_keys_mnemonic is empty or spaces it needs to be of non zero length"
            )

    if result["network_params"]["seconds_per_slot"] == 0:
        fail("seconds_per_slot is 0 needs to be > 0 ")

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

    if result["network_params"]["network"] == "kurtosis":
        if MIN_VALIDATORS > actual_num_validators:
            fail(
                "We require at least {0} validators but got {1}".format(
                    MIN_VALIDATORS, actual_num_validators
                )
            )
    else:
        # Don't allow validators on non-kurtosis networks
        for participant in result["participants"]:
            participant["validator_count"] = 0

    return result


def get_client_log_level_or_default(
    participant_log_level, global_log_level, client_log_levels
):
    log_level = client_log_levels.get(participant_log_level, "")
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
        "ethereum_metrics_exporter_enabled": False,
        "xatu_sentry_enabled": False,
        "parallel_keystore_generation": False,
        "disable_peer_scoring": False,
    }


def default_network_params():
    # this is temporary till we get params working
    return {
        "preregistered_validator_keys_mnemonic": "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete",
        "preregistered_validator_count": 0,
        "num_validator_keys_per_node": 64,
        "network_id": "3151908",
        "deposit_contract_address": "0x4242424242424242424242424242424242424242",
        "seconds_per_slot": 12,
        "genesis_delay": 20,
        "max_churn": 8,
        "ejection_balance": 16000000000,
        "eth1_follow_distance": 2048,
        "capella_fork_epoch": 0,
        "deneb_fork_epoch": 500,
        "electra_fork_epoch": None,
        "network": "kurtosis",
    }


def default_participant():
    return {
        "el_client_type": "geth",
        "el_client_image": "",
        "el_client_log_level": "",
        "el_client_volume_size": 0,
        "el_extra_params": [],
        "el_extra_env_vars": {},
        "el_extra_labels": {},
        "cl_client_type": "lighthouse",
        "cl_client_image": "",
        "cl_client_log_level": "",
        "cl_client_volume_size": 0,
        "cl_split_mode_enabled": False,
        "beacon_extra_params": [],
        "beacon_extra_labels": {},
        "validator_extra_params": [],
        "validator_extra_labels": {},
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
        "ethereum_metrics_exporter_enabled": False,
        "xatu_sentry_enabled": False,
        "count": 1,
        "prometheus_config": {
            "scrape_interval": "15s",
            "labels": None,
        },
        "blobber_enabled": False,
        "blobber_extra_params": [],
    }


def get_default_mev_params():
    return {
        "mev_relay_image": MEV_BOOST_RELAY_DEFAULT_IMAGE,
        "mev_builder_image": "flashbots/builder:latest",
        "mev_builder_cl_image": "sigp/lighthouse:latest",
        "mev_boost_image": "flashbots/mev-boost",
        "mev_relay_api_extra_args": [],
        "mev_relay_housekeeper_extra_args": [],
        "mev_relay_website_extra_args": [],
        "mev_builder_extra_args": [],
        "mev_flood_image": "flashbots/mev-flood",
        "mev_flood_extra_args": [],
        "mev_flood_seconds_per_bundle": 15,
        "mev_builder_prometheus_config": {
            "scrape_interval": "15s",
            "labels": None,
        },
    }


def get_default_tx_spammer_params():
    return {"tx_spammer_extra_args": []}


def get_default_goomy_blob_params():
    return {"goomy_blob_args": []}


def get_default_assertoor_params():
    return {
        "run_stability_check": True,
        "run_block_proposal_check": True,
        "run_lifecycle_test": False,
        "run_transaction_test": False,
        "run_blob_transaction_test": False,
        "run_opcodes_transaction_test": False,
        "tests": [],
    }


def get_default_xatu_sentry_params():
    return {
        "xatu_sentry_image": "ethpandaops/xatu:latest",
        "xatu_server_addr": "localhost:8080",
        "xatu_server_headers": {},
        "xatu_server_tls": False,
        "beacon_subscriptions": [
            "attestation",
            "block",
            "chain_reorg",
            "finalized_checkpoint",
            "head",
            "voluntary_exit",
            "contribution_and_proof",
            "blob_sidecar",
        ],
    }


def get_default_custom_flood_params():
    # this is a simple script that increases the balance of the coinbase address at a cadence
    return {"interval_between_transactions": 1}


def enrich_disable_peer_scoring(parsed_arguments_dict):
    for index, participant in enumerate(parsed_arguments_dict["participants"]):
        if participant["cl_client_type"] == "lighthouse":
            participant["beacon_extra_params"].append("--disable-peer-scoring")
        if participant["cl_client_type"] == "prysm":
            participant["beacon_extra_params"].append("--disable-peer-scorer")
        if participant["cl_client_type"] == "teku":
            participant["beacon_extra_params"].append("--Xp2p-gossip-scoring-enabled")
        if participant["cl_client_type"] == "lodestar":
            participant["beacon_extra_params"].append("--disablePeerScoring")
    return parsed_arguments_dict


# TODO perhaps clean this up into a map
def enrich_mev_extra_params(parsed_arguments_dict, mev_prefix, mev_port, mev_type):
    for index, participant in enumerate(parsed_arguments_dict["participants"]):
        index_str = shared_utils.zfill_custom(
            index + 1, len(str(len(parsed_arguments_dict["participants"])))
        )
        mev_url = "http://{0}-{1}-{2}-{3}:{4}".format(
            MEV_BOOST_SERVICE_NAME_PREFIX,
            index_str,
            participant["cl_client_type"],
            participant["el_client_type"],
            mev_port,
        )

        if participant["cl_client_type"] == "lighthouse":
            participant["validator_extra_params"].append("--builder-proposals")
            participant["beacon_extra_params"].append("--builder={0}".format(mev_url))
        if participant["cl_client_type"] == "lodestar":
            participant["validator_extra_params"].append("--builder")
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
    index_str = shared_utils.zfill_custom(
        num_participants + 1, len(str(num_participants + 1))
    )
    if mev_type == "full":
        mev_participant = default_participant()
        mev_participant["el_client_type"] = (
            mev_participant["el_client_type"] + "-builder"
        )
        mev_participant.update(
            {
                "el_client_image": parsed_arguments_dict["mev_params"][
                    "mev_builder_image"
                ],
                "cl_client_image": parsed_arguments_dict["mev_params"][
                    "mev_builder_cl_image"
                ],
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
                    "--builder.beacon_endpoints=http://cl-{0}-lighthouse-geth-builder:4000".format(
                        index_str
                    ),
                    "--builder.bellatrix_fork_version={0}".format(
                        constants.BELLATRIX_FORK_VERSION
                    ),
                    "--builder.genesis_fork_version={0}".format(
                        constants.GENESIS_FORK_VERSION
                    ),
                    "--builder.genesis_validators_root={0}".format(
                        constants.GENESIS_VALIDATORS_ROOT_PLACEHOLDER
                    ),
                    '--miner.extradata="Illuminate Dmocratize Dstribute"',
                    "--builder.algotype=greedy",
                    "--metrics.builder",
                ]
                + parsed_arguments_dict["mev_params"]["mev_builder_extra_args"],
                "el_extra_env_vars": {
                    "BUILDER_TX_SIGNING_KEY": "0x"
                    + genesis_constants.PRE_FUNDED_ACCOUNTS[0].private_key
                },
                "validator_count": 0,
                "prometheus_config": parsed_arguments_dict["mev_params"][
                    "mev_builder_prometheus_config"
                ],
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
