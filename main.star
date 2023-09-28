parse_input = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/package_io/parse_input.star"
)

participant_network = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/participant_network.star"
)

static_files = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/static_files/static_files.star"
)
genesis_constants = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/prelaunch_data_generator/genesis_constants/genesis_constants.star"
)

transaction_spammer = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/transaction_spammer/transaction_spammer.star"
)
blob_spammer = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/blob_spammer/blob_spammer.star"
)
cl_forkmon = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/cl_forkmon/cl_forkmon_launcher.star"
)
el_forkmon = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/el_forkmon/el_forkmon_launcher.star"
)
beacon_metrics_gazer = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/beacon_metrics_gazer/beacon_metrics_gazer_launcher.star"
)
dora = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/dora/dora_launcher.star"
)
prometheus = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/prometheus/prometheus_launcher.star"
)
grafana = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/grafana/grafana_launcher.star"
)
mev_boost_launcher_module = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/mev_boost/mev_boost_launcher.star"
)
mock_mev_launcher_module = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/mock_mev/mock_mev_launcher.star"
)
mev_relay_launcher_module = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/mev_relay/mev_relay_launcher.star"
)
mev_flood_module = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/mev_flood/mev_flood_launcher.star"
)
mev_custom_flood_module = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/mev_custom_flood/mev_custom_flood_launcher.star"
)

GRAFANA_USER = "admin"
GRAFANA_PASSWORD = "admin"
GRAFANA_DASHBOARD_PATH_URL = "/d/QdTOwy-nz/eth2-merge-kurtosis-module-dashboard?orgId=1"

FIRST_NODE_FINALIZATION_FACT = "cl-boot-finalization-fact"
HTTP_PORT_ID_FOR_FACT = "http"

MEV_BOOST_SHOULD_CHECK_RELAY = True
MOCK_MEV_TYPE = "mock"
FULL_MEV_TYPE = "full"
PATH_TO_PARSED_BEACON_STATE = "/genesis/output/parsedBeaconState.json"


