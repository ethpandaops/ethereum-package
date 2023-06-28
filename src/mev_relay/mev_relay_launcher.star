redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")
postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")

DUMMY_SECRET_KEY = "0x607a11b45a7219cc61a3d9c5fd08c7eebd602a6a19a977f8d3771d5711a550f2"
DUMMY_PUB_KEY = "0xae1c2ca7bbd6f415a5aa5bb4079caf0a5c273104be5fb5e40e2b5a2f080b2f5bd945336f2a9e8ba346299cb65b0f84c8"
MEV_BOOST_RELAY_IMAGE = "flashbots/mev-boost-relay"

MEV_RELAY_WEBSITE = "mev-relay-website"
MEV_RELAY_ENDPOINT = "mev-relay-api"
MEV_RELAY_HOUSEKEEPER = "mev-relay-housekeeper"

NETWORK_ID_TO_NAME = {
	"5":        "goerli",
	"11155111": "sepolia",
	"3":        "ropsten",
}

def launch_mev_relay(plan, network_id, beacon_uri):
    redis = redis_module.run(plan, {})
    # making the password postgres as the relay expects it to be postgres
    postgres = postgres_module.run(plan, {"password": "postgres", "user": "postgres", "database": "postgres", "name": "postgres"})

    network_name = NETWORK_ID_TO_NAME.get(network_id, network_id)

    plan.add_service(
        name = MEV_RELAY_HOUSEKEEPER,
        config = ServiceConfig(
            image = MEV_BOOST_RELAY_IMAGE,
            cmd = ["housekeeper", "--network", "custom", "--db", "postgres://postgres:postgres@postgres:5432/postgres?sslmode=disable", "--redis-uri", "redis:6379", "--beacon-uris", "http://" + beacon_uri],
            env_vars={
                "GENESIS_FORK_VERSION": "0x10000038",
                "BELLATRIX_FORK_VERSION": "0x30000038",
                "CAPELLA_FORK_VERSION": "0x40000038",
            }
        )
    )

    api = plan.add_service(
        name = MEV_RELAY_ENDPOINT,
        config = ServiceConfig(
            image = MEV_BOOST_RELAY_IMAGE,
            cmd = ["api", "--network", "custom", "--db", "postgres://postgres:postgres@postgres:5432/postgres?sslmode=disable", "--secret-key", DUMMY_SECRET_KEY, "--listen-addr", "0.0.0.0:9062", "--redis-uri", "redis:6379", "--beacon-uris", "http://" + beacon_uri],
            ports = {
                "api": PortSpec(number = 9062, transport_protocol= "TCP")
            },
            # TODO remove hardcoding
            env_vars={
                "GENESIS_FORK_VERSION": "0x10000038",
                "BELLATRIX_FORK_VERSION": "0x30000038",
                "CAPELLA_FORK_VERSION": "0x40000038",
            }
        )
    )

    plan.add_service(
        name = MEV_RELAY_WEBSITE,
        config = ServiceConfig(
            image = MEV_BOOST_RELAY_IMAGE,
            cmd = ["website", "--network", "custom", "--db", "postgres://postgres:postgres@postgres:5432/postgres?sslmode=disable", "--listen-addr", "0.0.0.0:9060", "--redis-uri", "redis:6379", "https://{0}@{1}".format(DUMMY_PUB_KEY, MEV_RELAY_ENDPOINT)],
            ports = {
                "api": PortSpec(number = 9060, transport_protocol= "TCP")
            },
            env_vars={
                "GENESIS_FORK_VERSION": "0x10000038",
                "BELLATRIX_FORK_VERSION": "0x30000038",
                "CAPELLA_FORK_VERSION": "0x40000038",
            }
        )
    )

    return "http://{0}@{1}:{2}".format(DUMMY_PUB_KEY, api.ip_address, 9062)