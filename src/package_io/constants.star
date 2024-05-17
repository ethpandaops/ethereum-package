EL_TYPE = struct(
    geth_builder="geth-builder",
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
)

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
)

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

KEYMANAGER_MOUNT_PATH_ON_CLIENTS = "/keymanager"
KEYMANAGER_MOUNT_PATH_ON_CONTAINER = (
    KEYMANAGER_MOUNT_PATH_ON_CLIENTS + "/keymanager.txt"
)

MOCK_MEV_TYPE = "mock"
FLASHBOTS_MEV_TYPE = "flashbots"
MEV_RS_MEV_TYPE = "mev-rs"

DEFAULT_SNOOPER_IMAGE = "ethpandaops/rpc-snooper:latest"
DEFAULT_FLASHBOTS_RELAY_IMAGE = "flashbots/mev-boost-relay:0.27"
DEFAULT_FLASHBOTS_BUILDER_IMAGE = "flashbots/builder:latest"
DEFAULT_FLASHBOTS_MEV_BOOST_IMAGE = "flashbots/mev-boost"
DEFAULT_MEV_RS_IMAGE = "ethpandaops/mev-rs:main"
DEFAULT_MEV_RS_IMAGE_MINIMAL = "ethpandaops/mev-rs:main-minimal"
DEFAULT_MEV_PUBKEY = "0xa55c1285d84ba83a5ad26420cd5ad3091e49c55a813eee651cd467db38a8c8e63192f47955e9376f6b42f6d190571cb5"
DEFAULT_MEV_SECRET_KEY = (
    "0x607a11b45a7219cc61a3d9c5fd08c7eebd602a6a19a977f8d3771d5711a550f2"
)

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

GENESIS_FORK_VERSION = "0x10000038"
BELLATRIX_FORK_VERSION = "0x30000038"
CAPELLA_FORK_VERSION = "0x40000038"
DENEB_FORK_VERSION = "0x50000038"
ELECTRA_FORK_VERSION = "0x60000038"
EIP7594_FORK_VERSION = "0x70000038"

ETHEREUM_GENESIS_GENERATOR = struct(
    capella_genesis="ethpandaops/ethereum-genesis-generator:2.0.12",  # Deprecated (no support for minimal config)
    deneb_genesis="ethpandaops/ethereum-genesis-generator:3.1.6",  # Default
    verkle_support_genesis="ethpandaops/ethereum-genesis-generator:3.0.0-rc.19",  # soon to be deneb genesis, waiting for rebase
    verkle_genesis="ethpandaops/ethereum-genesis-generator:verkle-gen-v1.0.0",
)

NETWORK_NAME = struct(
    mainnet="mainnet",
    sepolia="sepolia",
    holesky="holesky",
    ephemery="ephemery",
    kurtosis="kurtosis",
    verkle="verkle",
    shadowfork="shadowfork",
)

PUBLIC_NETWORKS = (
    "mainnet",
    "sepolia",
    "holesky",
)

NETWORK_ID = {
    "mainnet": 1,
    "sepolia": 11155111,
    "holesky": 17000,
}

CHECKPOINT_SYNC_URL = {
    "mainnet": "https://beaconstate.info",
    "sepolia": "https://checkpoint-sync.sepolia.ethpandaops.io",
    "holesky": "https://checkpoint-sync.holesky.ethpandaops.io",
    "ephemery": "https://checkpointz.bordel.wtf/",
}

GENESIS_VALIDATORS_ROOT = {
    "mainnet": "0x4b363db94e286120d76eb905340fdd4e54bfe9f06bf33ff6cf5ad27f511bfe95",
    "sepolia": "0xd8ea171f3c94aea21ebc42a1ed61052acf3f9209c00e4efbaaddac09ed9b8078",
    "holesky": "0x9143aa7c615a7f7115e2b6aac319c03529df8242ae705fba9df39b79c59fa8b1",
}

DEPOSIT_CONTRACT_ADDRESS = {
    "mainnet": "0x00000000219ab540356cBB839Cbe05303d7705Fa",
    "sepolia": "0x7f02C3E3c98b133055B8B348B2Ac625669Ed295D",
    "holesky": "0x4242424242424242424242424242424242424242",
    "ephemery": "0x4242424242424242424242424242424242424242",
}

GENESIS_TIME = {
    "mainnet": 1606824023,
    "sepolia": 1655733600,
    "holesky": 1695902400,
}

VOLUME_SIZE = {
    "mainnet": {
        "geth_volume_size": 1000000,  # 1TB
        "erigon_volume_size": 3000000,  # 3TB
        "nethermind_volume_size": 1000000,  # 1TB
        "besu_volume_size": 1000000,  # 1TB
        "reth_volume_size": 3000000,  # 3TB
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
        "ethereumjs_volume_size": 3000,  # 3GB
        "nimbus_eth1_volume_size": 3000,  # 3GB
        "prysm_volume_size": 1000,  # 1GB
        "lighthouse_volume_size": 1000,  # 1GB
        "teku_volume_size": 1000,  # 1GB
        "nimbus_volume_size": 1000,  # 1GB
        "lodestar_volume_size": 1000,  # 1GB
        "grandine_volume_size": 1000,  # 1GB
    },
}

