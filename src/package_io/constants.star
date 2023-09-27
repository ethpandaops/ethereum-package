EL_CLIENT_TYPE = struct(
    geth="geth",
    erigon="erigon",
    nethermind="nethermind",
    besu="besu",
    reth="reth",
    ethereumjs="ethereumjs",
)

CL_CLIENT_TYPE = struct(
    lighthouse="lighthouse",
    teku="teku",
    nimbus="nimbus",
    prysm="prysm",
    lodestar="lodestar",
)

GLOBAL_CLIENT_LOG_LEVEL = struct(
    info="info",
    error="error",
    warn="warn",
    debug="debug",
    trace="trace",
)

VALIDATING_REWARDS_ACCOUNT = "0x878705ba3f8Bc32FCf7F4CAa1A35E72AF65CF766"
MAX_ENR_ENTRIES = 20
MAX_ENODE_ENTRIES = 20

GENESIS_VALIDATORS_ROOT_PLACEHOLDER = "GENESIS_VALIDATORS_ROOT_PLACEHOLDER"

DEFAULT_SNOOPER_IMAGE = "parithoshj/json_rpc_snoop:v1.0.0-x86"

ARCHIVE_MODE = True
