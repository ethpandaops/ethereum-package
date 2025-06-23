constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
node_metrics = import_module("../node_metrics_info.star")
remote_signer_context = import_module("./remote_signer_context.star")
shared_utils = import_module("../shared_utils/shared_utils.star")

REMOTE_SIGNER_KEYS_MOUNTPOINT = "/keystores"

REMOTE_SIGNER_HTTP_PORT_NUM = 9000
REMOTE_SIGNER_HTTP_PORT_ID = "http"
REMOTE_SIGNER_METRICS_PORT_NUM = 9001
REMOTE_SIGNER_METRICS_PORT_ID = "metrics"

METRICS_PATH = "/metrics"

REMOTE_SIGNER_USED_PORTS = {
    REMOTE_SIGNER_HTTP_PORT_ID: shared_utils.new_port_spec(
        REMOTE_SIGNER_HTTP_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    REMOTE_SIGNER_METRICS_PORT_ID: shared_utils.new_port_spec(
        REMOTE_SIGNER_METRICS_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

# The min/max CPU/memory that the remote signer can use
MIN_CPU = 50
MAX_CPU = 300
MIN_MEMORY = 128
MAX_MEMORY = 1024


def launch(
    plan,
    launcher,
    service_name,
    remote_signer_type,
    image,
    full_name,
    vc_type,
    node_keystore_files,
    participant,
    global_tolerations,
    node_selectors,
    port_publisher,
    remote_signer_index,
):
    tolerations = input_parser.get_client_tolerations(
        participant.remote_signer_tolerations,
        participant.tolerations,
        global_tolerations,
    )

    config = get_config(
        participant=participant,
        el_cl_genesis_data=launcher.el_cl_genesis_data,
        image=image,
        vc_type=vc_type,
        node_keystore_files=node_keystore_files,
        tolerations=tolerations,
        node_selectors=node_selectors,
        port_publisher=port_publisher,
        remote_signer_index=remote_signer_index,
    )

    remote_signer_service = plan.add_service(service_name, config)

    remote_signer_http_port = remote_signer_service.ports[REMOTE_SIGNER_HTTP_PORT_ID]
    remote_signer_http_url = "http://{0}:{1}".format(
        remote_signer_service.ip_address, remote_signer_http_port.number
    )

    remote_signer_metrics_port = remote_signer_service.ports[
        REMOTE_SIGNER_METRICS_PORT_ID
    ]
    validator_metrics_url = "{0}:{1}".format(
        remote_signer_service.ip_address, remote_signer_metrics_port.number
    )
    remote_signer_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, validator_metrics_url
    )

    return remote_signer_context.new_remote_signer_context(
        http_url=remote_signer_http_url,
        client_name=remote_signer_type,
        service_name=service_name,
        metrics_info=remote_signer_node_metrics_info,
    )


def get_config(
    participant,
    el_cl_genesis_data,
    image,
    vc_type,
    node_keystore_files,
    tolerations,
    node_selectors,
    port_publisher,
    remote_signer_index,
):
    validator_keys_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            REMOTE_SIGNER_KEYS_MOUNTPOINT,
            node_keystore_files.teku_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            REMOTE_SIGNER_KEYS_MOUNTPOINT,
            node_keystore_files.teku_secrets_relative_dirpath,
        )

    cmd = [
        "--http-listen-port={0}".format(REMOTE_SIGNER_HTTP_PORT_NUM),
        "--http-host-allowlist=*",
        "--metrics-enabled=true",
        "--metrics-host-allowlist=*",
        "--metrics-host=0.0.0.0",
        "--metrics-port={0}".format(REMOTE_SIGNER_METRICS_PORT_NUM),
        "eth2",
        "--network="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--keystores-path=" + validator_keys_dirpath,
        "--keystores-passwords-path=" + validator_secrets_dirpath,
        # slashing protection would require a postgres DB, applying DB migrations ...
        "--slashing-protection-enabled=false",
    ]

    if len(participant.remote_signer_extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
        cmd.extend([param for param in participant.remote_signer_extra_params])

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        REMOTE_SIGNER_KEYS_MOUNTPOINT: node_keystore_files.files_artifact_uuid,
    }

    public_ports = {}
    if port_publisher.remote_signer_enabled:
        public_ports_for_component = shared_utils.get_public_ports_for_component(
            "remote-signer", port_publisher, remote_signer_index
        )
        public_port_assignments = {
            constants.METRICS_PORT_ID: public_ports_for_component[0]
        }
        public_ports = shared_utils.get_port_specs(public_port_assignments)

    ports = {}
    ports.update(REMOTE_SIGNER_USED_PORTS)

    config_args = {
        "image": image,
        "ports": ports,
        "public_ports": public_ports,
        "cmd": cmd,
        "files": files,
        "env_vars": participant.remote_signer_extra_env_vars,
        "labels": shared_utils.label_maker(
            client=constants.REMOTE_SIGNER_TYPE.web3signer,
            client_type=constants.CLIENT_TYPES.remote_signer,
            image=image,
            connected_client=vc_type,
            extra_labels=participant.remote_signer_extra_labels,
            supernode=participant.supernode,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if participant.remote_signer_min_cpu > 0:
        config_args["min_cpu"] = participant.remote_signer_min_cpu
    if participant.remote_signer_max_cpu > 0:
        config_args["max_cpu"] = participant.remote_signer_max_cpu
    if participant.remote_signer_min_mem > 0:
        config_args["min_memory"] = participant.remote_signer_min_mem
    if participant.remote_signer_max_mem > 0:
        config_args["max_memory"] = participant.remote_signer_max_mem

    return ServiceConfig(**config_args)


def new_remote_signer_launcher(el_cl_genesis_data):
    return struct(el_cl_genesis_data=el_cl_genesis_data)
