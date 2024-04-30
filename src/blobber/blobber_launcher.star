shared_utils = import_module("../shared_utils/shared_utils.star")
input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
cl_context = import_module("../cl/cl_context.star")

blobber_context = import_module("../blobber/blobber_context.star")

BLOBBER_BEACON_PORT_NUM = 9000
BLOBBER_BEACON_PORT_TCP_ID = "discovery-tcp"
BLOBBER_BEACON_PORT_UDP_ID = "discovery-udp"
BLOBBER_VALIDATOR_PROXY_PORT_NUM = 5000
BLOBBER_VALIDATOR_PROXY_PORT_ID = "http"

DEFAULT_BLOBBER_IMAGE = "ethpandaops/blobber:1.1.0"

VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS = "/validator-keys"

BLOBBER_USED_PORTS = {
    BLOBBER_VALIDATOR_PROXY_PORT_ID: shared_utils.new_port_spec(
        BLOBBER_VALIDATOR_PROXY_PORT_NUM, shared_utils.TCP_PROTOCOL, wait="5s"
    ),
    BLOBBER_BEACON_PORT_TCP_ID: shared_utils.new_port_spec(
        BLOBBER_BEACON_PORT_NUM, shared_utils.TCP_PROTOCOL, wait=None
    ),
    BLOBBER_BEACON_PORT_UDP_ID: shared_utils.new_port_spec(
        BLOBBER_BEACON_PORT_NUM, shared_utils.UDP_PROTOCOL, wait=None
    ),
}

# The min/max CPU/memory that blobbers can use
MIN_CPU = 10
MAX_CPU = 500
MIN_MEMORY = 10
MAX_MEMORY = 300


def launch(
    plan,
    service_name,
    node_keystore_files,
    beacon_http_url,
    extra_params,
    node_selectors,
):
    blobber_service_name = "{0}".format(service_name)

    blobber_config = get_config(
        service_name,
        node_keystore_files,
        beacon_http_url,
        extra_params,
        node_selectors,
    )

    blobber_service = plan.add_service(blobber_service_name, blobber_config)
    return blobber_context.new_blobber_context(
        blobber_service.ip_address,
        blobber_service.ports[BLOBBER_VALIDATOR_PROXY_PORT_NUM],
    )


def get_config(
    service_name,
    node_keystore_files,
    beacon_http_url,
    extra_params,
    node_selectors,
):
    validator_root_dirpath = shared_utils.path_join(
        VALIDATOR_KEYS_MOUNTPOINT_ON_CLIENTS,
        node_keystore_files.raw_root_dirpath,
    )
    cmd = [
        "--beacon-port-start={0}".format(BLOBBER_BEACON_PORT_NUM),
        "--cl={0}".format(beacon_http_url),
        "--validator-key-folder={0}".format(validator_root_dirpath),
        "--enable-unsafe-mode",
        # Does this get affected by public ip address changes?
        "--external-ip={0}".format(constants.PRIVATE_IP_ADDRESS_PLACEHOLDER),
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
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
