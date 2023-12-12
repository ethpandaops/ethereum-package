shared_utils = import_module("../shared_utils/shared_utils.star")
input_parser = import_module("../package_io/input_parser.star")
cl_client_context = import_module("../cl/cl_client_context.star")

blobber_context = import_module("../blobber/blobber_context.star")

BLOBBER_BEACON_PORT_NUM = 9000
BLOBBER_BEACON_PORT_ID = "discovery"
BLOBBER_VALIDATOR_PROXY_PORT_NUM = 5000
BLOBBER_VALIDATOR_PROXY_PORT_ID = "http"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

DEFAULT_BLOBBER_IMAGE = "ethpandaops/blobber:1.0.5"

VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS = "/validator-keys"

BLOBBER_USED_PORTS = {
    BLOBBER_VALIDATOR_PROXY_PORT_ID: shared_utils.new_port_spec(
        BLOBBER_VALIDATOR_PROXY_PORT_NUM, shared_utils.TCP_PROTOCOL, wait="5s"
    ),
    BLOBBER_BEACON_PORT_ID: shared_utils.new_port_spec(
        BLOBBER_BEACON_PORT_NUM, shared_utils.TCP_PROTOCOL, wait=None
    ),
}


def launch(plan, service_name, node_keystore_files, beacon_http_url, extra_params):
    blobber_service_name = "{0}".format(service_name)

    blobber_config = get_config(
        service_name, node_keystore_files, beacon_http_url, extra_params
    )

    blobber_service = plan.add_service(blobber_service_name, blobber_config)
    return blobber_context.new_blobber_context(
        blobber_service.ip_address, blobber_service.ports[BLOBBER_VALIDATOR_PROXY_PORT_NUM]
    )


def get_config(service_name, node_keystore_files, beacon_http_url, extra_params):

    validator_root_dirpath = shared_utils.path_join(
        VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS,
        node_keystore_files.raw_root_dirpath,
    )
    cmd = [
        "--beacon-port-start={0}".format(BLOBBER_BEACON_PORT_NUM),
        "--cl={0}".format(beacon_http_url),
        "--validator-key-folder={0}".format(validator_root_dirpath),
        "--enable-unsafe-mode",
        "--external-ip={0}".format(PRIVATE_IP_ADDRESS_PLACEHOLDER),
        "--validator-proxy-port-start={0}".format(BLOBBER_VALIDATOR_PROXY_PORT_NUM),
    ]

    if len(extra_params) > 0:
        cmd.extend([param for param in extra_params])

    return ServiceConfig(
        image=DEFAULT_BLOBBER_IMAGE,
        ports=BLOBBER_USED_PORTS,
        files={
            VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS: node_keystore_files.files_artifact_uuid
        },
        cmd=cmd,
        private_ip_address_placeholder=PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
