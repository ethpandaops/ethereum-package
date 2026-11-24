input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
node_metrics = import_module("../node_metrics_info.star")
remote_signer_context = import_module("./remote_signer_context.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

py3signer = import_module("./py3signer.star")
web3signer = import_module("./web3signer.star")
remote_signer_shared = import_module("./remote_signer_shared.star")


def get_remote_signer_config(
    plan,
    launcher,
    service_name,
    remote_signer_type,
    image,
    vc_type,
    full_name,
    node_keystore_files,
    participant,
    global_tolerations,
    node_selectors,
    port_publisher,
    remote_signer_index,
):
    if node_keystore_files == None:
        return None

    remote_signer_launchers = {
        constants.REMOTE_SIGNER_TYPE.py3signer: {
            "get_config": py3signer.get_config,
        },
        constants.REMOTE_SIGNER_TYPE.web3signer: {
            "get_config": web3signer.get_config,
        },
    }

    tolerations = shared_utils.get_tolerations(
        specific_container_tolerations=participant.remote_signer_tolerations,
        participant_tolerations=participant.tolerations,
        global_tolerations=global_tolerations,
    )

    if remote_signer_type not in remote_signer_launchers:
        fail(
            "Unsupported launcher '{0}', need one of '{1}'".format(
                remote_signer_type, ",".join(remote_signer_launchers.keys())
            )
        )

    get_config = remote_signer_launchers[remote_signer_type]["get_config"]

    config = get_config(
        plan=plan,
        participant=participant,
        el_cl_genesis_data=launcher.el_cl_genesis_data,
        image=image,
        service_name=service_name,
        remote_signer_context=remote_signer_context,
        vc_type=vc_type,
        full_name=full_name,
        node_keystore_files=node_keystore_files,
        tolerations=tolerations,
        node_selectors=node_selectors,
        port_publisher=port_publisher,
        remote_signer_index=remote_signer_index,
    )

    return config


def new_remote_signer_launcher(el_cl_genesis_data):
    return struct(el_cl_genesis_data=el_cl_genesis_data)


def get_remote_signer_context(
    plan,
    service_name,
    service,
    client_name,
):
    remote_signer_http_port = service.ports[constants.REMOTE_SIGNER_HTTP_PORT_ID]
    remote_signer_http_url = "http://{0}:{1}".format(
        service.name, remote_signer_http_port.number
    )

    remote_signer_metrics_port = service.ports[constants.METRICS_PORT_ID]
    remote_signer_metrics_url = "{0}:{1}".format(
        service.name, remote_signer_metrics_port.number
    )
    remote_signer_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, remote_signer_shared.METRICS_PATH, remote_signer_metrics_url
    )

    return remote_signer_context.new_remote_signer_context(
        http_url=remote_signer_http_url,
        client_name=client_name,
        service_name=service_name,
        metrics_info=remote_signer_node_metrics_info,
    )

def launch(
    plan,
    launcher,
    service_name,
    remote_signer_type,
    image,
    vc_type,
    full_name,
    node_keystore_files,
    participant,
    global_tolerations,
    node_selectors,
    port_publisher,
    remote_signer_index,
):
    config = get_remote_signer_config(
        plan=plan,
        launcher=launcher,
        service_name=service_name,
        remote_signer_type=remote_signer_type,
        image=image,
        vc_type=vc_type,
        full_name=full_name,
        node_keystore_files=node_keystore_files,
        participant=participant,
        global_tolerations=global_tolerations,
        node_selectors=node_selectors,
        port_publisher=port_publisher,
        remote_signer_index=remote_signer_index,
    )

    if config == None:
        return None

    remote_signer_service = plan.add_service(service_name, config)

    return get_remote_signer_context(
        plan=plan,
        service_name=service_name,
        service=remote_signer_service,
        client_name=remote_signer_type,
    )
