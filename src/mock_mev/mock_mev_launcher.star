MOCK_MEV_IMAGE = "ethpandaops/mock-builder:latest"
MOCK_MEV_SERVICE_NAME = "mock-mev"

def launch_mock_mev(el_uri, beacon_uri, jwt_secret):
    plan.add_service(
        name = MOCK_MEV_SERVICE_NAME,
        config = ServiceConfig(
            image = MOCK_MEV_IMAGE,
            ports = {
                "rest": PortSpec(number = 18550, transport_protocol="TCP"),
            },
            cmd = [
                "--jwt-secret={0}".format(jwt_secret),
                "--el={0}".format(el_uri),
                "--beacon={0}".format(beacon_uri)
            ]
        )
    )
