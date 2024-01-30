# Ethereum Package

![Run of the Ethereum Network Package](run.gif)

This is a [Kurtosis][kurtosis-repo] package that will spin up a private Ethereum testnet over Docker or Kubernetes with multi-client support, Flashbot's `mev-boost` infrastructure for PBS-related testing/validation, and other useful network tools (transaction spammer, monitoring tools, etc). Kurtosis packages are entirely reproducible and composable, so this will work the same way over Docker or Kubernetes, in the cloud or locally on your machine.

You now have the ability to spin up a private Ethereum testnet or public devnet/testnet (e.g. Goerli, Holesky, Sepolia, dencun-devnet-12, verkle-gen-devnet-2 etc) with a single command. This package is designed to be used for testing, validation, and development of Ethereum clients, and is not intended for production use. For more details check network_params.network in the [configuration section](./README.md#configuration).

Specifically, this [package][package-reference] will:

1. Generate Execution Layer (EL) & Consensus Layer (CL) genesis information using [the Ethereum genesis generator](https://github.com/ethpandaops/ethereum-genesis-generator).
2. Configure & bootstrap a network of Ethereum nodes of *n* size using the genesis data generated above
3. Spin up a [transaction spammer](https://github.com/MariusVanDerWijden/tx-fuzz) to send fake transactions to the network
4. Spin up and connect a [testnet verifier](https://github.com/ethereum/merge-testnet-verifier)
5. Spin up a Grafana and Prometheus instance to observe the network
6. Spin up a Blobscan instance to analyze blob transactions (EIP-4844)

Optional features (enabled via flags or parameter files at runtime):

* Block until the Beacon nodes finalize an epoch (i.e. finalized_epoch > 0)
* Spin up & configure parameters for the infrastructure behind Flashbot's implementation of PBS using `mev-boost`, in either `full` or `mock` mode. More details [here](./README.md#proposer-builder-separation-pbs-implementation-via-flashbots-mev-boost-protocol).
* Spin up & connect the network to a [beacon metrics gazer service](https://github.com/dapplion/beacon-metrics-gazer) to collect network-wide participation metrics.
* Spin up and connect a [JSON RPC Snooper](https://github.com/ethDreamer/json_rpc_snoop) to the network log responses & requests between the EL engine API and the CL client.
* Specify extra parameters to be passed in for any of the: CL client Beacon, and CL client validator, and/or EL client containers
* Specify the required parameters for the nodes to reach an external block building network
* Generate keystores for each node in parallel

## Quickstart

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/new/?editor=code#https://github.com/kurtosis-tech/ethereum-package)

1. [Install Docker & start the Docker Daemon if you haven't done so already][docker-installation]
2. [Install the Kurtosis CLI, or upgrade it to the latest version if it's already installed][kurtosis-cli-installation]
3. Run the package with default configurations from the command line:

   ```bash
   kurtosis run --enclave my-testnet github.com/kurtosis-tech/ethereum-package
   ```

#### Run with your own configuration

Kurtosis packages are parameterizable, meaning you can customize your network and its behavior to suit your needs by storing parameters in a file that you can pass in at runtime like so:

```bash
kurtosis run --enclave my-testnet github.com/kurtosis-tech/ethereum-package "$(cat ~/network_params.yaml)"
```

Where `network_params.yaml` contains the parameters for your network in your home directory.

#### Run on Kubernetes

Kurtosis packages work the same way over Docker or on Kubernetes. Please visit our [Kubernetes docs](https://docs.kurtosis.com/k8s) to learn how to spin up a private testnet on a Kubernetes cluster.

#### Considerations for Running on a Public Testnet with a Cloud Provider
When running on a public testnet using a cloud provider's Kubernetes cluster, there are a few important factors to consider:

1. State Growth: The growth of the state might be faster than anticipated. This could potentially lead to issues if the default parameters become insufficient over time. It's important to monitor state growth and adjust parameters as necessary.

2. Persistent Storage Speed: Most cloud providers provision their Kubernetes clusters with relatively slow persistent storage by default. This can cause performance issues, particularly with Ethereum Light (EL) clients.

3. Network Syncing: The disk speed provided by cloud providers may not be sufficient to sync with networks that have high demands, such as the mainnet. This could lead to syncing issues and delays.

To mitigate these issues, you can use the `el_client_volume_size` and `cl_client_volume_size` flags to override the default settings locally. This allows you to allocate more storage to the EL and CL clients, which can help accommodate faster state growth and improve syncing performance. However, keep in mind that increasing the volume size may also increase your cloud provider costs. Always monitor your usage and adjust as necessary to balance performance and cost.

For optimal performance, we recommend using a cloud provider that allows you to provision Kubernetes clusters with fast persistent storage or self hosting your own Kubernetes cluster with fast persistent storage.

#### Tear down

The testnet will reside in an [enclave][enclave] - an isolated, ephemeral environment. The enclave and its contents (e.g. running containers, files artifacts, etc) will persist until torn down. You can remove an enclave and its contents with:

```bash
kurtosis enclave rm -f my-testnet
```

## Management

The [Kurtosis CLI](https://docs.kurtosis.com/cli) can be used to inspect and interact with the network.

For example, if you need shell access, simply run:

```bash
kurtosis service shell my-testnet $SERVICE_NAME
```

And if you need the logs for a service, simply run:

```bash
kurtosis service logs my-testnet $SERVICE_NAME
```

Check out the full list of CLI commands [here](https://docs.kurtosis.com/cli)

## Debugging

To grab the genesis files for the network, simply run:

```bash
kurtosis files download my-testnet $FILE_NAME $OUTPUT_DIRECTORY
```

For example, to retrieve the Execution Layer (EL) genesis data, run:

```bash
kurtosis files download my-testnet el-genesis-data ~/Downloads
```

## Configuration

To configure the package behaviour, you can modify your `network_params.yaml` file. The full YAML schema that can be passed in is as follows with the defaults provided:

```yaml
# Specification of the participants in the network
participants:
  # The type of EL client that should be started
  # Valid values are geth, nethermind, erigon, besu, ethereumjs, reth
- el_client_type: geth

  # The Docker image that should be used for the EL client; leave blank to use the default for the client type
  # Defaults by client:
  # - geth: ethereum/client-go:latest
  # - erigon: thorax/erigon:devel
  # - nethermind: nethermind/nethermind:latest
  # - besu: hyperledger/besu:develop
  # - reth: ghcr.io/paradigmxyz/reth
  # - ethereumjs: ethpandaops/ethereumjs:master
  el_client_image: ""

  # The log level string that this participant's EL client should log at
  # If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
  # global `logLevel` = `info` then Geth would receive `3`, Besu would receive `INFO`, etc.)
  # If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
  # over a specific participant's logging
  el_client_log_level: ""

  # A list of optional extra params that will be passed to the EL client container for modifying its behaviour
  el_extra_params: []

  # A list of optional extra env_vars the el container should spin up with
  el_extra_env_vars: {}

  # Persistent storage size for the EL client container (in MB)
  # Defaults to 0, which means that the default size for the client will be used
  # Default values can be found in /src/package_io/constants.star VOLUME_SIZE
  el_client_volume_size: 0

  # A list of optional extra labels the el container should spin up with
  # Example; el_extra_labels: {"ethereum-package.partition": "1"}
  el_extra_labels: {}

  # The type of CL client that should be started
  # Valid values are nimbus, lighthouse, lodestar, teku, and prysm
  cl_client_type: lighthouse

  # The Docker image that should be used for the EL client; leave blank to use the default for the client type
  # Defaults by client (note that Prysm is different in that it requires two images - a Beacon and a validator - separated by a comma):
  # - lighthouse: sigp/lighthouse:latest
  # - teku: consensys/teku:latest
  # - nimbus: statusim/nimbus-eth2:multiarch-latest
  # - prysm: gcr.io/prysmaticlabs/prysm/beacon-chain:latest,gcr.io/prysmaticlabs/prysm/validator:latest
  # - lodestar: chainsafe/lodestar:next
  cl_client_image: ""

  # The log level string that this participant's EL client should log at
  # If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
  # global `logLevel` = `info` then Teku would receive `INFO`, Prysm would receive `info`, etc.)
  # If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
  # over a specific participant's logging
  cl_client_log_level: ""

  # A list of optional extra params that will be passed to the CL to run separate Beacon and validator nodes
  # Only possible for nimbus or teku
  # Please note that in order to get it to work with Nimbus, you have to use `ethpandaops/nimbus:unstable` as the image (default upstream image does not yet support this out of the box)
  # Defaults to false
  cl_split_mode_enabled: false

  # Persistent storage size for the CL client container (in MB)
  # Defaults to 0, which means that the default size for the client will be used
  # Default values can be found in /src/package_io/constants.star VOLUME_SIZE
  cl_client_volume_size: 0

  # A list of optional extra params that will be passed to the CL client Beacon container for modifying its behaviour
  # If the client combines the Beacon & validator nodes (e.g. Teku, Nimbus), then this list will be passed to the combined Beacon-validator node
  beacon_extra_params: []

  # A list of optional extra labels that will be passed to the CL client Beacon container.
  # Example; beacon_extra_labels: {"ethereum-package.partition": "1"}
  beacon_extra_labels: {}

  # A list of optional extra params that will be passed to the CL client validator container for modifying its behaviour
  # If the client combines the Beacon & validator nodes (e.g. Teku, Nimbus), then this list will also be passed to the combined Beacon-validator node
  validator_extra_params: []

  # A list of optional extra labels that will be passed to the CL client validator container.
  # Example; validator_extra_labels: {"ethereum-package.partition": "1"}
  validator_extra_labels: {}

  # A set of parameters the node needs to reach an external block building network
  # If `null` then the builder infrastructure will not be instantiated
  # Example:
  #
  # "relay_endpoints": [
  #  "https:#0xdeadbeefcafa@relay.example.com",
  #  "https:#0xdeadbeefcafb@relay.example.com",
  #  "https:#0xdeadbeefcafc@relay.example.com",
  #  "https:#0xdeadbeefcafd@relay.example.com"
  # ]
  builder_network_params: null

  # Resource management for el/beacon/validator containers
  # CPU is milicores
  # RAM is in MB
  # Defaults are set per client
  el_min_cpu: 0
  el_max_cpu: 0
  el_min_mem: 0
  el_max_mem: 0
  bn_min_cpu: 0
  bn_max_cpu: 0
  bn_min_mem: 0
  bn_max_mem: 0
  v_min_cpu: 0
  v_max_cpu: 0
  v_min_mem: 0
  v_max_mem: 0

  # Snooper can be enabled with the `snooper_enabled` flag per client or globally
  # Defaults to false
  snooper_enabled: false

  # Enables Ethereum Metrics Exporter for this participant. Can be set globally.
  # Defaults to false
  ethereum_metrics_exporter_enabled: false

  # Enables Xatu Sentry for this participant. Can be set globally.
  # Defaults to false
  xatu_sentry_enabled: false

  # Count of nodes to spin up for this participant
  # Default to 1
  count: 1

  # Count of the number of validators you want to run for a given participant
  # Default to null, which means that the number of validators will be using the
  # network parameter num_validator_keys_per_node
  validator_count: null

  # Prometheus additional configuration for a given participant prometheus target.
  # Execution, beacon and validator client targets on prometheus will include this
  # configuration.
  prometheus_config:
    # Scrape interval to be used. Default to 15 seconds
    scrape_interval: 15s
    # Additional labels to be added. Default to empty
    labels: {}

  # Blobber can be enabled with the `blobber_enabled` flag per client or globally
  # Defaults to false
  blobber_enabled: false

  # Blobber extra params can be passed in to the blobber container
  # Defaults to empty
  blobber_extra_params: []

# Default configuration parameters for the Eth network
network_params:
  # The network ID of the network.
  network_id: 3151908

  # The address of the staking contract address on the Eth1 chain
  deposit_contract_address: "0x4242424242424242424242424242424242424242"

  # Number of seconds per slot on the Beacon chain
  seconds_per_slot: 12

  # The number of validator keys that each CL validator node should get
  num_validator_keys_per_node: 64

  # This mnemonic will a) be used to create keystores for all the types of validators that we have and b) be used to generate a CL genesis.ssz that has the children
  # validator keys already preregistered as validators
  preregistered_validator_keys_mnemonic: "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete"
  # The number of pre-registered validators for genesis. If 0 or not specified then the value will be calculated from the participants
  preregistered_validator_count: 0
  # How long you want the network to wait before starting up
  genesis_delay: 20

  # Max churn rate for the network introduced by
  # EIP-7514 https:#eips.ethereum.org/EIPS/eip-7514
  # Defaults to 8
  max_churn: 8

  # Ejection balance
  # Defaults to 16ETH
  # 16000000000 gwei
  ejection_balance: 16000000000,

  # ETH1 follow distance
  # Defaults to 2048
  eth1_follow_distance: 2048

  # The epoch at which the capella and deneb forks are set to occur.
  capella_fork_epoch: 0
  deneb_fork_epoch: 500
  electra_fork_epoch: null

  # Network name, used to enable syncing of alternative networks
  # Defaults to "kurtosis"
  # You can sync any public network by setting this to the network name (e.g. "mainnet", "goerli", "sepolia", "holesky")
  # You can sync any devnet by setting this to the network name (e.g. "dencun-devnet-12", "verkle-gen-devnet-2")
  network: "kurtosis"

# Configuration place for transaction spammer - https:#github.com/MariusVanDerWijden/tx-fuzz
tx_spammer_params:
  # A list of optional extra params that will be passed to the TX Spammer container for modifying its behaviour
  tx_spammer_extra_args: []

# Configuration place for goomy the blob spammer - https:#github.com/ethpandaops/goomy-blob
goomy_blob_params:
  # A list of optional params that will be passed to the blob-spammer comamnd for modifying its behaviour
  goomy_blob_args: []

# Configuration place for the assertoor testing tool - https:#github.com/ethpandaops/assertoor
assertoor_params:
  # Check chain stability
  # This check monitors the chain and succeeds if:
  # - all clients are synced
  # - chain is finalizing for min. 2 epochs
  # - >= 98% correct target votes
  # - >= 80% correct head votes
  # - no reorgs with distance > 2 blocks
  # - no more than 2 reorgs per epoch
  run_stability_check: true

  # Check block propöosals
  # This check monitors the chain and succeeds if:
  # - all client pairs have proposed a block
  run_block_proposal_check: true

  # Run normal transaction test
  # This test generates random EOA transactions and checks inclusion with/from all client pairs
  # This test checks for:
  # - block proposals with transactions from all client pairs
  # - transaction inclusion when submitting via each client pair
  # test is done twice, first with legacy (type 0) transactions, then with dynfee (type 2) transactions
  run_transaction_test: false

  # Run blob transaction test
  # This test generates blob transactions and checks inclusion with/from all client pairs
  # This test checks for:
  # - block proposals with blobs from all client pairs
  # - blob inclusion when submitting via each client pair
  run_blob_transaction_test: false

  # Run all-opcodes transaction test
  # This test generates a transaction that triggers all EVM OPCODES once
  # This test checks for:
  # - all-opcodes transaction success
  run_opcodes_transaction_test: false

  # Run validator lifecycle test (~48h to complete)
  # This test requires exactly 500 active validator keys.
  # The test will cause a temporary chain unfinality when running.
  # This test checks:
  # - Deposit inclusion with/from all client pairs
  # - BLS Change inclusion with/from all client pairs
  # - Voluntary Exit inclusion with/from all client pairs
  # - Attester Slashing inclusion with/from all client pairs
  # - Proposer Slashing inclusion with/from all client pairs
  # all checks are done during finality & unfinality
  run_lifecycle_test: false

  # Run additional tests from external test definitions
  # eg:
  #   - https://raw.githubusercontent.com/ethpandaops/assertoor/master/example/tests/block-proposal-check.yaml
  tests: []


# By default includes
# - A transaction spammer & blob spammer is launched to fake transactions sent to the network
# - Forkmon for EL will be launched
# - A prometheus will be started, coupled with grafana
# - A beacon metrics gazer will be launched
# - A light beacon chain explorer will be launched
# - Default: ["tx_spammer", "blob_spammer", "el_forkmon", "beacon_metrics_gazer", "blockscout", "dora"," "prometheus_grafana"]
additional_services:
  - assertoor
  - broadcaster
  - tx_spammer
  - blob_spammer
  - custom_flood
  - goomy_blob
  - el_forkmon
  - beacon_metrics_gazer
  - dora
  - full_beaconchain_explorer
  - blockscout
  - prometheus_grafana
  - blobscan

# If set, the package will block until a finalized epoch has occurred.
wait_for_finalization: false

# The global log level that all clients should log at
# Valid values are "error", "warn", "info", "debug", and "trace"
# This value will be overridden by participant-specific values
global_client_log_level: "info"

# EngineAPI Snooper global flags for all participants
# Default to false
snooper_enabled: false

# Enables Ethereum Metrics Exporter for all participants
# Defaults to false
ethereum_metrics_exporter_enabled: false

# Parallelizes keystore generation so that each node has keystores being generated in their own container
# This will result in a large number of containers being spun up than normal. We advise users to only enable this on a sufficiently large machine or in the cloud as it can be resource consuming on a single machine.
parallel_keystore_generation: false

# Disable peer scoring to prevent nodes impacted by faults from being permanently ejected from the network
# Default to false
disable_peer_scoring: false

# A list of locators for grafana dashboards to be loaded be the grafana service
grafana_additional_dashboards: []

# Whether the environment should be persistent; this is WIP and is slowly being rolled out accross services
# Note this requires Kurtosis greater than 0.85.49 to work
# Note Erigon, Besu, Teku persistence is not currently supported with docker.
# Defaults to false
persistent: false

# Supports three valeus
# Default: "null" - no mev boost, mev builder, mev flood or relays are spun up
# "mock" - mock-builder & mev-boost are spun up
# "full" - mev-boost, relays, flooder and builder are all spun up
# Users are recommended to set network_params.capella_fork_epoch to non zero when testing MEV
# We have seen instances of multibuilder instances failing to start mev-relay-api with non zero epochs
mev_type: null

# Parameters if MEV is used
mev_params:
  # The image to use for MEV boot relay
  mev_relay_image: flashbots/mev-boost-relay
  # The image to use for the builder
  mev_builder_image: ethpandaops/flashbots-builder:main
  # The image to use for the CL builder
  mev_builder_cl_image: sigp/lighthouse:latest
  # The image to use for mev-boost
  mev_boost_image: flashbots/mev-boost
  # Extra parameters to send to the API
  mev_relay_api_extra_args: []
  # Extra parameters to send to the housekeeper
  mev_relay_housekeeper_extra_args: []
  # Extra parameters to send to the website
  mev_relay_website_extra_args: []
  # Extra parameters to send to the builder
  mev_builder_extra_args: []
  # Prometheus additional configuration for the mev builder participant.
  # Execution, beacon and validator client targets on prometheus will include this configuration.
  mev_builder_prometheus_config:
    # Scrape interval to be used. Default to 15 seconds
    scrape_interval: 15s
    # Additional labels to be added. Default to empty
    labels: {}
  # Image to use for mev-flood
  mev_flood_image: flashbots/mev-flood
  # Extra parameters to send to mev-flood
  mev_flood_extra_args: []
  # Number of seconds between bundles for mev-flood
  mev_flood_seconds_per_bundle: 15
  # Optional parameters to send to the custom_flood script that sends reliable payloads
  custom_flood_params:
    interval_between_transactions: 1

# Enables Xatu Sentry for all participants
# Defaults to false
xatu_sentry_enabled: false

# Xatu Sentry params
xatu_sentry_params:
  # The image to use for Xatu Sentry
  xatu_sentry_image: ethpandaops/xatu:latest
  # GRPC Endpoint of Xatu Server to send events to
  xatu_server_addr: localhost:8080
  # Enables TLS to Xatu Server
  xatu_server_tls: false
  # Headers to add on to Xatu Server requests
  xatu_server_headers: {}
  # Beacon event stream topics to subscribe to
  beacon_subscriptions:
  - attestation
  - block
  - chain_reorg
  - finalized_checkpoint
  - head
  - voluntary_exit
  - contribution_and_proof
  - blob_sidecar
```

#### Example configurations

<details>
    <summary>Verkle configuration example</summary>

```yaml
participants:
  - el_client_type: geth
    el_client_image: ethpandaops/geth:<VERKLE_IMAGE>
    elExtraParams:
    - "--override.verkle=<UNIXTIMESTAMP>"
    cl_client_type: lighthouse
    cl_client_image: sigp/lighthouse:latest
  - el_client_type: geth
    el_client_image: ethpandaops/geth:<VERKLE_IMAGE>
    elExtraParams:
    - "--override.verkle=<UNIXTIMESTAMP>"
    cl_client_type: lighthouse
    cl_client_image: sigp/lighthouse:latest
  - el_client_type: geth
    el_client_image: ethpandaops/geth:<VERKLE_IMAGE>
    elExtraParams:
    - "--override.verkle=<UNIXTIMESTAMP>"
    cl_client_type: lighthouse
    cl_client_image: sigp/lighthouse:latest
network_params:
  capella_fork_epoch: 2
  deneb_fork_epoch: 5
additional_services: []
wait_for_finalization: false
wait_for_verifications: false
global_client_log_level: info

```

</details>

<details>
    <summary>A 3-node Ethereum network with "mock" MEV mode.</summary>
    Useful for testing mev-boost and the client implementations without adding the complexity of the relay. This can be enabled by a single config command and would deploy the [mock-builder](https://github.com/marioevz/mock-builder), instead of the relay infrastructure.

```yaml
participants:
  - el_client_type: geth
    el_client_image: ''
    cl_client_type: lighthouse
    cl_client_image: ''
    count: 2
  - el_client_type: nethermind
    el_client_image: ''
    cl_client_type: teku
    cl_client_image: ''
    count: 1
  - el_client_type: besu
    el_client_image: ''
    cl_client_type: prysm
    cl_client_image: ''
    count: 2
mev_type: mock
additional_services: []
```

</details>

<details>
    <summary>A 5-node Ethereum network with three different CL and EL client combinations and mev-boost infrastructure in "full" mode.</summary>

```yaml
participants:
  - el_client_type: geth
    cl_client_type: lighthouse
    count: 2
  - el_client_type: nethermind
    cl_client_type: teku
  - el_client_type: besu
    cl_client_type: prysm
    count: 2
mev_type: full
network_params:
  capella_fork_epoch: 1
additional_services: []

```

</details>

<details>
    <summary>A 2-node geth/lighthouse network with optional services (Grafana, Prometheus, transaction-spammer, EngineAPI snooper, and a testnet verifier)</summary>

```yaml
participants:
  - el_client_type: geth
    cl_client_type: lighthouse
    count: 2
snooper_enabled: true
```

</details>

## Custom labels for Docker and Kubernetes

There are 4 custom labels that can be used to identify the nodes in the network. These labels are used to identify the nodes in the network and can be used to run chaos tests on specific nodes. An example for these labels are as follows:

Execution Layer (EL) nodes:

```sh
  "com.kurtosistech.custom.ethereum-package-client": "geth",
  "com.kurtosistech.custom.ethereum-package-client-image": "ethereum-client-go-latest",
  "com.kurtosistech.custom.ethereum-package-client-type": "execution",
  "com.kurtosistech.custom.ethereum-package-connected-client": "lighthouse",
```

Consensus Layer (CL) nodes - Beacon:

```sh
  "com.kurtosistech.custom.ethereum-package-client": "lighthouse",
  "com.kurtosistech.custom.ethereum-package-client-image": "sigp-lighthouse-latest",
  "com.kurtosistech.custom.ethereum-package-client-type": "beacon",
  "com.kurtosistech.custom.ethereum-package-connected-client": "geth",
```

Consensus Layer (CL) nodes - Validator:

```sh
  "com.kurtosistech.custom.ethereum-package-client": "lighthouse",
  "com.kurtosistech.custom.ethereum-package-client-image": "sigp-lighthouse-latest",
  "com.kurtosistech.custom.ethereum-package-client-type": "validator",
  "com.kurtosistech.custom.ethereum-package-connected-client": "geth",
```

`ethereum-package-client` describes which client is running on the node.
`ethereum-package-client-image` describes the image that is used for the client.
`ethereum-package-client-type` describes the type of client that is running on the node (`execution`,`beacon` or `validator`).
`ethereum-package-connected-client` describes the CL/EL client that is connected to the EL/CL client.

## Proposer Builder Separation (PBS) emulation

To spin up the network of Ethereum nodes with an external block building network (using Flashbot's `mev-boost` protocol), simply use:

```
kurtosis run github.com/kurtosis-tech/ethereum-package '{"mev_type": "full"}'
```

Starting your network up with `"mev_type": "full"` will instantiate and connect the following infrastructure to your network:

1. `Flashbot's block builder & CL validator + beacon` - A modified Geth client that builds blocks. The CL validator and beacon clients are lighthouse clients configured to receive payloads from the relay.
2. `mev-relay-api` - Services that provide APIs for (a) proposers, (b) block builders, (c) data
3. `mev-relay-website` - A website to monitor payloads that have been delivered
4. `mev-relay-housekeeper` - Updates known validators, proposer duties, and more in the background. Only a single instance of this should run.
5. `mev-boost` - open-source middleware instantiated for each EL/Cl pair in the network, including the builder
6. `mev-flood` - Deploys UniV2 smart contracts, provisions liquidity on UniV2 pairs, & sends a constant stream of UniV2 swap transactions to the network's public mempool.

<details>
    <summary>Caveats when using "mev_type": "full"</summary>

* Validators (64 per node by default, so 128 in the example in this guide) will get registered with the relay automatically after the 1st epoch. This registration process is simply a configuration addition to the mev-boost config - which Kurtosis will automatically take care of as part of the set up. This means that the mev-relay infrastructure only becomes aware of the existence of the validators after the 1st epoch.
* After the 3rd epoch, the mev-relay service will begin to receive execution payloads (eth_sendPayload, which does not contain transaction content) from the mev-builder service (or mock-builder in mock-mev mode).
* Validators will start to receive validated execution payload headers from the mev-relay service (via mev-boost) after the 4th epoch. The validator selects the most valuable header, signs the payload, and returns the signed header to the relay - effectively proposing the payload of transactions to be included in the soon-to-be-proposed block. Once the relay verifies the block proposer's signature, the relay will respond with the full execution payload body (incl. the transaction contents) for the validator to use when proposing a SignedBeaconBlock to the network.

It is recommended to use non zero value for `capella_fork_epoch` by setting `network_params.capella_fork_epoch` to a non-zero value
in the arguments passed with `mev_type` set to `full`.
</details>

This package also supports a `"mev_type": "mock"` mode that will only bring up:

1. `mock-builder` - a server that listens for builder API directives and responds with payloads built using an execution client
1. `mev-boost` - for every EL/CL pair launched

For more details, including a guide and architecture of the `mev-boost` infrastructure, go [here](https://docs.kurtosis.com/how-to-full-mev-with-ethereum-package/).

## MEV-Boost usage with Capella at Epoch 0

This note is from 2023-10-05

`flashbots/mev-boost-relay:0.27` and later support `capella_fork_epoch` at `0` but this seems to require a few flags enabled
on the `lighthouse` beacon client including `--always-prefer-builder-payload` and `--disable-peer-scoring`

Users are recommended to browse the example tests [`./.github/tests`](./.github/tests); as inspiration for different ways to use the package.

## Pre-funded accounts at Genesis

This package comes with [seven prefunded keys for testing](https://github.com/kurtosis-tech/ethereum-package/blob/main/src/prelaunch_data_generator/genesis_constants/genesis_constants.star).

Here's a table of where the keys are used

| Account Index | Component Used In   | Private Key Used | Public Key Used | Comment                     |
|---------------|---------------------|------------------|-----------------|-----------------------------|
| 0             | Builder             | ✅                |                 | As coinbase                |
| 0             | mev_custom_flood    |                  | ✅              | As the receiver of balance |
| 1             | blob_spammer        | ✅                |                 | As the sender of blobs     |
| 3             | transaction_spammer | ✅                |                 | To spam transactions with  |
| 4              | goomy_blob         | ✅                |                 | As the sender of blobs     |
| 5             | eip4788_deployment  | ✅                |                 | As contract deployer       |
| 6             | mev_flood           | ✅                |                 | As the contract owner      |
| 7             | mev_flood           | ✅                |                 | As the user_key            |
| 8             | assertoor           | ✅                | ✅              | As the funding for tests   |
| 11            | mev_custom_flood    | ✅                |                 | As the sender of balance   |

## Developing On This Package

First, install prerequisites:

1. [Install Kurtosis itself][kurtosis-cli-installation]

Then, run the dev loop:

1. Make your code changes
1. Rebuild and re-run the package by running the following from the root of the repo:

   ```bash
   kurtosis run . "{}"
   ```

   NOTE 1: You can change the value of the second positional argument flag to pass in extra configuration to the package per the "Configuration" section above!
   NOTE 2: The second positional argument accepts JSON.

To get detailed information about the structure of the package, visit [the architecture docs](./docs/architecture.md).

When you're happy with your changes:

1. Create a PR
1. Add one of the maintainers of the repo as a "Review Request":
   * `parithosh` (Ethereum Foundation)
   * `barnabasbusa` (Ethereum Foundation)
   * `pk910` (Ethereum Foundation)
   * `samcm` (Ethereum Foundation)
   * `h4ck3rk3y` (Kurtosis)
   * `mieubrisse` (Kurtosis)
   * `leederek` (Kurtosis)
1. Once everything works, merge!

<!------------------------ Only links below here -------------------------------->

[docker-installation]: https://docs.docker.com/get-docker/
[kurtosis-cli-installation]: https://docs.kurtosis.com/install
[kurtosis-repo]: https://github.com/kurtosis-tech/kurtosis
[enclave]: https://docs.kurtosis.com/advanced-concepts/enclaves/
[package-reference]: https://docs.kurtosis.com/advanced-concepts/packages