RAM_CPU_OVERRIDES = {
    "mainnet": {
        "geth_max_mem": 16384,  # 16GB
        "geth_max_cpu": 4000,  # 4 cores
        "erigon_max_mem": 16384,  # 16GB
        "erigon_max_cpu": 4000,  # 4 cores
        "nethermind_max_mem": 16384,  # 16GB
        "nethermind_max_cpu": 4000,  # 4 cores
        "besu_max_mem": 16384,  # 16GB
        "besu_max_cpu": 4000,  # 4 cores
        "reth_max_mem": 16384,  # 16GB
        "reth_max_cpu": 4000,  # 4 cores
        "ethereumjs_max_mem": 16384,  # 16GB
        "ethereumjs_max_cpu": 4000,  # 4 cores
        "nimbus_eth1_max_mem": 16384,  # 16GB
        "nimbus_eth1_max_cpu": 4000,  # 4 cores
        "prysm_max_mem": 16384,  # 16GB
        "prysm_max_cpu": 4000,  # 4 cores
        "lighthouse_max_mem": 16384,  # 16GB
        "lighthouse_max_cpu": 4000,  # 4 cores
        "teku_max_mem": 16384,  # 16GB
        "teku_max_cpu": 4000,  # 4 cores
        "nimbus_max_mem": 16384,  # 16GB
        "nimbus_max_cpu": 4000,  # 4 cores
        "lodestar_max_mem": 16384,  # 16GB
        "lodestar_max_cpu": 4000,  # 4 cores
        "grandine_max_mem": 16384,  # 16GB
        "grandine_max_cpu": 4000,  # 4 cores
    },
    "sepolia": {
        "geth_max_mem": 4096,  # 4GB
        "geth_max_cpu": 1000,  # 1 core
        "erigon_max_mem": 4096,  # 4GB
        "erigon_max_cpu": 1000,  # 1 core
        "nethermind_max_mem": 4096,  # 4GB
        "nethermind_max_cpu": 1000,  # 1 core
        "besu_max_mem": 4096,  # 4GB
        "besu_max_cpu": 1000,  # 1 core
        "reth_max_mem": 4096,  # 4GB
        "reth_max_cpu": 1000,  # 1 core
        "ethereumjs_max_mem": 4096,  # 4GB
        "ethereumjs_max_cpu": 1000,  # 1 core
        "nimbus_eth1_max_mem": 4096,  # 4GB
        "nimbus_eth1_max_cpu": 1000,  # 1 core
        "prysm_max_mem": 4096,  # 4GB
        "prysm_max_cpu": 1000,  # 1 core
        "lighthouse_max_mem": 4096,  # 4GB
        "lighthouse_max_cpu": 1000,  # 1 core
        "teku_max_mem": 4096,  # 4GB
        "teku_max_cpu": 1000,  # 1 core
        "nimbus_max_mem": 4096,  # 4GB
        "nimbus_max_cpu": 1000,  # 1 core
        "lodestar_max_mem": 4096,  # 4GB
        "lodestar_max_cpu": 1000,  # 1 core
        "grandine_max_mem": 4096,  # 4GB
        "grandine_max_cpu": 1000,  # 1 core
    },
    "holesky": {
        "geth_max_mem": 8192,  # 8GB
        "geth_max_cpu": 2000,  # 2 cores
        "erigon_max_mem": 8192,  # 8GB
        "erigon_max_cpu": 2000,  # 2 cores
        "nethermind_max_mem": 8192,  # 8GB
        "nethermind_max_cpu": 2000,  # 2 cores
        "besu_max_mem": 8192,  # 8GB
        "besu_max_cpu": 2000,  # 2 cores
        "reth_max_mem": 8192,  # 8GB
        "reth_max_cpu": 2000,  # 2 cores
        "ethereumjs_max_mem": 8192,  # 8GB
        "ethereumjs_max_cpu": 2000,  # 2 cores
        "nimbus_eth1_max_mem": 8192,  # 8GB
        "nimbus_eth1_max_cpu": 2000,  # 2 cores
        "prysm_max_mem": 8192,  # 8GB
        "prysm_max_cpu": 2000,  # 2 cores
        "lighthouse_max_mem": 8192,  # 8GB
        "lighthouse_max_cpu": 2000,  # 2 cores
        "teku_max_mem": 8192,  # 8GB
        "teku_max_cpu": 2000,  # 2 cores
        "nimbus_max_mem": 8192,  # 8GB
        "nimbus_max_cpu": 2000,  # 2 cores
        "lodestar_max_mem": 8192,  # 8GB
        "lodestar_max_cpu": 2000,  # 2 cores
        "grandine_max_mem": 8192,  # 8GB
        "grandine_max_cpu": 2000,  # 2 cores
    },
    "devnets": {
        "geth_max_mem": 4096,  # 4GB
        "geth_max_cpu": 1000,  # 1 core
        "erigon_max_mem": 4096,  # 4GB
        "erigon_max_cpu": 1000,  # 1 core
        "nethermind_max_mem": 4096,  # 4GB
        "nethermind_max_cpu": 1000,  # 1 core
        "besu_max_mem": 4096,  # 4GB
        "besu_max_cpu": 1000,  # 1 core
        "reth_max_mem": 4096,  # 4GB
        "reth_max_cpu": 1000,  # 1 core
        "ethereumjs_max_mem": 4096,  # 4GB
        "ethereumjs_max_cpu": 1000,  # 1 core
        "nimbus_eth1_max_mem": 4096,  # 4GB
        "nimbus_eth1_max_cpu": 1000,  # 1 core
        "prysm_max_mem": 4096,  # 4GB
        "prysm_max_cpu": 1000,  # 1 core
        "lighthouse_max_mem": 4096,  # 4GB
        "lighthouse_max_cpu": 1000,  # 1 core
        "teku_max_mem": 4096,  # 4GB
        "teku_max_cpu": 1000,  # 1 core
        "nimbus_max_mem": 4096,  # 4GB
        "nimbus_max_cpu": 1000,  # 1 core
        "lodestar_max_mem": 4096,  # 4GB
        "lodestar_max_cpu": 1000,  # 1 core
        "grandine_max_mem": 4096,  # 4GB
        "grandine_max_cpu": 1000,  # 1 core
    },
    "ephemery": {
        "geth_max_mem": 1024,  # 1GB
        "geth_max_cpu": 1000,  # 1 core
        "erigon_max_mem": 1024,  # 1GB
        "erigon_max_cpu": 1000,  # 1 core
        "nethermind_max_mem": 1024,  # 1GB
        "nethermind_max_cpu": 1000,  # 1 core
        "besu_max_mem": 1024,  # 1GB
        "besu_max_cpu": 1000,  # 1 core
        "reth_max_mem": 1024,  # 1GB
        "reth_max_cpu": 1000,  # 1 core
        "ethereumjs_max_mem": 1024,  # 1GB
        "ethereumjs_max_cpu": 1000,  # 1 core
        "nimbus_eth1_max_mem": 1024,  # 1GB
        "nimbus_eth1_max_cpu": 1000,  # 1 core
        "prysm_max_mem": 1024,  # 1GB
        "prysm_max_cpu": 1000,  # 1 core
        "lighthouse_max_mem": 1024,  # 1GB
        "lighthouse_max_cpu": 1000,  # 1 core
        "teku_max_mem": 1024,  # 1GB
        "teku_max_cpu": 1000,  # 1 core
        "nimbus_max_mem": 1024,  # 1GB
        "nimbus_max_cpu": 1000,  # 1 core
        "lodestar_max_mem": 1024,  # 1GB
        "lodestar_max_cpu": 1000,  # 1 core
        "grandine_max_mem": 1024,  # 1GB
        "grandine_max_cpu": 1000,  # 1 core
    },
    "kurtosis": {
        "geth_max_mem": 1024,  # 1GB
        "geth_max_cpu": 1000,  # 1 core
        "erigon_max_mem": 1024,  # 1GB
        "erigon_max_cpu": 1000,  # 1 core
        "nethermind_max_mem": 1024,  # 1GB
        "nethermind_max_cpu": 1000,  # 1 core
        "besu_max_mem": 1024,  # 1GB
        "besu_max_cpu": 1000,  # 1 core
        "reth_max_mem": 1024,  # 1GB
        "reth_max_cpu": 1000,  # 1 core
        "ethereumjs_max_mem": 1024,  # 1GB
        "ethereumjs_max_cpu": 1000,  # 1 core
        "nimbus_eth1_max_mem": 1024,  # 1GB
        "nimbus_eth1_max_cpu": 1000,  # 1 core
        "prysm_max_mem": 1024,  # 1GB
        "prysm_max_cpu": 1000,  # 1 core
        "lighthouse_max_mem": 1024,  # 1GB
        "lighthouse_max_cpu": 1000,  # 1 core
        "teku_max_mem": 2048,  # 2GB
        "teku_max_cpu": 1000,  # 1 core
        "nimbus_max_mem": 1024,  # 1GB
        "nimbus_max_cpu": 1000,  # 1 core
        "lodestar_max_mem": 2048,  # 2GB
        "lodestar_max_cpu": 1000,  # 1 core
        "grandine_max_mem": 2048,  # 2GB
        "grandine_max_cpu": 1000,  # 1 core
    },
}
