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
MAX_MEMORY = 2048

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
):
    all_client_info = []
    validator_client_info = []

    for index, participant in enumerate(participant_contexts):
        participant_config = participant_configs[index]
        cl_client = participant.cl_client_context
        el_client = participant.el_client_context

        all_client_info.append(
            new_client_info(
                cl_client.ip_addr,
                cl_client.http_port_num,
                el_client.ip_addr,
                el_client.rpc_port_num,
                cl_client.beacon_service_name,
            )
        )

        if participant_config.validator_count != 0:
            validator_client_info.append(
                new_client_info(
                    cl_client.ip_addr,
                    cl_client.http_port_num,
                    el_client.ip_addr,
                    el_client.rpc_port_num,
                    cl_client.beacon_service_name,
                )
            )

    template_data = new_config_template_data(
        HTTP_PORT_NUMBER, all_client_info, validator_client_info, assertoor_params
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
    )

    plan.add_service(SERVICE_NAME, config)


def get_config(
    config_files_artifact_name,
    tests_config_artifacts_name,
    network_params,
    assertoor_params,
):
    config_file_path = shared_utils.path_join(
        ASSERTOOR_CONFIG_MOUNT_DIRPATH_ON_SERVICE,
        ASSERTOOR_CONFIG_FILENAME,
    )

    if assertoor_params.image != "":
        IMAGE_NAME = assertoor_params.image
    elif network_params.electra_fork_epoch != None:
        IMAGE_NAME = "ethpandaops/assertoor:verkle-support"
    else:
        IMAGE_NAME = "ethpandaops/assertoor:latest"

    return ServiceConfig(
        image=IMAGE_NAME,
        ports=USED_PORTS,
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
    )


def new_config_template_data(
    listen_port_num, client_info, validator_client_info, assertoor_params
):
    return {
        "ListenPortNum": listen_port_num,
        "ClientInfo": client_info,
        "ValidatorClientInfo": validator_client_info,
        "RunStabilityCheck": assertoor_params.run_stability_check,
        "RunBlockProposalCheck": assertoor_params.run_block_proposal_check,
        "RunLifecycleTest": assertoor_params.run_lifecycle_test,
        "RunTransactionTest": assertoor_params.run_transaction_test,
        "RunBlobTransactionTest": assertoor_params.run_blob_transaction_test,
        "RunOpcodesTransactionTest": assertoor_params.run_opcodes_transaction_test,
        "AdditionalTests": assertoor_params.tests,
    }


def new_client_info(cl_ip_addr, cl_port_num, el_ip_addr, el_port_num, service_name):
    return {
        "CLIPAddr": cl_ip_addr,
        "CLPortNum": cl_port_num,
        "ELIPAddr": el_ip_addr,
        "ELPortNum": el_port_num,
        "Name": service_name,
    }
