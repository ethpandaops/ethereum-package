input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
node_metrics = import_module("../node_metrics_info.star")
vc_context = import_module("./vc_context.star")

lighthouse = import_module("./lighthouse.star")
lodestar = import_module("./lodestar.star")
nimbus = import_module("./nimbus.star")
prysm = import_module("./prysm.star")
teku = import_module("./teku.star")
vc_shared = import_module("./shared.star")
shared_utils = import_module("../shared_utils/shared_utils.star")


def launch(
    plan,
    launcher,
    keymanager_file,
    service_name,
    vc_type,
    image,
    global_log_level,
    cl_context,
    el_context,
    full_name,
    snooper_enabled,
    snooper_beacon_context,
    node_keystore_files,
    participant,
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
    global_tolerations,
    node_selectors,
    preset,
    network,  # TODO: remove when deneb rebase is done
    electra_fork_epoch,  # TODO: remove when deneb rebase is done
    port_publisher,
    vc_index,
):
    if node_keystore_files == None:
        return None

    tolerations = input_parser.get_client_tolerations(
        participant.vc_tolerations, participant.tolerations, global_tolerations
    )

    if snooper_enabled:
        beacon_http_url = "http://{0}:{1}".format(
            snooper_beacon_context.ip_addr,
            snooper_beacon_context.beacon_rpc_port_num,
        )
    else:
        beacon_http_url = "{0}".format(
            cl_context.beacon_http_url,
        )

    (
        vc_min_cpu,
        vc_max_cpu,
        vc_min_mem,
        vc_max_mem,
        _,
    ) = shared_utils.get_cpu_mem_resource_limits(
        participant.vc_min_cpu,
        participant.vc_max_cpu,
        participant.vc_min_mem,
        participant.vc_max_mem,
        0,
        network,
        vc_type,
    )
    extra_params = participant.vc_extra_params
    extra_env_vars = participant.vc_extra_env_vars
    extra_labels = participant.vc_extra_labels
    participant_log_level = participant.vc_log_level
    keymanager_enabled = participant.keymanager_enabled
    if vc_type == constants.VC_TYPE.lighthouse:
        config = lighthouse.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            image=image,
            participant_log_level=participant_log_level,
            global_log_level=global_log_level,
            beacon_http_url=beacon_http_url,
            cl_context=cl_context,
            el_context=el_context,
            full_name=full_name,
            node_keystore_files=node_keystore_files,
            vc_min_cpu=vc_min_cpu,
            vc_max_cpu=vc_max_cpu,
            vc_min_mem=vc_min_mem,
            vc_max_mem=vc_max_mem,
            extra_params=extra_params,
            extra_env_vars=extra_env_vars,
            extra_labels=extra_labels,
            tolerations=tolerations,
            node_selectors=node_selectors,
            keymanager_enabled=keymanager_enabled,
            network=network,  # TODO: remove when deneb rebase is done
            electra_fork_epoch=electra_fork_epoch,  # TODO: remove when deneb rebase is done
            port_publisher=port_publisher,
            vc_index=vc_index,
        )
    elif vc_type == constants.VC_TYPE.lodestar:
        config = lodestar.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            keymanager_file=keymanager_file,
            image=image,
            participant_log_level=participant_log_level,
            global_log_level=global_log_level,
            beacon_http_url=beacon_http_url,
            cl_context=cl_context,
            el_context=el_context,
            full_name=full_name,
            node_keystore_files=node_keystore_files,
            vc_min_cpu=vc_min_cpu,
            vc_max_cpu=vc_max_cpu,
            vc_min_mem=vc_min_mem,
            vc_max_mem=vc_max_mem,
            extra_params=extra_params,
            extra_env_vars=extra_env_vars,
            extra_labels=extra_labels,
            tolerations=tolerations,
            node_selectors=node_selectors,
            keymanager_enabled=keymanager_enabled,
            preset=preset,
            port_publisher=port_publisher,
            vc_index=vc_index,
        )
    elif vc_type == constants.VC_TYPE.teku:
        config = teku.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            keymanager_file=keymanager_file,
            image=image,
            beacon_http_url=beacon_http_url,
            cl_context=cl_context,
            el_context=el_context,
            full_name=full_name,
            node_keystore_files=node_keystore_files,
            vc_min_cpu=vc_min_cpu,
            vc_max_cpu=vc_max_cpu,
            vc_min_mem=vc_min_mem,
            vc_max_mem=vc_max_mem,
            extra_params=extra_params,
            extra_env_vars=extra_env_vars,
            extra_labels=extra_labels,
            tolerations=tolerations,
            node_selectors=node_selectors,
            keymanager_enabled=keymanager_enabled,
            port_publisher=port_publisher,
            vc_index=vc_index,
        )
    elif vc_type == constants.VC_TYPE.nimbus:
        config = nimbus.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            keymanager_file=keymanager_file,
            image=image,
            beacon_http_url=beacon_http_url,
            cl_context=cl_context,
            el_context=el_context,
            full_name=full_name,
            node_keystore_files=node_keystore_files,
            vc_min_cpu=vc_min_cpu,
            vc_max_cpu=vc_max_cpu,
            vc_min_mem=vc_min_mem,
            vc_max_mem=vc_max_mem,
            extra_params=extra_params,
            extra_env_vars=extra_env_vars,
            extra_labels=extra_labels,
            tolerations=tolerations,
            node_selectors=node_selectors,
            keymanager_enabled=keymanager_enabled,
            port_publisher=port_publisher,
            vc_index=vc_index,
        )
    elif vc_type == constants.VC_TYPE.prysm:
        config = prysm.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            keymanager_file=keymanager_file,
            image=image,
            beacon_http_url=beacon_http_url,
            cl_context=cl_context,
            el_context=el_context,
            full_name=full_name,
            node_keystore_files=node_keystore_files,
            vc_min_cpu=vc_min_cpu,
            vc_max_cpu=vc_max_cpu,
            vc_min_mem=vc_min_mem,
            vc_max_mem=vc_max_mem,
            extra_params=extra_params,
            extra_env_vars=extra_env_vars,
            extra_labels=extra_labels,
            prysm_password_relative_filepath=prysm_password_relative_filepath,
            prysm_password_artifact_uuid=prysm_password_artifact_uuid,
            tolerations=tolerations,
            node_selectors=node_selectors,
            keymanager_enabled=keymanager_enabled,
            port_publisher=port_publisher,
            vc_index=vc_index,
        )
    elif vc_type == constants.VC_TYPE.grandine:
        fail("Grandine VC is not yet supported")
    else:
        fail("Unsupported vc_type: {0}".format(vc_type))

    validator_service = plan.add_service(service_name, config)

    validator_metrics_port = validator_service.ports[constants.METRICS_PORT_ID]
    validator_metrics_url = "{0}:{1}".format(
        validator_service.ip_address, validator_metrics_port.number
    )
    validator_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, vc_shared.METRICS_PATH, validator_metrics_url
    )

    return vc_context.new_vc_context(
        client_name=vc_type,
        service_name=service_name,
        metrics_info=validator_node_metrics_info,
    )


def new_vc_launcher(el_cl_genesis_data):
    return struct(el_cl_genesis_data=el_cl_genesis_data)
