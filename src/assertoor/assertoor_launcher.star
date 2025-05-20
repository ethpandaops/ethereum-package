shared_utils = import_module("../shared_utils/shared_utils.star")
static_files = import_module("../static_files/static_files.star")
constants = import_module("../package_io/constants.star")
SERVICE_NAME = "assertoor"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 8080

ASSERTOOR_CONFIG_FILENAME = "assertoor-config.yaml"

ASSERTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE = "/config"
ASSERTOOR_TESTS_MOUNT_DIRPATH_ON_SERVICE = "/tests"

VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE = "/validator-ranges"
VALIDATOR_RANGES_ARTIFACT_NAME = "validator-ranges"

# The min/max CPU/memory that assertoor can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 8192

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_assertoor(
    plan,
    config_template,
    participant_contexts,
    participant_configs,
    network_params,
    assertoor_params,
    port_publisher,
    index,
    global_node_selectors,
):
    all_client_info = []
    clients_with_validators = []
    clients_with_el_snooper = []
    clients_with_cl_snooper = []

    public_ports = shared_utils.get_additional_service_standard_public_port(
        port_publisher,
        constants.HTTP_PORT_ID,
        index,
        0,
    )

    for index, participant in enumerate(participant_contexts):
        (
            full_name,
            cl_client,
            el_client,
            participant_config,
        ) = shared_utils.get_client_names(
            participant, index, participant_contexts, participant_configs
        )

        client_info = new_client_info(
            cl_client.beacon_http_url,
            el_client.ip_addr,
            el_client.rpc_port_num,
            participant.snooper_engine_context,
            participant.snooper_beacon_context,
            full_name,
        )

        all_client_info.append(client_info)

        if participant_config.validator_count != 0:
            clients_with_validators.append(client_info)
        if participant.snooper_engine_context != None:
            clients_with_el_snooper.append(client_info)
        if participant.snooper_beacon_context != None:
            clients_with_cl_snooper.append(client_info)

    template_data = new_config_template_data(
        HTTP_PORT_NUMBER,
        all_client_info,
        clients_with_validators,
        clients_with_el_snooper,
        clients_with_cl_snooper,
        assertoor_params,
    )

    template_and_data = shared_utils.new_template_and_data(
        config_template, template_data
    )
    template_and_data_by_rel_dest_filepath = {}
    template_and_data_by_rel_dest_filepath[
        ASSERTOOR_CONFIG_FILENAME
    ] = template_and_data

    config_files_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, "assertoor-config"
    )

    tests_config_artifacts_name = plan.upload_files(
        static_files.ASSERTOOR_TESTS_CONFIG_DIRPATH, name="assertoor-tests"
    )

    config = get_config(
        config_files_artifact_name,
        tests_config_artifacts_name,
        network_params,
        assertoor_params,
        public_ports,
        global_node_selectors,
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    tests_config_artifacts_name,
    network_params,
    assertoor_params,
    public_ports,
    node_selectors,
):
    config_file_path = shared_utils.path_join(
        ASSERTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        ASSERTOOR_CONFIG_FILENAME,
    )

    IMAGE_NAME = assertoor_params.image

    if assertoor_params.image == constants.DEFAULT_ASSERTOOR_IMAGE:
        if network_params.fulu_fork_epoch < constants.FAR_FUTURE_EPOCH:
            IMAGE_NAME = "ethpandaops/assertoor:fulu-support"

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
        public_ports=public_ports,
        files={
            ASSERTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE: config_files_artifact_name,
            ASSERTOOR_TESTS_MOUNT_DIRPATH_ON_SERVICE: tests_config_artifacts_name,
            VALIDATOR_RANGES_MOUNT_DIRPATH_ON_SERVICE: VALIDATOR_RANGES_ARTIFACT_NAME,
        },
        cmd=["--config", config_file_path],
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )


def new_config_template_data(
    listen_port_num,
    all_client_info,
    clients_with_validators,
    clients_with_el_snooper,
    clients_with_cl_snooper,
    assertoor_params,
):
    additional_tests = []
    for index, testcfg in enumerate(assertoor_params.tests):
        if type(testcfg) == "dict":
            additional_tests.append(json.encode(testcfg))
        else:
            additional_tests.append(
                json.encode(
                    {
                        "file": testcfg,
                    }
                )
            )

    return {
        "ListenPortNum": listen_port_num,
        "ClientInfo": all_client_info,
        "ValidatorClientInfo": clients_with_validators,
        "ElSnooperClientInfo": clients_with_el_snooper,
        "ClSnooperClientInfo": clients_with_cl_snooper,
        "RunStabilityCheck": assertoor_params.run_stability_check,
        "RunBlockProposalCheck": assertoor_params.run_block_proposal_check,
        "RunLifecycleTest": assertoor_params.run_lifecycle_test,
        "RunTransactionTest": assertoor_params.run_transaction_test,
        "RunBlobTransactionTest": assertoor_params.run_blob_transaction_test,
        "RunOpcodesTransactionTest": assertoor_params.run_opcodes_transaction_test,
        "AdditionalTests": additional_tests,
    }


def new_client_info(
    beacon_http_url,
    el_ip_addr,
    el_port_num,
    el_snooper_context,
    cl_snooper_context,
    full_name,
):
    el_snooper_enabled = False
    el_snooper_url = ""
    cl_snooper_enabled = False
    cl_snooper_url = ""

    if el_snooper_context != None:
        el_snooper_enabled = True
        el_snooper_url = "http://{0}:{1}".format(
            el_snooper_context.ip_addr,
            el_snooper_context.engine_rpc_port_num,
        )
    if cl_snooper_context != None:
        cl_snooper_enabled = True
        cl_snooper_url = "http://{0}:{1}".format(
            cl_snooper_context.ip_addr,
            cl_snooper_context.beacon_rpc_port_num,
        )

    return {
        "CL_HTTP_URL": beacon_http_url,
        "ELIPAddr": el_ip_addr,
        "ELPortNum": el_port_num,
        "ELSnooperEnabled": el_snooper_enabled,
        "ELSnooperUrl": el_snooper_url,
        "CLSnooperEnabled": cl_snooper_enabled,
        "CLSnooperUrl": cl_snooper_url,
        "Name": full_name,
    }
