MOCK_MEV_IMAGE = "ethpandaops/mock-builder:latest"
MOCK_MEV_SERVICE_NAME = "mock-mev"
MOCK_MEV_BUILDER_PORT = 18550
DUMMY_PUB_KEY_THAT_ISNT_VERIFIED = "0xae1c2ca7bbd6f415a5aa5bb4079caf0a5c273104be5fb5e40e2b5a2f080b2f5bd945336f2a9e8ba346299cb65b0f84c8"


def launch_mock_mev(plan, el_uri, beacon_uri, jwt_secret):
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
                "--jwt-secret={0}".format(jwt_secret),
                "--el={0}".format(el_uri),
                "--cl={0}".format(beacon_uri),
            ],
        ),
    )
    return "http://{0}@{1}:{2}".format(
        DUMMY_PUB_KEY_THAT_ISNT_VERIFIED, mock_builder.ip_address, MOCK_MEV_BUILDER_PORT
    )
