EL_TYPE = struct(
    geth="geth",
    erigon="erigon",
    nethermind="nethermind",
    besu="besu",
    reth="reth",
    reth_builder="reth-builder",
    ethereumjs="ethereumjs",
    nimbus="nimbus",
)

CL_TYPE = struct(
    lighthouse="lighthouse",
    teku="teku",
    nimbus="nimbus",
    prysm="prysm",
    lodestar="lodestar",
    grandine="grandine",
)

VC_TYPE = struct(
    lighthouse="lighthouse",
    lodestar="lodestar",
    nimbus="nimbus",
    prysm="prysm",
    teku="teku",
    vero="vero",
)

REMOTE_SIGNER_TYPE = struct(web3signer="web3signer")

GLOBAL_LOG_LEVEL = struct(
    info="info",
    error="error",
    warn="warn",
    debug="debug",
    trace="trace",
)

CLIENT_TYPES = struct(
    el="execution",
    cl="beacon",
    validator="validator",
    remote_signer="remote-signer",
)

TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
RPC_PORT_ID = "rpc"
WS_RPC_PORT_ID = "ws-rpc"
WS_PORT_ID = "ws"
HTTP_PORT_ID = "http"
PROFILING_PORT_ID = "profiling"
VALIDATOR_HTTP_PORT_ID = "http-validator"
METRICS_PORT_ID = "metrics"
ENGINE_RPC_PORT_ID = "engine-rpc"
ENGINE_WS_PORT_ID = "engine-ws"
ADMIN_PORT_ID = "admin"
RBUILDER_PORT_ID = "rbuilder-rpc"
LITTLE_BIGTABLE_PORT_ID = "littlebigtable"
VALDIATOR_GRPC_PORT_ID = "grpc"

VALIDATING_REWARDS_ACCOUNT = "0x8943545177806ED17B9F23F0a21ee5948eCaa776"
MAX_ENR_ENTRIES = 20
MAX_ENODE_ENTRIES = 20

GENESIS_VALIDATORS_ROOT_PLACEHOLDER = "GENESIS_VALIDATORS_ROOT_PLACEHOLDER"

ARCHIVE_MODE = True

GENESIS_DATA_MOUNTPOINT_ON_CLIENTS = "/network-configs"
GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER = GENESIS_DATA_MOUNTPOINT_ON_CLIENTS

VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER = "/validator-keys"

JWT_MOUNTPOINT_ON_CLIENTS = "/jwt"
JWT_MOUNT_PATH_ON_CONTAINER = JWT_MOUNTPOINT_ON_CLIENTS + "/jwtsecret"

NODE_KEY_MOUNTPOINT_ON_CLIENTS = "/peerdas-node-keys"

KEYMANAGER_MOUNT_PATH_ON_CLIENTS = "/keymanager"
KEYMANAGER_MOUNT_PATH_ON_CONTAINER = (
    KEYMANAGER_MOUNT_PATH_ON_CLIENTS + "/keymanager.txt"
)

MOCK_MEV_TYPE = "mock"
FLASHBOTS_MEV_TYPE = "flashbots"
MEV_RS_MEV_TYPE = "mev-rs"
COMMIT_BOOST_MEV_TYPE = "commit-boost"
DEFAULT_DORA_IMAGE = "ethpandaops/dora:latest"
DEFAULT_ASSERTOOR_IMAGE = "ethpandaops/assertoor:latest"
DEFAULT_SNOOPER_IMAGE = "ethpandaops/rpc-snooper:latest"
DEFAULT_ETHEREUM_GENESIS_GENERATOR_IMAGE = (
    "ethpandaops/ethereum-genesis-generator:4.0.1"
)
DEFAULT_FLASHBOTS_RELAY_IMAGE = "ethpandaops/mev-boost-relay:main"
DEFAULT_FLASHBOTS_BUILDER_IMAGE = "ethpandaops/reth-rbuilder:develop"
DEFAULT_FLASHBOTS_MEV_BOOST_IMAGE = "ethpandaops/mev-boost:develop"
DEFAULT_MEV_RS_IMAGE = "ethpandaops/mev-rs:main"
DEFAULT_MEV_RS_IMAGE_MINIMAL = "ethpandaops/mev-rs:main-minimal"
DEFAULT_COMMIT_BOOST_MEV_BOOST_IMAGE = "ghcr.io/commit-boost/pbs:latest"
DEFAULT_MOCK_MEV_IMAGE = "ethpandaops/rustic-builder:main"
DEFAULT_MEV_PUBKEY = "0xa55c1285d84ba83a5ad26420cd5ad3091e49c55a813eee651cd467db38a8c8e63192f47955e9376f6b42f6d190571cb5"
DEFAULT_MEV_SECRET_KEY = (
    "0x607a11b45a7219cc61a3d9c5fd08c7eebd602a6a19a977f8d3771d5711a550f2"
)

