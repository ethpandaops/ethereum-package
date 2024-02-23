input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
node_metrics = import_module("../node_metrics_info.star")
validator_client_context = import_module("./validator_client_context.star")

lighthouse = import_module("./lighthouse.star")
lodestar = import_module("./lodestar.star")
nimbus = import_module("./nimbus.star")
prysm = import_module("./prysm.star")
teku = import_module("./teku.star")
validator_client_shared = import_module("./shared.star")

# The defaults for min/max CPU/memory that the validator client can use
MIN_CPU = 50
MAX_CPU = 300
MIN_MEMORY = 128
MAX_MEMORY = 512


def launch(
    plan,
    launcher,
    service_name,
    validator_client_type,
    image,
    participant_log_level,
    global_log_level,
    cl_client_context,
    el_client_context,
    node_keystore_files,
    v_min_cpu,
    v_max_cpu,
    v_min_mem,
    v_max_mem,
    extra_params,
    extra_labels,
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
    validator_tolerations,
    participant_tolerations,
    global_tolerations,
    node_selectors,
):
    if node_keystore_files == None:
        return None

    tolerations = input_parser.get_client_tolerations(
        validator_tolerations, participant_tolerations, global_tolerations
    )

    beacon_http_url = "http://{}:{}".format(
        cl_client_context.ip_addr,
        cl_client_context.http_port_num,
    )

    v_min_cpu = int(v_min_cpu) if int(v_min_cpu) > 0 else MIN_CPU
    v_max_cpu = int(v_max_cpu) if int(v_max_cpu) > 0 else MAX_CPU
    v_min_mem = int(v_min_mem) if int(v_min_mem) > 0 else MIN_MEMORY
    v_max_mem = int(v_max_mem) if int(v_max_mem) > 0 else MAX_MEMORY

    if validator_client_type == constants.VC_CLIENT_TYPE.lighthouse:
        config = lighthouse.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            image=image,
            participant_log_level=participant_log_level,
            global_log_level=global_log_level,
            beacon_http_url=beacon_http_url,
            cl_client_context=cl_client_context,
            el_client_context=el_client_context,
            node_keystore_files=node_keystore_files,
            v_min_cpu=v_min_cpu,
            v_max_cpu=v_max_cpu,
            v_min_mem=v_min_mem,
            v_max_mem=v_max_mem,
            extra_params=extra_params,
            extra_labels=extra_labels,
            tolerations=tolerations,
            node_selectors=node_selectors,
        )
    elif validator_client_type == constants.VC_CLIENT_TYPE.lodestar:
        config = lodestar.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            image=image,
            participant_log_level=participant_log_level,
            global_log_level=global_log_level,
            beacon_http_url=beacon_http_url,
            cl_client_context=cl_client_context,
            el_client_context=el_client_context,
            node_keystore_files=node_keystore_files,
            v_min_cpu=v_min_cpu,
            v_max_cpu=v_max_cpu,
            v_min_mem=v_min_mem,
            v_max_mem=v_max_mem,
            extra_params=extra_params,
            extra_labels=extra_labels,
            tolerations=tolerations,
            node_selectors=node_selectors,
        )
    elif validator_client_type == constants.VC_CLIENT_TYPE.teku:
        config = teku.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            image=image,
            beacon_http_url=beacon_http_url,
            cl_client_context=cl_client_context,
            el_client_context=el_client_context,
            node_keystore_files=node_keystore_files,
            v_min_cpu=v_min_cpu,
            v_max_cpu=v_max_cpu,
            v_min_mem=v_min_mem,
            v_max_mem=v_max_mem,
            extra_params=extra_params,
            extra_labels=extra_labels,
            tolerations=tolerations,
            node_selectors=node_selectors,
        )
    elif validator_client_type == constants.VC_CLIENT_TYPE.nimbus:
        config = nimbus.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            image=image,
            beacon_http_url=beacon_http_url,
            cl_client_context=cl_client_context,
            el_client_context=el_client_context,
            node_keystore_files=node_keystore_files,
            v_min_cpu=v_min_cpu,
            v_max_cpu=v_max_cpu,
            v_min_mem=v_min_mem,
            v_max_mem=v_max_mem,
            extra_params=extra_params,
            extra_labels=extra_labels,
            tolerations=tolerations,
            node_selectors=node_selectors,
        )
    elif validator_client_type == constants.VC_CLIENT_TYPE.prysm:
        # Prysm VC only works with Prysm beacon node right now
        if cl_client_context.client_name != constants.CL_CLIENT_TYPE.prysm:
            fail("Prysm VC is only compatible with Prysm beacon node")

        config = prysm.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            image=image,
            beacon_http_url=beacon_http_url,
            cl_client_context=cl_client_context,
            el_client_context=el_client_context,
            node_keystore_files=node_keystore_files,
            v_min_cpu=v_min_cpu,
            v_max_cpu=v_max_cpu,
            v_min_mem=v_min_mem,
            v_max_mem=v_max_mem,
            extra_params=extra_params,
            extra_labels=extra_labels,
            prysm_password_relative_filepath=prysm_password_relative_filepath,
            prysm_password_artifact_uuid=prysm_password_artifact_uuid,
            tolerations=tolerations,
            node_selectors=node_selectors,
        )
    else:
        fail("Unsupported validator_client_type: {0}".format(validator_client_type))

    validator_service = plan.add_service(service_name, config)

    validator_metrics_port = validator_service.ports[
        validator_client_shared.VALIDATOR_CLIENT_METRICS_PORT_ID
    ]
    validator_metrics_url = "{0}:{1}".format(
        validator_service.ip_address, validator_metrics_port.number
    )
    validator_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, validator_client_shared.METRICS_PATH, validator_metrics_url
    )

    return validator_client_context.new_validator_client_context(
        service_name=service_name,
        client_name=validator_client_type,
        metrics_info=validator_node_metrics_info,
    )


def new_validator_client_launcher(el_cl_genesis_data):
    return struct(el_cl_genesis_data=el_cl_genesis_data)
