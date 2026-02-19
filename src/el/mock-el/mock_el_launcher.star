shared_utils = import_module("../../shared_utils/shared_utils.star")
input_parser = import_module("../../package_io/input_parser.star")
el_context = import_module("../../el/el_context.star")
constants = import_module("../../package_io/constants.star")

ENGINE_RPC_PORT_NUM = 8551

GENESIS_FILEPATH = constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS + "/genesis.json"


def get_used_ports():
    used_ports = {
        constants.ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(
            ENGINE_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL
        ),
        constants.RPC_PORT_ID: shared_utils.new_port_spec(
            ENGINE_RPC_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


def launch(
    plan,
    launcher,
    service_name,
    participant,
    global_log_level,
    existing_el_clients,
    persistent,
    tolerations,
    node_selectors,
    port_publisher,
    participant_index,
    network_params,
    extra_files_artifacts,
    bootnodoor_enode=None,
    el_binary_artifact=None,
):
    cl_client_name = service_name.split("-")[3]

    config = get_config(
        plan,
        launcher,
        participant,
        service_name,
        existing_el_clients,
        cl_client_name,
        global_log_level,
        persistent,
        tolerations,
        node_selectors,
        port_publisher,
        participant_index,
        network_params,
        extra_files_artifacts,
        bootnodoor_enode,
        el_binary_artifact,
    )

    service = plan.add_service(
        service_name, config, force_update=participant.el_force_restart
    )

    return get_el_context(
        plan,
        service_name,
        service,
        launcher,
    )


def get_config(
    plan,
    launcher,
    participant,
    service_name,
    existing_el_clients,
    cl_client_name,
    global_log_level,
    persistent,
    tolerations,
    node_selectors,
    port_publisher,
    participant_index,
    network_params,
    extra_files_artifacts,
    bootnodoor_enode=None,
    el_binary_artifact=None,
):
    used_ports = get_used_ports()

    cmd = [
        "lcli",
        "mock-el",
        "--listen-address",
        "0.0.0.0",
        "--listen-port",
        str(ENGINE_RPC_PORT_NUM),
        "--jwt-secret-path",
        constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--all-payloads-valid",
        "true",
    ]

    if network_params.network in constants.PUBLIC_NETWORKS:
        cmd.extend(["--network", network_params.network])
    else:
        shanghai_time = plan.run_sh(
            name="{}-shanghai-time".format(service_name),
            run="jq -r '.config.shanghaiTime // 0' < {} | tr -d '\\n'".format(GENESIS_FILEPATH),
            files={
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
            },
        )
        cancun_time = plan.run_sh(
            name="{}-cancun-time".format(service_name),
            run="jq -r '.config.cancunTime // 0' < {} | tr -d '\\n'".format(GENESIS_FILEPATH),
            files={
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
            },
        )
        prague_time = plan.run_sh(
            name="{}-prague-time".format(service_name),
            run="jq -r '.config.pragueTime // 0' < {} | tr -d '\\n'".format(GENESIS_FILEPATH),
            files={
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
            },
        )
        osaka_time = plan.run_sh(
            name="{}-osaka-time".format(service_name),
            run="jq -r '.config.osakaTime // 0' < {} | tr -d '\\n'".format(GENESIS_FILEPATH),
            files={
                constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
            },
        )
        cmd.extend([
            "--shanghai-time",
            shanghai_time.output,
            "--cancun-time",
            cancun_time.output,
            "--prague-time",
            prague_time.output,
            "--osaka-time",
            osaka_time.output,
        ])

    if len(participant.el_extra_params) > 0:
        cmd.extend([param for param in participant.el_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.el_cl_genesis_data.files_artifact_uuid,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }

    # Add extra mounts - automatically handle file uploads
    processed_mounts = shared_utils.process_extra_mounts(
        plan, participant.el_extra_mounts, extra_files_artifacts
    )
    for mount_path, artifact in processed_mounts.items():
        files[mount_path] = artifact

    config_args = {
        "image": participant.el_image,
        "ports": used_ports,
        "cmd": cmd,
        "files": files,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": participant.el_extra_env_vars,
        "labels": shared_utils.label_maker(
            client=constants.EL_TYPE.mock_el,
            client_type=constants.CLIENT_TYPES.el,
            image=participant.el_image[-constants.MAX_LABEL_LENGTH :],
            connected_client=cl_client_name,
            extra_labels=participant.el_extra_labels
            | {constants.NODE_INDEX_LABEL_KEY: str(participant_index + 1)},
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if participant.el_min_cpu > 0:
        config_args["min_cpu"] = participant.el_min_cpu
    if participant.el_max_cpu > 0:
        config_args["max_cpu"] = participant.el_max_cpu
    if participant.el_min_mem > 0:
        config_args["min_memory"] = participant.el_min_mem
    if participant.el_max_mem > 0:
        config_args["max_memory"] = participant.el_max_mem

    return ServiceConfig(**config_args)


def get_el_context(
    plan,
    service_name,
    service,
    launcher,
):
    http_url = "http://{0}:{1}".format(service.name, ENGINE_RPC_PORT_NUM)

    return el_context.new_el_context(
        client_name="mock-el",
        enode="",
        dns_name=service.name,
        rpc_port_num=ENGINE_RPC_PORT_NUM,
        ws_port_num=0,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        rpc_http_url=http_url,
        ws_url="",
        enr="",
        service_name=service_name,
        el_metrics_info=[],
        ip_addr=service.ip_address,
    )


def new_mock_el_launcher(el_cl_genesis_data, jwt_file):
    return struct(el_cl_genesis_data=el_cl_genesis_data, jwt_file=jwt_file)
