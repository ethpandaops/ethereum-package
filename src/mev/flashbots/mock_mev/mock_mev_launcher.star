constants = import_module("../../../package_io/constants.star")
input_parser = import_module("../../../package_io/input_parser.star")
shared_utils = import_module("../../../shared_utils/shared_utils.star")
# Default image if none specified in mev_params

MOCK_MEV_SERVICE_NAME = "mock-mev"
MOCK_MEV_BUILDER_PORT = 8560

# The min/max CPU/memory that rustic-builder can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 128
MAX_MEMORY = 1024


def launch_mock_mev(
    plan,
    el_uri,
    beacon_uri,
    jwt_file,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    mev_params,
):
    tolerations = shared_utils.get_tolerations(global_tolerations=global_tolerations)
    mock_builder = plan.add_service(
        name=MOCK_MEV_SERVICE_NAME,
        config=ServiceConfig(
            image=mev_params.mock_mev_image,
            ports={
                "rest": PortSpec(
                    number=MOCK_MEV_BUILDER_PORT, transport_protocol="TCP"
                ),
            },
            cmd=[
                "--execution-endpoint=http://{0}".format(el_uri),
                "--beacon-node=http://{0}".format(beacon_uri),
                "--jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
                "--port={0}".format(MOCK_MEV_BUILDER_PORT),
                "--address=0.0.0.0",
                "--set-max-bid-value",
                "--log-level={0}".format(global_log_level),
                "--builder-secret-key=" + constants.DEFAULT_MEV_SECRET_KEY[2:],
            ],
            files={
                constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
            },
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=global_node_selectors,
            tolerations=tolerations,
        ),
    )
    return "http://{0}@{1}:{2}".format(
        constants.DEFAULT_MEV_PUBKEY, mock_builder.ip_address, MOCK_MEV_BUILDER_PORT
    )
