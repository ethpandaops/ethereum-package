constants = import_module("../../../package_io/constants.star")

MOCK_MEV_IMAGE = "parithoshj/rustic-builder:v1"
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
    jwt_secret,
    global_log_level,
    global_node_selectors,
):
    mock_builder = plan.add_service(
        name=MOCK_MEV_SERVICE_NAME,
        config=ServiceConfig(
            image=MOCK_MEV_IMAGE,
            ports={
                "rest": PortSpec(
                    number=MOCK_MEV_BUILDER_PORT, transport_protocol="TCP"
                ),
            },
            cmd=[
                "--execution-endpoint=http://{0}".format(el_uri),
                "--beacon-node=http://{0}".format(beacon_uri),
                "--jwt-secret={0}".format(jwt_secret),
                "--port={0}".format(MOCK_MEV_BUILDER_PORT),
                "--set-max-bid-value", 
                "--log-level={0}".format(global_log_level),
            ],
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            node_selectors=global_node_selectors,
        ),
    )
    return "http://{0}@{1}:{2}".format(
        constants.DEFAULT_MEV_PUBKEY, mock_builder.ip_address, MOCK_MEV_BUILDER_PORT
    )