def run(plan, args={}):
    args_with_right_defaults = parse_input.parse_input(plan, args)

    num_participants = len(args_with_right_defaults.participants)
    network_params = args_with_right_defaults.network_params
    mev_params = args_with_right_defaults.mev_params
    parallel_keystore_generation = args_with_right_defaults.parallel_keystore_generation

    grafana_datasource_config_template = read_file(
        static_files.GRAFANA_DATASOURCE_CONFIG_TEMPLATE_FILEPATH
    )
    grafana_dashboards_config_template = read_file(
        static_files.GRAFANA_DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH
    )
    prometheus_config_template = read_file(
        static_files.PROMETHEUS_CONFIG_TEMPLATE_FILEPATH
    )
    prometheus_additional_metrics_jobs = []

    plan.print("Read the prometheus, grafana templates")

    plan.print(
        "Launching participant network with {0} participants and the following network params {1}".format(
            num_participants, network_params
        )
    )
    (
        all_participants,
        cl_genesis_timestamp,
        genesis_validators_root,
    ) = participant_network.launch_participant_network(
        plan,
        args_with_right_defaults.participants,
        network_params,
        args_with_right_defaults.global_client_log_level,
        parallel_keystore_generation,
    )

    plan.print(
        "NODE JSON RPC URI: '{0}:{1}'".format(
            all_participants[0].el_client_context.ip_addr,
            all_participants[0].el_client_context.rpc_port_num,
        )
    )

    all_el_client_contexts = []
    all_cl_client_contexts = []
    for participant in all_participants:
        all_el_client_contexts.append(participant.el_client_context)
        all_cl_client_contexts.append(participant.cl_client_context)

    mev_endpoints = []
    # passed external relays get priority
    # perhaps add mev_type External or remove this
    if (
        hasattr(participant, "builder_network_params")
        and participant.builder_network_params != None
    ):
        mev_endpoints = participant.builder_network_params.relay_end_points
    # otherwise dummy relays spinup if chosen
    elif (
        args_with_right_defaults.mev_type
        and args_with_right_defaults.mev_type == MOCK_MEV_TYPE
    ):
        el_uri = "{0}:{1}".format(
            all_el_client_contexts[0].ip_addr,
            all_el_client_contexts[0].engine_rpc_port_num,
        )
        beacon_uri = "{0}:{1}".format(
            all_cl_client_contexts[0].ip_addr, all_cl_client_contexts[0].http_port_num
        )
        jwt_secret = all_el_client_contexts[0].jwt_secret
        endpoint = mock_mev_launcher_module.launch_mock_mev(
            plan,
            el_uri,
            beacon_uri,
            jwt_secret,
            args_with_right_defaults.global_client_log_level,
        )
        mev_endpoints.append(endpoint)
    elif (
        args_with_right_defaults.mev_type
        and args_with_right_defaults.mev_type == FULL_MEV_TYPE
    ):
        el_uri = "http://{0}:{1}".format(
            all_el_client_contexts[0].ip_addr, all_el_client_contexts[0].rpc_port_num
        )
        builder_uri = "http://{0}:{1}".format(
            all_el_client_contexts[-1].ip_addr, all_el_client_contexts[-1].rpc_port_num
        )
        beacon_uris = ','.join([
            "http://{0}:{1}".format(context.ip_addr, context.http_port_num)
            for context in all_cl_client_contexts
        ])
        first_cl_client = all_cl_client_contexts[0]
        first_client_beacon_name = first_cl_client.beacon_service_name
        mev_flood_module.launch_mev_flood(
            plan,
            mev_params.mev_flood_image,
            el_uri,
            genesis_constants.PRE_FUNDED_ACCOUNTS,
        )
        epoch_recipe = GetHttpRequestRecipe(
            endpoint="/eth/v2/beacon/blocks/head",
            port_id=HTTP_PORT_ID_FOR_FACT,
            extract={"epoch": ".data.message.body.attestations[0].data.target.epoch"},
        )
        plan.wait(
            recipe=epoch_recipe,
            field="extract.epoch",
            assertion=">=",
            target_value=str(network_params.capella_fork_epoch),
            timeout="20m",
            service_name=first_client_beacon_name,
        )
        endpoint = mev_relay_launcher_module.launch_mev_relay(
            plan,
            mev_params,
            network_params.network_id,
            beacon_uris,
            genesis_validators_root,
            builder_uri,
            network_params.seconds_per_slot,
            network_params.slots_per_epoch,
        )
        mev_flood_module.spam_in_background(
            plan,
            el_uri,
            mev_params.mev_flood_extra_args,
            mev_params.mev_flood_seconds_per_bundle,
            genesis_constants.PRE_FUNDED_ACCOUNTS,
        )
        if args_with_right_defaults.mev_params.launch_custom_flood:
            mev_custom_flood_module.spam_in_background(
                plan,
                genesis_constants.PRE_FUNDED_ACCOUNTS[-1].private_key,
                genesis_constants.PRE_FUNDED_ACCOUNTS[0].address,
                el_uri,
            )
        mev_endpoints.append(endpoint)

    # spin up the mev boost contexts if some endpoints for relays have been passed
    all_mevboost_contexts = []
    if mev_endpoints:
        for index, participant in enumerate(all_participants):
            if args_with_right_defaults.participants[index].validator_count != 0:
                mev_boost_launcher = mev_boost_launcher_module.new_mev_boost_launcher(
                    MEV_BOOST_SHOULD_CHECK_RELAY, mev_endpoints
                )
                mev_boost_service_name = "{0}{1}".format(
                    parse_input.MEV_BOOST_SERVICE_NAME_PREFIX, index
                )
                mev_boost_context = mev_boost_launcher_module.launch(
                    plan,
                    mev_boost_launcher,
                    mev_boost_service_name,
                    network_params.network_id,
                    mev_params.mev_boost_image,
                )
                all_mevboost_contexts.append(mev_boost_context)

    if not args_with_right_defaults.launch_additional_services:
        return
    launch_prometheus_grafana = False
    for additional_service in args_with_right_defaults.additional_services:
        if additional_service == "tx_spammer":
            plan.print("Launching transaction spammer")
            tx_spammer_params = args_with_right_defaults.tx_spammer_params
            transaction_spammer.launch_transaction_spammer(
                plan,
                genesis_constants.PRE_FUNDED_ACCOUNTS,
                all_el_client_contexts[0],
                tx_spammer_params,
            )
            plan.print("Succesfully launched transaction spammer")
        elif additional_service == "blob_spammer":
            plan.print("Launching Blob spammer")
            blob_spammer.launch_blob_spammer(
                plan,
                genesis_constants.PRE_FUNDED_ACCOUNTS,
                all_el_client_contexts[0],
                all_cl_client_contexts[0],
                network_params.deneb_fork_epoch,
                network_params.seconds_per_slot,
                network_params.slots_per_epoch,
                network_params.genesis_delay,
            )
            plan.print("Succesfully launched blob spammer")
        # We need a way to do time.sleep
        # TODO add code that waits for CL genesis
        elif additional_service == "cl_forkmon":
            plan.print("Launching cl forkmon")
            cl_forkmon_config_template = read_file(
                static_files.CL_FORKMON_CONFIG_TEMPLATE_FILEPATH
            )
            cl_forkmon.launch_cl_forkmon(
                plan,
                cl_forkmon_config_template,
                all_cl_client_contexts,
                cl_genesis_timestamp,
                network_params.seconds_per_slot,
                network_params.slots_per_epoch,
            )
            plan.print("Succesfully launched consensus layer forkmon")
        elif additional_service == "el_forkmon":
            plan.print("Launching el forkmon")
            el_forkmon_config_template = read_file(
                static_files.EL_FORKMON_CONFIG_TEMPLATE_FILEPATH
            )
            el_forkmon.launch_el_forkmon(
                plan, el_forkmon_config_template, all_el_client_contexts
            )
            plan.print("Succesfully launched execution layer forkmon")
        elif additional_service == "beacon_metrics_gazer":
            plan.print("Launching beacon metrics gazer")
            beacon_metrics_gazer_config_template = read_file(
                static_files.BEACON_METRICS_GAZER_CONFIG_TEMPLATE_FILEPATH
            )
            beacon_metrics_gazer_prometheus_metrics_job = (
                beacon_metrics_gazer.launch_beacon_metrics_gazer(
                    plan,
                    beacon_metrics_gazer_config_template,
                    all_cl_client_contexts,
                    args_with_right_defaults.participants,
                    network_params,
                )
            )
            launch_prometheus_grafana = True
            prometheus_additional_metrics_jobs.append(
                beacon_metrics_gazer_prometheus_metrics_job
            )
            plan.print("Succesfully launched beacon metrics gazer")
        elif additional_service == "dora":
            plan.print("Launching dora")
            dora_config_template = read_file(static_files.DORA_CONFIG_TEMPLATE_FILEPATH)
            dora.launch_dora(plan, dora_config_template, all_cl_client_contexts)
            plan.print("Succesfully launched dora")
        elif additional_service == "prometheus_grafana":
            # Allow prometheus to be launched last so is able to collect metrics from other services
            launch_prometheus_grafana = True
        else:
            fail("Invalid additional service %s" % (additional_service))
    if launch_prometheus_grafana:
        plan.print("Launching prometheus...")
        prometheus_private_url = prometheus.launch_prometheus(
            plan,
            prometheus_config_template,
            all_el_client_contexts,
            all_cl_client_contexts,
            prometheus_additional_metrics_jobs,
        )

        plan.print("Launching grafana...")
        grafana.launch_grafana(
            plan,
            grafana_datasource_config_template,
            grafana_dashboards_config_template,
            prometheus_private_url,
        )
        plan.print("Succesfully launched grafana")

    if args_with_right_defaults.wait_for_finalization:
        plan.print("Waiting for the first finalized epoch")
        first_cl_client = all_cl_client_contexts[0]
        first_client_beacon_name = first_cl_client.beacon_service_name
        epoch_recipe = GetHttpRequestRecipe(
            endpoint="/eth/v1/beacon/states/head/finality_checkpoints",
            port_id=HTTP_PORT_ID_FOR_FACT,
            extract={"finalized_epoch": ".data.finalized.epoch"},
        )
        plan.wait(
            recipe=epoch_recipe,
            field="extract.finalized_epoch",
            assertion="!=",
            target_value="0",
            timeout="40m",
            service_name=first_client_beacon_name,
        )
        plan.print("First finalized epoch occurred successfully")

    grafana_info = struct(
        dashboard_path=GRAFANA_DASHBOARD_PATH_URL,
        user=GRAFANA_USER,
        password=GRAFANA_PASSWORD,
    )
    output = struct(grafana_info=grafana_info)

    return output