DEFAULT_MNEMONIC = "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

GENESIS_FORK_VERSION = "0x10000038"
ALTAIR_FORK_VERSION = "0x20000038"
BELLATRIX_FORK_VERSION = "0x30000038"
CAPELLA_FORK_VERSION = "0x40000038"
DENEB_FORK_VERSION = "0x50000038"
ELECTRA_FORK_VERSION = "0x60000038"
FULU_FORK_VERSION = "0x70000038"
EIP7732_FORK_VERSION = "0x80000038"
EIP7805_FORK_VERSION = "0x90000038"

FAR_FUTURE_EPOCH = 18446744073709551615

MAX_LABEL_LENGTH = 63

CONTAINER_REGISTRY = struct(
    dockerhub="/",
    ghcr="ghcr.io",
    gcr="gcr.io",
)

NETWORK_NAME = struct(
    mainnet="mainnet",
    sepolia="sepolia",
    holesky="holesky",
    hoodi="hoodi",
    ephemery="ephemery",
    kurtosis="kurtosis",
    verkle="verkle",
    shadowfork="shadowfork",
)

PUBLIC_NETWORKS = (
    "mainnet",
    "sepolia",
    "holesky",
    "hoodi",
)

NETWORK_ID = {
    "mainnet": "1",
    "sepolia": "11155111",
    "holesky": "17000",
    "hoodi": "560048",
}

CHECKPOINT_SYNC_URL = {
    "mainnet": "https://beaconstate.info",
    "ephemery": "https://checkpoint-sync.ephemery.ethpandaops.io/",
    "sepolia": "https://checkpoint-sync.sepolia.ethpandaops.io/",
    "holesky": "https://checkpoint-sync.holesky.ethpandaops.io/",
    "hoodi": "https://checkpoint-sync.hoodi.ethpandaops.io/",
}

GENESIS_VALIDATORS_ROOT = {
    "mainnet": "0x4b363db94e286120d76eb905340fdd4e54bfe9f06bf33ff6cf5ad27f511bfe95",
    "sepolia": "0xd8ea171f3c94aea21ebc42a1ed61052acf3f9209c00e4efbaaddac09ed9b8078",
    "holesky": "0x9143aa7c615a7f7115e2b6aac319c03529df8242ae705fba9df39b79c59fa8b1",
    "hoodi": "0x212f13fc4df078b6cb7db228f1c8307566dcecf900867401a92023d7ba99cb5f",
}

DEPOSIT_CONTRACT_ADDRESS = {
    "mainnet": "0x00000000219ab540356cBB839Cbe05303d7705Fa",
    "sepolia": "0x7f02C3E3c98b133055B8B348B2Ac625669Ed295D",
    "holesky": "0x4242424242424242424242424242424242424242",
    "ephemery": "0x4242424242424242424242424242424242424242",
    "hoodi": "0x00000000219ab540356cBB839Cbe05303d7705Fa",
}

GENESIS_TIME = {
    "mainnet": 1606824023,
    "sepolia": 1655733600,
    "holesky": 1695902400,
    "hoodi": 1741971600,
}

