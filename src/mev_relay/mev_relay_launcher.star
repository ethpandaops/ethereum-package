redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")
postgres_module = import_module("github.com/kurtosis-tech/postgres-package/main.star")

DUMMY_SECRET_KEY = "0x607a11b45a7219cc61a3d9c5fd08c7eebd602a6a19a977f8d3771d5711a550f2"
DUMMY_PUB_KEY = "0xa55c1285d84ba83a5ad26420cd5ad3091e49c55a813eee651cd467db38a8c8e63192f47955e9376f6b42f6d190571cb5"
MEV_BOOST_RELAY_IMAGE = "h4ck3rk3y/mev-boost-relay"

MEV_RELAY_WEBSITE = "mev-relay-website"
MEV_RELAY_ENDPOINT = "mev-relay-api"
MEV_RELAY_HOUSEKEEPER = "mev-relay-housekeeper"

MEV_RELAY_ENDPOINT_PORT = 9062
MEV_RELAY_WEBSITE_PORT = 9060

NETWORK_ID_TO_NAME = {
	"5":        "goerli",
	"11155111": "sepolia",
	"3":        "ropsten",
}

def launch_mev_relay(plan, network_id, beacon_uris, validator_root, builder_uri):
    redis = redis_module.run(plan, {})
    # making the password postgres as the relay expects it to be postgres
    postgres = postgres_module.run(plan, {"password": "postgres", "user": "postgres", "database": "postgres", "name": "postgres"})

    network_name = NETWORK_ID_TO_NAME.get(network_id, network_id)

    # TODO(maybe) remove hardocded values for the forks
    env_vars= {
        "GENESIS_FORK_VERSION": "0x10000038",
        "BELLATRIX_FORK_VERSION": "0x30000038",
        "CAPELLA_FORK_VERSION": "0x40000038",
        "DENEB_FORK_VERSION": "0x50000038",
        "GENESIS_VALIDATORS_ROOT": validator_root
    }

    plan.add_service(
        name = MEV_RELAY_HOUSEKEEPER,
        config = ServiceConfig(
            image = MEV_BOOST_RELAY_IMAGE,
            cmd = ["housekeeper", "--network", "custom", "--db", "postgres://postgres:postgres@postgres:5432/postgres?sslmode=disable", "--redis-uri", "redis:6379", "--beacon-uris", beacon_uris],
            env_vars= env_vars
        )
    )

    api = plan.add_service(
        name = MEV_RELAY_ENDPOINT,
        config = ServiceConfig(
            image = MEV_BOOST_RELAY_IMAGE,
            cmd = ["api", "--network", "custom", "--db", "postgres://postgres:postgres@postgres:5432/postgres?sslmode=disable", "--secret-key", DUMMY_SECRET_KEY, "--listen-addr", "0.0.0.0:{0}".format(MEV_RELAY_ENDPOINT_PORT), "--redis-uri", "redis:6379", "--beacon-uris", beacon_uris, "--blocksim", builder_uri],
            ports = {
                "api": PortSpec(number = MEV_RELAY_ENDPOINT_PORT, transport_protocol= "TCP")
            },
            env_vars= env_vars
        )
    )

    plan.add_service(
        name = MEV_RELAY_WEBSITE,
        config = ServiceConfig(
            image = MEV_BOOST_RELAY_IMAGE,
            cmd = ["website", "--network", "custom", "--db", "postgres://postgres:postgres@postgres:5432/postgres?sslmode=disable", "--listen-addr", "0.0.0.0:{0}".format(MEV_RELAY_WEBSITE_PORT), "--redis-uri", "redis:6379", "https://{0}@{1}".format(DUMMY_PUB_KEY, MEV_RELAY_ENDPOINT)],
            ports = {
                "api": PortSpec(number = MEV_RELAY_WEBSITE_PORT, transport_protocol= "TCP")
            },
            env_vars= env_vars
        )
    )

    return "http://{0}@{1}:{2}".format(DUMMY_PUB_KEY, api.ip_address, MEV_RELAY_ENDPOINT_PORT)
