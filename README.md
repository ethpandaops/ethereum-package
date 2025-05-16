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

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/new/?editor=code#https://github.com/ethpandaops/ethereum-package)

1. [Install Docker & start the Docker Daemon if you haven't done so already][docker-installation]
2. [Install the Kurtosis CLI, or upgrade it to the latest version if it's already installed][kurtosis-cli-installation]
3. Run the package with default configurations from the command line:

   ```bash
   kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package
   ```

#### Run with your own configuration

Kurtosis packages are parameterizable, meaning you can customize your network and its behavior to suit your needs by storing parameters in a file that you can pass in at runtime like so:

```bash
kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package --args-file network_params.yaml
```

Where `network_params.yaml` contains the parameters for your network in your home directory.

#### Run on Kubernetes

Kurtosis packages work the same way over Docker or on Kubernetes. Please visit our [Kubernetes docs](https://docs.kurtosis.com/k8s) to learn how to spin up a private testnet on a Kubernetes cluster.

#### Considerations for Running on a Public Testnet with a Cloud Provider
When running on a public testnet using a cloud provider's Kubernetes cluster, there are a few important factors to consider:

1. State Growth: The growth of the state might be faster than anticipated. This could potentially lead to issues if the default parameters become insufficient over time. It's important to monitor state growth and adjust parameters as necessary.

2. Persistent Storage Speed: Most cloud providers provision their Kubernetes clusters with relatively slow persistent storage by default. This can cause performance issues, particularly with Execution Layer (EL) clients.

3. Network Syncing: The disk speed provided by cloud providers may not be sufficient to sync with networks that have high demands, such as the mainnet. This could lead to syncing issues and delays.

To mitigate these issues, you can use the `el_volume_size` and `cl_volume_size` flags to override the default settings locally. This allows you to allocate more storage to the EL and CL clients, which can help accommodate faster state growth and improve syncing performance. However, keep in mind that increasing the volume size may also increase your cloud provider costs. Always monitor your usage and adjust as necessary to balance performance and cost.

For optimal performance, we recommend using a cloud provider that allows you to provision Kubernetes clusters with fast persistent storage or self hosting your own Kubernetes cluster with fast persistent storage.

### Shadowforking
In order to enable shadowfork capabilities, you can use the `network_params.network` flag. The expected value is the name of the network you want to shadowfork followed by `-shadowfork`. Please note that `persistent` configuration parameter has to be enabled for shadowforks to work! Current limitation on k8s is it is only working on a single node cluster. For example, to shadowfork the Holesky testnet, you can use the following command:
```yaml
...
network_params:
  network: "holesky-shadowfork"
persistent: true
...
```

##### Shadowforking custom verkle networks
In order to enable shadowfork capabilities for verkle networks, you need to define electra and mention verkle in the network name after shadowfork.
```yaml
...
network_params:
  electra_fork_epoch: 1
  network: "holesky-shadowfork-verkle"
persistent: true
...
```

#### Taints and tolerations
It is possible to run the package on a Kubernetes cluster with taints and tolerations. This is done by adding the tolerations to the `tolerations` field in the `network_params.yaml` file. For example:
```yaml
participants:
  - el_type: reth
    cl_type: teku
global_tolerations:
  - key: "node-role.kubernetes.io/master6"
    value: "true"
    operator: "Equal"
    effect: "NoSchedule"
```

It is possible to define toleration globally, per participant or per container. The order of precedence is as follows:
1. Container (`el_tolerations`, `cl_tolerations`, `vc_tolerations`)
2. Participant (`tolerations`)
3. Global (`global_tolerations`)

This feature is only available for Kubernetes. To learn more about taints and tolerations, please visit the [Kubernetes documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/).

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

# Basic file sharing

Apache is included in the package to allow for basic file sharing. The Apache service is started when additional services are enabled. It will expose the network-configs directory, which might needed if you want to share the network config publicly.

```yaml
additional_services:
  - apache
```

## Configuration

To configure the package behaviour, you can modify your `network_params.yaml` file. The full YAML schema that can be passed in is as follows with the defaults provided:

```yaml
# Specification of the participants in the network
participants:
  # EL(Execution Layer) Specific flags
    # The type of EL client that should be started
    # Valid values are geth, nethermind, erigon, besu, ethereumjs, reth, nimbus-eth1
  - el_type: geth

    # The Docker image that should be used for the EL client; leave blank to use the default for the client type
    # Defaults by client:
    # - geth: ethereum/client-go:latest
    # - erigon: ethpandaops/erigon:main
    # - nethermind: nethermind/nethermind:latest
    # - besu: hyperledger/besu:develop
    # - reth: ghcr.io/paradigmxyz/reth
    # - ethereumjs: ethpandaops/ethereumjs:master
    # - nimbus-eth1: ethpandaops/nimbus-eth1:master
    el_image: ""

    # The log level string that this participant's EL client should log at
    # If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
    # global `logLevel` = `info` then Geth would receive `3`, Besu would receive `INFO`, etc.)
    # If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
    # over a specific participant's logging
    el_log_level: ""

    # A list of optional extra env_vars the el container should spin up with
    el_extra_env_vars: {}

    # A list of optional extra labels the el container should spin up with
    # Example; el_extra_labels: {"ethereum-package.partition": "1"}
    el_extra_labels: {}

    # A list of optional extra params that will be passed to the EL client container for modifying its behaviour
    el_extra_params: []

    # A list of tolerations that will be passed to the EL client container
    # Only works with Kubernetes
    # Example: el_tolerations:
    # - key: "key"
    #   operator: "Equal"
    #   value: "value"
    #   effect: "NoSchedule"
    #   toleration_seconds: 3600
    # Defaults to empty
    el_tolerations: []

    # Persistent storage size for the EL client container (in MB)
    # Defaults to 0, which means that the default size for the client will be used
    # Default values can be found in /src/package_io/constants.star VOLUME_SIZE
    el_volume_size: 0

    # Resource management for el containers
    # CPU is milicores
    # RAM is in MB
    # Defaults to 0, which results in no resource limits
    el_min_cpu: 0
    el_max_cpu: 0
    el_min_mem: 0
    el_max_mem: 0

  # CL(Consensus Layer) Specific flags
    # The type of CL client that should be started
    # Valid values are nimbus, lighthouse, lodestar, teku, prysm, and grandine
    cl_type: lighthouse

    # The Docker image that should be used for the CL client; leave blank to use the default for the client type
    # Defaults by client:
    # - lighthouse: sigp/lighthouse:latest
    # - teku: consensys/teku:latest
    # - nimbus: statusim/nimbus-eth2:multiarch-latest
    # - prysm: gcr.io/prysmaticlabs/prysm/beacon-chain:latest
    # - lodestar: chainsafe/lodestar:next
    # - grandine: sifrai/grandine:stable
    cl_image: ""

    # The log level string that this participant's CL client should log at
    # If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
    # global `logLevel` = `info` then Teku would receive `INFO`, Prysm would receive `info`, etc.)
    # If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
    # over a specific participant's logging
    cl_log_level: ""

    # A list of optional extra env_vars the cl container should spin up with
    cl_extra_env_vars: {}

    # A list of optional extra labels that will be passed to the CL client Beacon container.
    # Example; cl_extra_labels: {"ethereum-package.partition": "1"}
    cl_extra_labels: {}

    # A list of optional extra params that will be passed to the CL client Beacon container for modifying its behaviour
    # If the client combines the Beacon & validator nodes (e.g. Teku, Nimbus), then this list will be passed to the combined Beacon-validator node
    cl_extra_params: []

    # A list of tolerations that will be passed to the CL client container
    # Only works with Kubernetes
    # Example: el_tolerations:
    # - key: "key"
    #   operator: "Equal"
    #   value: "value"
    #   effect: "NoSchedule"
    #   toleration_seconds: 3600
    # Defaults to empty
    cl_tolerations: []

    # Persistent storage size for the CL client container (in MB)
    # Defaults to 0, which means that the default size for the client will be used
    # Default values can be found in /src/package_io/constants.star VOLUME_SIZE
    cl_volume_size: 0

    # Resource management for cl containers
    # CPU is milicores
    # RAM is in MB
    # Defaults to 0, which results in no resource limits
    cl_min_cpu: 0
    cl_max_cpu: 0
    cl_min_mem: 0
    cl_max_mem: 0

    # Whether to act as a supernode for the network
    # Supernodes will subscribe to all subnet topics
    # This flag should only be used with peerdas
    # Defaults to false
    supernode: false

    # Whether to use a separate validator client attached to the CL client.
    # Defaults to false for clients that can run both in one process (Teku, Nimbus)
    use_separate_vc: true

  # VC (Validator Client) Specific flags
    # The type of validator client that should be used
    # Valid values are nimbus, lighthouse, lodestar, teku, prysm and vero
    # ( The prysm validator only works with a prysm CL client )
    # Defaults to matching the chosen CL client (cl_type)
    vc_type: ""

    # The Docker image that should be used for the separate validator client
    # Defaults by client:
    # - lighthouse: sigp/lighthouse:latest
    # - lodestar: chainsafe/lodestar:latest
    # - nimbus: statusim/nimbus-validator-client:multiarch-latest
    # - prysm: gcr.io/prysmaticlabs/prysm/validator:latest
    # - teku: consensys/teku:latest
    # - vero: ghcr.io/serenita-org/vero:master
    vc_image: ""

    # The log level string that this participant's validator client should log at
    # If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
    # global `logLevel` = `info` then Teku would receive `INFO`, Prysm would receive `info`, etc.)
    # If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
    # over a specific participant's logging
    vc_log_level: ""

    # A list of optional extra env_vars the vc container should spin up with
    vc_extra_env_vars: {}

    # A list of optional extra labels that will be passed to the validator client validator container.
    # Example; vc_extra_labels: {"ethereum-package.partition": "1"}
    vc_extra_labels: {}

    # A list of optional extra params that will be passed to the validator client container for modifying its behaviour
    # If the client combines the Beacon & validator nodes (e.g. Teku, Nimbus), then this list will also be passed to the combined Beacon-validator node
    vc_extra_params: []

    # A list of tolerations that will be passed to the validator container
    # Only works with Kubernetes
    # Example: el_tolerations:
    # - key: "key"
    #   operator: "Equal"
    #   value: "value"
    #   effect: "NoSchedule"
    #   toleration_seconds: 3600
    # Defaults to empty
    vc_tolerations: []

    # Resource management for vc containers
    # CPU is milicores
    # RAM is in MB
    # Defaults to 0, which results in no resource limits
    vc_min_cpu: 0
    vc_max_cpu: 0
    vc_min_mem: 0
    vc_max_mem: 0

    # Count of the number of validators you want to run for a given participant
    # Default to null, which means that the number of validators will be using the
    # network parameter num_validator_keys_per_node
    validator_count: null

    # Whether to use a remote signer instead of the vc directly handling keys
    # Note Lighthouse VC does not support this flag
    # Defaults to false
    use_remote_signer: false

  # Remote signer Specific flags
    # The type of remote signer that should be used
    # Valid values are web3signer
    # Defaults to web3signer
    remote_signer_type: "web3signer"

    # The Docker image that should be used for the remote signer
    # Defaults to "consensys/web3signer:latest"
    remote_signer_image: "consensys/web3signer:latest"

    # A list of optional extra env_vars the remote signer container should spin up with
    remote_signer_extra_env_vars: {}

    # A list of optional extra labels that will be passed to the remote signer container.
    # Example; remote_signer_extra_labels: {"ethereum-package.partition": "1"}
    remote_signer_extra_labels: {}

    # A list of optional extra params that will be passed to the remote signer container for modifying its behaviour
    remote_signer_extra_params: []

    # A list of tolerations that will be passed to the remote signer container
    # Only works with Kubernetes
    # Example: remote_signer_tolerations:
    # - key: "key"
    #   operator: "Equal"
    #   value: "value"
    #   effect: "NoSchedule"
    #   toleration_seconds: 3600
    # Defaults to empty
    remote_signer_tolerations: []

    # Resource management for remote signer containers
    # CPU is milicores
    # RAM is in MB
    # Defaults to 0, which results in no resource limits
    remote_signer_min_cpu: 0
    remote_signer_max_cpu: 0
    remote_signer_min_mem: 0
    remote_signer_max_mem: 0

  # Participant specific flags
    # Node selector
    # Only works with Kubernetes
    # Example: node_selectors: { "disktype": "ssd" }
    # Defaults to empty
    node_selectors: {}

    # A list of tolerations that will be passed to the EL/CL/validator containers
    # This is to be used when you don't want to specify the tolerations for each container separately
    # Only works with Kubernetes
    # Example: tolerations:
    # - key: "key"
    #   operator: "Equal"
    #   value: "value"
    #   effect: "NoSchedule"
    #   toleration_seconds: 3600
    # Defaults to empty
    tolerations: []

    # Count of nodes to spin up for this participant
    # Default to 1
    count: 1

    # Snooper local flag for a participant.
    # Snooper can be enabled with the `snooper_enabled` flag per client or globally
    # Snooper dumps all JSON-RPC requests and responses including BeaconAPI, EngineAPI and ExecutionAPI.
    # Default to null
    snooper_enabled: null

    # Enables Ethereum Metrics Exporter for this participant. Can be set globally.
    # Defaults null and then set to global ethereum_metrics_exporter_enabled (false)
    ethereum_metrics_exporter_enabled: null

    # Enables Xatu Sentry for this participant. Can be set globally.
    # Defaults null and then set to global xatu_sentry_enabled (false)
    xatu_sentry_enabled: null

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

    # A set of parameters the node needs to reach an external block building network
    # If `null` then the builder infrastructure will not be instantiated
    # Example:
    #
    # "relay_endpoints": [
    #  "https://0xdeadbeefcafa@relay.example.com",
    #  "https://0xdeadbeefcafb@relay.example.com",
    #  "https://0xdeadbeefcafc@relay.example.com",
    #  "https://0xdeadbeefcafd@relay.example.com"
    # ]
    builder_network_params: null

    # Participant flag for keymanager api
    # This will open up http ports to your validator services!
    # Defaults null and then set to default global keymanager_enabled (false)
    keymanager_enabled: null

# Participants matrix creates a participant for each combination of EL, CL and VC clients
# Each EL/CL/VC item can provide the same parameters as a standard participant
participants_matrix: {}
  # el:
  #   - el_type: geth
  #   - el_type: besu
  # cl:
  #   - cl_type: prysm
  #   - cl_type: lighthouse
  # vc:
  #   - vc_type: prysm
  #   - vc_type: lighthouse


# Default configuration parameters for the network
network_params:
  # Network name, used to enable syncing of alternative networks
  # Defaults to "kurtosis"
  # You can sync any public network by setting this to the network name (e.g. "mainnet", "sepolia", "holesky", "hoodi")
  # You can sync any devnet by setting this to the network name (e.g. "dencun-devnet-12", "verkle-gen-devnet-2")
  network: "kurtosis"

  # The network ID of the network.
  network_id: "3151908"

  # The address of the staking contract address on the Eth1 chain
  deposit_contract_address: "0x00000000219ab540356cBB839Cbe05303d7705Fa"

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

  # The gas limit of the network set at genesis
  # Defaults to 36000000

  genesis_gaslimit: 36000000

  # Max churn rate for the network introduced by
  # EIP-7514 https://eips.ethereum.org/EIPS/eip-7514
  # Defaults to 8
  max_per_epoch_activation_churn_limit: 8

  # Churn limit quotient for the network
  # Defaults to 65536
  churn_limit_quotient: 65536

  # Ejection balance
  # Defaults to 16ETH
  # 16000000000 gwei
  ejection_balance: 16000000000

  # ETH1 follow distance
  # Defaults to 2048
  eth1_follow_distance: 2048

  # The number of epochs to wait validators to be able to withdraw
  # Defaults to 256 epochs ~27 hours
  min_validator_withdrawability_delay: 256

  # The period of the shard committee
  # Defaults to 256 epoch ~27 hours
  shard_committee_period: 256

  # The epoch at which the deneb/electra/fulu forks are set to occur. Note: PeerDAS and Electra clients are currently
  # working on forks. So set either one of the below forks.
  # Altair fork epoch
  # Defaults to 0
  altair_fork_epoch: 0

  # Bellatrix fork epoch
  # Defaults to 0
  bellatrix_fork_epoch: 0

  # Capella fork epoch
  # Defaults to 0
  capella_fork_epoch: 0

  # Deneb fork epoch
  # Defaults to 0
  deneb_fork_epoch: 0

  # Electra fork epoch
  # Defaults to 0
  electra_fork_epoch: 0

  # Fulu fork epoch
  # Defaults to 18446744073709551615
  fulu_fork_epoch: 18446744073709551615

  # Network sync base url for syncing public networks from a custom snapshot (mostly useful for shadowforks)
  # Defaults to "https://snapshots.ethpandaops.io/"
  # If you have a local snapshot, you can set this to the local url:
  # network_snapshot_url_base = "http://10.10.101.21:10000/snapshots/"
  # The snapshots are taken with https://github.com/ethpandaops/snapshotter
  network_sync_base_url: https://snapshots.ethpandaops.io/

  # Force network sync with a custom snapshot
  # This enables quicker EL sync (use with caution)
  # Defaults to false
  force_snapshot_sync: false

  # The block height of the shadowfork
  # This is used to sync the network from a snapshot at a specific block height
  # Defaults to "latest"
  # Example: shadowfork_block_height: 240000
  shadowfork_block_height: "latest"

  # The number of data column sidecar subnets used in the gossipsub protocol
  data_column_sidecar_subnet_count: 128
  # Number of DataColumn random samples a node queries per slot
  samples_per_slot: 8

  # Minimum number of subnets an honest node custodies and serves samples from
  # Defaults to 4
  custody_requirement: 4

  # Maximum number of blobs per block for Electra fork (default 9)
  max_blobs_per_block_electra: 9
  # Target number of blobs per block for Electra fork (default 6)
  target_blobs_per_block_electra: 6
  # Base fee update fraction for Electra fork (default 5007716)
  base_fee_update_fraction_electra: 5007716

  # EIP-7732 fork epoch
  # Defaults to 18446744073709551615
  eip7732_fork_epoch: 18446744073709551615

  # EIP-7805 fork epoch
  # Defaults to 18446744073709551615
  eip7805_fork_epoch: 18446744073709551615


  # Preset for the network
  # Default: "mainnet"
  # Options: "mainnet", "minimal"
  # "minimal" preset will spin up a network with minimal preset. This is useful for rapid testing and development.
  # 192 seconds to get to finalized epoch vs 1536 seconds with mainnet defaults
  # Please note that minimal preset requires alternative client images.
  # For an example of minimal preset, please refer to [minimal.yaml](.github/tests/minimal.yaml)
  preset: "mainnet"

  # Preloaded contracts for the chain
  additional_preloaded_contracts: {}
  # Example:
  # additional_preloaded_contracts: '{
  #  "0x123463a4B065722E99115D6c222f267d9cABb524":
  #   {
  #     balance: "1ETH",
  #     code: "0x1234",
  #     storage: {},
  #     nonce: 0,
  #     secretKey: "0x",
  #   }
  # }'

  # Repository override for devnet networks
  # Default: ethpandaops
  devnet_repo: ethpandaops

  # A number of prefunded accounts to be created
  # Defaults to no prefunded accounts
  # Example:
  # prefunded_accounts: '{"0x25941dC771bB64514Fc8abBce970307Fb9d477e9": {"balance": "10ETH"}}'
  # 10ETH to the account 0x25941dC771bB64514Fc8abBce970307Fb9d477e9
  # To prefund multiple accounts, separate them with a comma
  #
  # prefunded_accounts: '{"0x25941dC771bB64514Fc8abBce970307Fb9d477e9": {"balance": "10ETH"}, "0x4107be99052d895e3ee461C685b042Aa975ab5c0": {"balance": "1ETH"}}'
  prefunded_accounts: {}

  # Maximum size of gossip messages in bytes
  # 10 * 2**20 (= 10485760, 10 MiB)
  # Defaults to 10485760 (10MB)
  max_payload_size: 10485760

  # Enable Perfect PeerDAS
  # This flag is meant to be used with 16 nodes where each node gets 8 unique columns
  # Ensure that you set the number of validator keys per node to less than or equal to 8 so that validator custody is not affected
  # Defaults to false
  perfect_peerdas_enabled: false

  # Gas limit for the network
  # Default to 0
  # If set to 0, the gas limit will be set to the default gas limit for the clients
  # Set this value to gas limit in millionths of a gwei
  # Example: gas_limit: 36000000
  # This will override the gas limit for each EL client
  # Do not confuse with genesis_gaslimit which sets the gas limit at the genesis file level
  gas_limit: 0

  # BPO
  # BPO1 epoch (default 18446744073709551615)
  bpo_1_epoch: 18446744073709551615
  # Maximum number of blobs per block for BPO1 (default 12)
  bpo_1_max_blobs: 12
  # Target number of blobs per block for BPO1 (default 9)
  bpo_1_target_blobs: 9
  # Base fee update fraction for BPO1 (default 5007716)
  bpo_1_base_fee_update_fraction: 5007716

  # BPO2 epoch (default 18446744073709551615)
  bpo_2_epoch: 18446744073709551615
  # Maximum number of blobs per block for BPO2 (default 12)
  bpo_2_max_blobs: 12
  # Target number of blobs per block for BPO2 (default 9)
  bpo_2_target_blobs: 9
  # Base fee update fraction for BPO2 (default 5007716)
  bpo_2_base_fee_update_fraction: 5007716

  # BPO3 epoch (default 18446744073709551615)
  bpo_3_epoch: 18446744073709551615
  # Maximum number of blobs per block for BPO3 (default 12)
  bpo_3_max_blobs: 12
  # Target number of blobs per block for BPO3 (default 9)
  bpo_3_target_blobs: 9
  # Base fee update fraction for BPO3 (default 5007716)
  bpo_3_base_fee_update_fraction: 5007716

  # BPO4 epoch (default 18446744073709551615)
  bpo_4_epoch: 18446744073709551615
  # Maximum number of blobs per block for BPO4 (default 12)
  bpo_4_max_blobs: 12
  # Target number of blobs per block for BPO4 (default 9)
  bpo_4_target_blobs: 9
  # Base fee update fraction for BPO4 (default 5007716)
  bpo_4_base_fee_update_fraction: 5007716

  # BPO5 epoch (default 18446744073709551615)
  bpo_5_epoch: 18446744073709551615
  # Maximum number of blobs per block for BPO5 (default 12)
  bpo_5_max_blobs: 12
  # Target number of blobs per block for BPO5 (default 9)
  bpo_5_target_blobs: 9
  # Base fee update fraction for BPO5 (default 5007716)
  bpo_5_base_fee_update_fraction: 5007716


# Global parameters for the network

# By default includes
# - A transaction spammer & blob spammer is launched to fake transactions sent to the network
# - Forkmon for EL will be launched
# - A prometheus will be started, coupled with grafana
# - A beacon metrics gazer will be launched
# - A light beacon chain explorer will be launched
# - Default: []
additional_services:
  - assertoor
  - broadcaster
  - tx_fuzz
  - custom_flood
  - spamoor
  - forkmon
  - blockscout
  - dora
  - full_beaconchain_explorer
  - prometheus_grafana
  - blobscan
  - dugtrio
  - blutgang
  - forky
  - apache
  - tracoor

# Configuration place for blockscout explorer - https://github.com/blockscout/blockscout
blockscout_params:
  # blockscout docker image to use
  # Defaults to blockscout/blockscout:latest
  image: "blockscout/blockscout:latest"
  # blockscout smart contract verifier image to use
  # Defaults to ghcr.io/blockscout/smart-contract-verifier:latest
  verif_image: "ghcr.io/blockscout/smart-contract-verifier:latest"
  # Frontend image
  # Defaults to ghcr.io/blockscout/frontend:latest
  frontend_image: "ghcr.io/blockscout/frontend:latest"

# Configuration place for dora the explorer - https://github.com/ethpandaops/dora
dora_params:
  # Dora docker image to use
  # Defaults to the latest image
  image: "ethpandaops/dora:latest"
  # A list of optional extra env_vars the dora container should spin up with
  env: {}

# Configuration place for transaction spammer - https://github.com/MariusVanDerWijden/tx-fuzz
tx_fuzz_params:
  # TX Spammer docker image to use
  # Defaults to the latest master image
  image: "ethpandaops/tx-fuzz:master"
  # A list of optional extra params that will be passed to the TX Spammer container for modifying its behaviour
  tx_fuzz_extra_args: []

# Configuration place for prometheus
prometheus_params:
  storage_tsdb_retention_time: "1d"
  storage_tsdb_retention_size: "512MB"
  # Resource management for prometheus container
  # CPU is milicores
  # RAM is in MB
  min_cpu: 10
  max_cpu: 1000
  min_mem: 128
  max_mem: 2048
  # Prometheus docker image to use
  # Defaults to the latest image
  image: "prom/prometheus:latest"

# Configuration place for grafana
grafana_params:
  # A list of locators for grafana dashboards to be loaded be the grafana service
  additional_dashboards: []
  # Resource management for grafana container
  # CPU is milicores
  # RAM is in MB
  min_cpu: 10
  max_cpu: 1000
  min_mem: 128
  max_mem: 2048
  # Grafana docker image to use
  # Defaults to the latest image
  image: "grafana/grafana:latest"

# Configuration place for the assertoor testing tool - https://github.com/ethpandaops/assertoor
assertoor_params:
  # Assertoor docker image to use
  # Defaults to the latest image
  image: "ethpandaops/assertoor:latest"

  # Check chain stability
  # This check monitors the chain and succeeds if:
  # - all clients are synced
  # - chain is finalizing for min. 2 epochs
  # - >= 98% correct target votes
  # - >= 80% correct head votes
  # - no reorgs with distance > 2 blocks
  # - no more than 2 reorgs per epoch
  run_stability_check: false

  # Check block propöosals
  # This check monitors the chain and succeeds if:
  # - all client pairs have proposed a block
  run_block_proposal_check: false

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
  # Entries may be simple strings (link to the test file) or dictionaries with more flexibility
  # eg:
  #   - https://raw.githubusercontent.com/ethpandaops/assertoor/master/example/tests/block-proposal-check.yaml
  #   - file: "https://raw.githubusercontent.com/ethpandaops/assertoor/master/example/tests/block-proposal-check.yaml"
  #     config:
  #       someCustomTestConfig: "some value"
  tests: []


# If set, the package will block until a finalized epoch has occurred.
wait_for_finalization: false

# The global log level that all clients should log at
# Valid values are "error", "warn", "info", "debug", and "trace"
# This value will be overridden by participant-specific values
global_log_level: "info"

# Snooper global flag for all participants
# Snooper can be enabled with the `snooper_enabled` flag per client or globally
# Snooper dumps all JSON-RPC requests and responses including BeaconAPI, EngineAPI and ExecutionAPI.
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

# Whether the environment should be persistent; this is WIP and is slowly being rolled out across services
# Note this requires Kurtosis greater than 0.85.49 to work
# Note Erigon, Besu, Teku persistence is not currently supported with docker.
# Defaults to false
persistent: false

# Docker cache url enables all docker images to be pulled through a custom docker registry
# Disabled by default
# Defaults to empty cache url
# Images pulled from dockerhub will be prefixed with "/dh/" by default (docker.io)
# Images pulled from github registry will be prefixed with "/gh/" by default (ghcr.io)
# Images pulled from google registry will be prefixed with "/gcr/" by default (gcr.io)
# If you want to use a local image in combination with the cache, do not put "/" in your local image name
docker_cache_params:
  enabled: false
  url: ""
  dockerhub_prefix: "/dh/"
  github_prefix: "/gh/"
  google_prefix: "/gcr/"

# Supports three valeus
# Default: "null" - no mev boost, mev builder, mev flood or relays are spun up
# "mock" - mock-builder & mev-boost are spun up
# "flashbots" - mev-boost, relays, flooder and builder are all spun up, powered by [flashbots](https://github.com/flashbots)
# "mev-rs" - mev-boost, relays and builder are all spun up, powered by [mev-rs](https://github.com/ralexstokes/mev-rs/)
# "commit-boost" - mev-boost, relays and builder are all spun up, powered by [commit-boost](https://github.com/Commit-Boost/commit-boost-client)
# We have seen instances of multibuilder instances failing to start mev-relay-api with non zero epochs
mev_type: null

# Parameters if MEV is used
mev_params:
  # The image to use for MEV boost relay
  mev_relay_image: ethpandaops/mev-boost-relay:main
  # The image to use for the builder
  mev_builder_image: ethpandaops/reth-rbuilder:develop
  # The image to use for the CL builder
  mev_builder_cl_image: sigp/lighthouse:latest
  # The subsidy to use for the builder (in ETH)
  mev_builder_subsidy: 0
  # The image to use for mev-boost
  mev_boost_image: ethpandaops/mev-boost:develop
  # Parameters for MEV Boost. This overrides all arguments of the mev-boost container
  mev_boost_args: []
  # Extra parameters to send to the API
  mev_relay_api_extra_args: []
  # Extra environment variables to send to the API
  mev_relay_api_extra_env_vars: {}
  # Extra parameters to send to the housekeeper
  mev_relay_housekeeper_extra_args: []
  # Extra environment variables to send to the housekeeper
  mev_relay_housekeeper_extra_env_vars: {}
  # Extra parameters to send to the website
  mev_relay_website_extra_args: []
  # Extra environment variables to send to the website
  mev_relay_website_extra_env_vars: {}
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

  # Image to use for mock mev
  mock_mev_image: ethpandaops/rustic-builder:main

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

# Apache params
# Apache public port to port forward to local machine
# Default to port None, only set if apache additional service is activated
apache_port: null

# Global tolerations that will be passed to all containers (unless overridden by a more specific toleration)
# Only works with Kubernetes
# Example: tolerations:
# - key: "key"
#   operator: "Equal"
#   value: "value"
#   effect: "NoSchedule"
#   toleration_seconds: 3600
# Defaults to empty
global_tolerations: []

# Global node selector that will be passed to all containers (unless overridden by a more specific node selector)
# Only works with Kubernetes
# Example: global_node_selectors: { "disktype": "ssd" }
# Defaults to empty
global_node_selectors: {}

# Global parameters for keymanager api
# This will open up http ports to your validator services!
# Defaults to false
keymanager_enabled: false

# Global flag to enable checkpoint sync across the network
checkpoint_sync_enabled: false

# Global flag to set checkpoint sync url
checkpoint_sync_url: ""

# Configuration place for spamoor as transaction spammer
spamoor_params:
  # The image to use for spamoor
  image: ethpandaops/spamoor:latest
  # Resource management for spamoor
  # CPU is milicores
  # RAM is in MB
  min_cpu: 10
  max_cpu: 1000
  min_mem: 20
  max_mem: 300
  # A list of spammers to launch on startup
  # example:
  # - scenario: eoatx  # The spamoor scenario to use (see https://github.com/ethpandaops/spamoor)
  #   name: "Optional name for this example spammer"
  #   config:
  #     throughput: 10  # 10 tx per block
  # - scenario: erctx
  #   config:
  #     throughput: 10  # 10 tx per block
  spammers: []
  # A list of optional params that will be passed to the spamoor command for modifying its behaviour
  extra_args: []

# Ethereum genesis generator params
ethereum_genesis_generator_params:
  # The image to use for ethereum genesis generator
  image: ethpandaops/ethereum-genesis-generator:4.1.4

# Global parameter to set the exit ip address of services and public ports
port_publisher:
  # if you have a service that you want to expose on a specific interface; set that IP here
  # if you set it to auto it gets the public ip from ident.me and sets it
  # Defaults to constants.PRIVATE_IP_ADDRESS_PLACEHOLDER
  # The default value just means its the IP address of the container in which the service is running
  nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER
  # Execution Layer public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 32000
  # You can't run multiple enclaves on the same port settings
  el:
    enabled: false
    public_port_start: 32000
  # Consensus Layer public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 33000
  # You can't run multiple enclaves on the same port settings
  cl:
    enabled: false
    public_port_start: 33000
  # Validator client public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 34000
  # You can't run multiple enclaves on the same port settings
  vc:
    enabled: false
    public_port_start: 34000
  # remote signer public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 35000
  # You can't run multiple enclaves on the same port settings
  remote_signer:
    enabled: false
    public_port_start: 35000
  # Additional services public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 36000
  # You can't run multiple enclaves on the same port settings
  additional_services:
    enabled: false
    public_port_start: 36000

  # MEV public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 37000
  # You can't run multiple enclaves on the same port settings
  mev:
    enabled: false
    public_port_start: 37000

  # Other public port exposed to your local machine (like ethereum metrics exporter, snooper)
  # Disabled by default
  # Public port start defaults to 38000
  # You can't run multiple enclaves on the same port settings
  other:
    enabled: false
    public_port_start: 38000
```

#### Example configurations

<details>
    <summary>Verkle configuration example</summary>

```yaml
participants:
  - el_type: geth
    el_image: ethpandaops/geth:<VERKLE_IMAGE>
    elExtraParams:
    - "--override.verkle=<UNIXTIMESTAMP>"
    cl_type: lighthouse
    cl_image: sigp/lighthouse:latest
  - el_type: geth
    el_image: ethpandaops/geth:<VERKLE_IMAGE>
    elExtraParams:
    - "--override.verkle=<UNIXTIMESTAMP>"
    cl_type: lighthouse
    cl_image: sigp/lighthouse:latest
  - el_type: geth
    el_image: ethpandaops/geth:<VERKLE_IMAGE>
    elExtraParams:
    - "--override.verkle=<UNIXTIMESTAMP>"
    cl_type: lighthouse
    cl_image: sigp/lighthouse:latest
network_params:
  deneb_fork_epoch: 0
wait_for_finalization: false
wait_for_verifications: false
global_log_level: info

```

</details>

<details>
    <summary>A 3-node Ethereum network with "mock" MEV mode.</summary>
    Useful for testing mev-boost and the client implementations without adding the complexity of the relay. This can be enabled by a single config command and would deploy the [mock-builder](https://github.com/marioevz/mock-builder), instead of the relay infrastructure.

```yaml
participants:
  - el_type: geth
    el_image: ''
    cl_type: lighthouse
    cl_image: ''
    count: 2
  - el_type: nethermind
    el_image: ''
    cl_type: teku
    cl_image: ''
    count: 1
  - el_type: besu
    el_image: ''
    cl_type: prysm
    cl_image: ''
    count: 2
mev_type: mock
```

</details>

<details>
    <summary>A 5-node Ethereum network with three different CL and EL client combinations and mev-boost infrastructure in "full" mode.</summary>

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
    count: 2
  - el_type: nethermind
    cl_type: teku
  - el_type: besu
    cl_type: prysm
    count: 2
mev_type: flashbots
network_params:
  deneb_fork_epoch: 1
```

</details>

<details>
    <summary>A 2-node geth/lighthouse network with optional services (Grafana, Prometheus, tx_fuzz, EngineAPI snooper, and a testnet verifier)</summary>

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
    count: 2
snooper_enabled: true
additional_services:
  - prometheus_grafana
ethereum_metrics_exporter_enabled: true
```

</details>

## Beacon Node <> Validator Client compatibility

|               | Lighthouse VC | Prysm VC | Teku VC | Lodestar VC | Nimbus VC
|---------------|---------------|----------|---------|-------------|-----------|
| Lighthouse BN | ✅            | ❌       | ✅      | ✅          | ✅
| Prysm BN      | ✅            | ✅       | ✅      | ✅          | ✅
| Teku BN       | ✅            | ✅       | ✅      | ✅          | ✅
| Lodestar BN   | ✅            | ✅       | ✅      | ✅          | ✅
| Nimbus BN     | ✅            | ✅       | ✅      | ✅          | ✅
| Grandine BN   | ✅            | ✅       | ✅      | ✅          | ✅

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
kurtosis run github.com/ethpandaops/ethereum-package '{"mev_type": "full"}'
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

</details>

This package also supports a `"mev_type": "mock"` mode that will only bring up:

1. `mock-builder` - a server that listens for builder API directives and responds with payloads built using an execution client
1. `mev-boost` - for every EL/CL pair launched

For more details, including a guide and architecture of the `mev-boost` infrastructure, go [here](https://docs.kurtosis.com/how-to-full-mev-with-ethereum-package/).

## Pre-funded accounts at Genesis

This package comes with [21 prefunded keys for testing](https://github.com/ethpandaops/ethereum-package/blob/main/src/prelaunch_data_generator/genesis_constants/genesis_constants.star).

Here's a table of where the keys are used

| Account Index | Component Used In   | Private Key Used | Public Key Used | Comment                     |
|---------------|---------------------|------------------|-----------------|-----------------------------|
| 0             | Builder             | ✅                |                 | As coinbase                |
| 0             | mev_custom_flood    |                   | ✅              | As the receiver of balance |
| 3             | transaction_spammer | ✅                |                 | To spam transactions with  |
| 6             | mev_flood           | ✅                |                 | As the contract owner      |
| 7             | mev_flood           | ✅                |                 | As the user_key            |
| 8             | assertoor           | ✅                | ✅              | As the funding for tests   |
| 11            | mev_custom_flood    | ✅                |                 | As the sender of balance   |
| 12            | l2_contracts        | ✅                |                 | Contract deployer address  |
| 13            | spamoor             | ✅                |                 | Spams transactions         |

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

## PeerDAS

We can use a set of pre-generated node keys to achieve a perfect column distribution on a 128-column network with an 8-column custody requirement.
For this to work, we need a network of 16 nodes running, so each node would custody 8 unique columns.

Here's a table of the private keys that can be used to create the nodes:
| nodeId | sep256k1 privKey | columns |
|--------|-------------|---------|
| 0x9908...4159 | 0x86e8...4c8d | 17, 51, 52, 76, 103, 113, 117, 118 |
| 0xacd4...84e1 | 0xe156...c0da | 24, 35, 78, 80, 101, 107, 114, 122 |
| 0x3916...b3d | 0x932b...9dd5 | 16, 25, 57, 66, 69, 70, 77, 115 |
| 0x95a8...373b | 0x6eca...ae2c | 9, 30, 82, 99, 105, 116, 123, 125 |
| 0x4a53...c82 | 0x2e2e...df9b | 10, 14, 61, 85, 86, 90, 111, 126 |
| 0x4722...8ff9 | 0x2ea0...32e9 | 2, 5, 18, 32, 33, 49, 83, 94 |
| 0x912d...add3 | 0xc070...da04 | 3, 13, 48, 50, 74, 97, 119, 121 |
| 0x93cd...3477 | 0xd915...e831 | 40, 42, 53, 58, 62, 87, 89, 120 |
| 0x1e19...dd2a | 0x077c...89be | 41, 43, 47, 54, 56, 63, 92, 98 |
| 0x8165...f316 | 0x5a3e...a8a6 | 8, 22, 38, 60, 79, 91, 93, 112 |
| 0xe705...fe55 | 0xa10f...c636 | 6, 29, 44, 68, 75, 81, 109, 110 |
| 0x1835...f044 | 0xbeb4...f299 | 0, 11, 26, 27, 34, 36, 39, 95 |
| 0x4fb2...e3ce | 0x735e...4947 | 4, 15, 28, 55, 72, 73, 88, 108 |
| 0xd1f9...50c9 | 0x75ba...167a | 7, 12, 31, 37, 45, 65, 71, 84 |
| 0x024a...8dc5 | 0xd93a...e1a7 | 1, 19, 20, 21, 46, 64, 67, 124 |
| 0x3f2b...0db3 | 0xbcde...0608 | 23, 59, 96, 100, 102, 104, 106, 127 |

Private keys can be found in the `static_files/peerdas-node-keys` directory.

<!------------------------ Only links below here -------------------------------->

[docker-installation]: https://docs.docker.com/get-docker/
[kurtosis-cli-installation]: https://docs.kurtosis.com/install
[kurtosis-repo]: https://github.com/kurtosis-tech/kurtosis
[enclave]: https://docs.kurtosis.com/advanced-concepts/enclaves/
[package-reference]: https://docs.kurtosis.com/advanced-concepts/packages