VOLUME_SIZE = {
    "mainnet": {
        "geth_volume_size": 1000000,  # 1TB
        "erigon_volume_size": 3000000,  # 3TB
        "nethermind_volume_size": 1000000,  # 1TB
        "besu_volume_size": 1000000,  # 1TB
        "reth_volume_size": 3000000,  # 3TB
        "reth_builder_volume_size": 3000000,  # 3TB
        "ethereumjs_volume_size": 1000000,  # 1TB
        "nimbus_eth1_volume_size": 1000000,  # 1TB
        "prysm_volume_size": 500000,  # 500GB
        "lighthouse_volume_size": 500000,  # 500GB
        "teku_volume_size": 500000,  # 500GB
        "nimbus_volume_size": 500000,  # 500GB
        "lodestar_volume_size": 500000,  # 500GB
        "grandine_volume_size": 500000,  # 500GB
    },
    "sepolia": {
        "geth_volume_size": 300000,  # 300GB
        "erigon_volume_size": 500000,  # 500GB
        "nethermind_volume_size": 300000,  # 300GB
        "besu_volume_size": 300000,  # 300GB
        "reth_volume_size": 500000,  # 500GB
        "reth_builder_volume_size": 500000,  # 500GB
        "ethereumjs_volume_size": 300000,  # 300GB
        "nimbus_eth1_volume_size": 300000,  # 300GB
        "prysm_volume_size": 150000,  # 150GB
        "lighthouse_volume_size": 150000,  # 150GB
        "teku_volume_size": 150000,  # 150GB
        "nimbus_volume_size": 150000,  # 150GB
        "lodestar_volume_size": 150000,  # 150GB
        "grandine_volume_size": 150000,  # 150GB
    },
    "holesky": {
        "geth_volume_size": 100000,  # 100GB
        "erigon_volume_size": 200000,  # 200GB
        "nethermind_volume_size": 100000,  # 100GB
        "besu_volume_size": 100000,  # 100GB
        "reth_volume_size": 200000,  # 200GB
        "reth_builder_volume_size": 200000,  # 200GB
        "ethereumjs_volume_size": 100000,  # 100GB
        "nimbus_eth1_volume_size": 100000,  # 100GB
        "prysm_volume_size": 100000,  # 100GB
        "lighthouse_volume_size": 100000,  # 100GB
        "teku_volume_size": 100000,  # 100GB
        "nimbus_volume_size": 100000,  # 100GB
        "lodestar_volume_size": 100000,  # 100GB
        "grandine_volume_size": 100000,  # 100GB
    },
    "devnets": {
        "geth_volume_size": 100000,  # 100GB
        "erigon_volume_size": 200000,  # 200GB
        "nethermind_volume_size": 100000,  # 100GB
        "besu_volume_size": 100000,  # 100GB
        "reth_volume_size": 200000,  # 200GB
        "reth_builder_volume_size": 200000,  # 200GB
        "ethereumjs_volume_size": 100000,  # 100GB
        "nimbus_eth1_volume_size": 100000,  # 100GB
        "prysm_volume_size": 100000,  # 100GB
        "lighthouse_volume_size": 100000,  # 100GB
        "teku_volume_size": 100000,  # 100GB
        "nimbus_volume_size": 100000,  # 100GB
        "lodestar_volume_size": 100000,  # 100GB
        "grandine_volume_size": 100000,  # 100GB
    },
    "ephemery": {
        "geth_volume_size": 5000,  # 5GB
        "erigon_volume_size": 3000,  # 3GB
        "nethermind_volume_size": 3000,  # 3GB
        "besu_volume_size": 3000,  # 3GB
        "reth_volume_size": 3000,  # 3GB
        "reth_builder_volume_size": 3000,  # 3GB
        "ethereumjs_volume_size": 3000,  # 3GB
        "nimbus_eth1_volume_size": 3000,  # 3GB
        "prysm_volume_size": 1000,  # 1GB
        "lighthouse_volume_size": 1000,  # 1GB
        "teku_volume_size": 1000,  # 1GB
        "nimbus_volume_size": 1000,  # 1GB
        "lodestar_volume_size": 1000,  # 1GB
        "grandine_volume_size": 1000,  # 1GB
    },
    "kurtosis": {
        "geth_volume_size": 5000,  # 5GB
        "erigon_volume_size": 3000,  # 3GB
        "nethermind_volume_size": 3000,  # 3GB
        "besu_volume_size": 3000,  # 3GB
        "reth_volume_size": 3000,  # 3GB
        "reth_builder_volume_size": 3000,  # 3GB
        "ethereumjs_volume_size": 3000,  # 3GB
        "nimbus_eth1_volume_size": 3000,  # 3GB
        "prysm_volume_size": 1000,  # 1GB
        "lighthouse_volume_size": 1000,  # 1GB
        "teku_volume_size": 1000,  # 1GB
        "nimbus_volume_size": 1000,  # 1GB
        "lodestar_volume_size": 1000,  # 1GB
        "grandine_volume_size": 1000,  # 1GB
    },
    "hoodi": {
        "geth_volume_size": 100000,  # 100GB
        "erigon_volume_size": 200000,  # 200GB
        "nethermind_volume_size": 100000,  # 100GB
        "besu_volume_size": 100000,  # 100GB
        "reth_volume_size": 300000,  # 300GB
        "reth_builder_volume_size": 300000,  # 300GB
        "ethereumjs_volume_size": 100000,  # 100GB
        "nimbus_eth1_volume_size": 100000,  # 100GB
        "prysm_volume_size": 100000,  # 100GB
        "lighthouse_volume_size": 100000,  # 100GB
        "teku_volume_size": 100000,  # 100GB
        "nimbus_volume_size": 100000,  # 100GB
        "lodestar_volume_size": 100000,  # 100GB
        "grandine_volume_size": 100000,  # 100GB
    },
}
VOLUME_SIZE["mainnet-shadowfork"] = VOLUME_SIZE["mainnet"]
VOLUME_SIZE["sepolia-shadowfork"] = VOLUME_SIZE["sepolia"]
VOLUME_SIZE["holesky-shadowfork"] = VOLUME_SIZE["holesky"]
VOLUME_SIZE["hoodi-shadowfork"] = VOLUME_SIZE["hoodi"]
