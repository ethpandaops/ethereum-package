# Ethereum Package

This is a [Kurtosis Package][starlark-docs] that will spin up a private Ethereum testnet over Docker or Kubernetes with multi-client support, Flashbot's `mev-boost` infrastructure for PBS-related testing/validation, and other useful network tools (transaction spammer, monitoring tools, etc). Kurtosis packages are entirely reproducible and composable, so this will work the same way over Docker or Kubernetes, in the cloud or locally on your machine.

Specifically, this package will:
1. Generate Execution Layer (EL) & Consensus Layer (CL) genesis information using [the Ethereum genesis generator](https://github.com/ethpandaops/ethereum-genesis-generator).
2. Configure & bootstrap a network of Ethereum nodes of *n* size using the genesis data generated above
3. Spin up a [transaction spammer](https://github.com/MariusVanDerWijden/tx-fuzz) to send fake transactions to the network
4. Spin up and connect a [testnet verifier](https://github.com/ethereum/merge-testnet-verifier)
5. Spin up a Grafana and Prometheus instance to observe the network

Optional features (enabled via flags or parameter files at runtime):
* Block until the Beacon nodes finalize an epoch (i.e. finalized_epoch > 0)
* Spin up & configure parameters for the infrastructure behind Flashbot's implementation of PBS using `mev-boost`, in either `full` or `mock` mode. More details [here](./README.md#proposer-builder-separation-pbs-implementation-via-flashbots-mev-boost-protocol).
* Spin up & connect the network to a [beacon metrics gazer service](https://github.com/dapplion/beacon-metrics-gazer) to collect network-wide participation metrics.
* Spin up and connect a [JSON RPC Snooper](https://github.com/ethDreamer/json_rpc_snoop) to the network log responses & requests between the EL engine API and the CL client. 
* Specify extra parameters to be passed in for any of the: CL client Beacon, and CL client validator, and/or EL client containers
* Specify the required parameters for the nodes to reach an external block building network
* Generate keystores for each node in parallel

## Quickstart
1. [Install Docker & start the Docker Daemon if you haven't done so already][docker-installation]
2. [Install the Kurtosis CLI, or upgrade it to the latest version if it's already installed][kurtosis-cli-installation]
3. Run the package with default configurations from the command line:
   ```bash
   kurtosis run --enclave my-testnet github.com/kurtosis-tech/eth2-package
   ```

#### Run with your own configuration
Kurtosis packages are parameterizable, meaning you can customize your network and its behavior to suit your needs by storing parameters in a file that you can pass in at runtime like so:
```bash
kurtosis run --enclave my-testnet github.com/kurtosis-tech/eth2-package "$(cat ~/network_params.json)"
```

Where `network_params.json` contains the parameters for your network in your home directory.

#### Run on Kubernetes
Kurtosis packages work the same way over Docker or on Kubernetes. Please visit our [Kubernetes docs](https://docs.kurtosis.com/k8s) to learn how to spin up a private testnet on a Kubernetes cluster. 

#### Tear down
The testnet will reside in an [enclave](https://docs.kurtosis.com/concepts-reference/enclaves/) - an isolated, ephemeral environment. The enclave and its contents (e.g. running containers, files artifacts, etc) will persist until torn down. You can remove an enclave and its contents with:
```
kurtosis enclave rm -f my-testnet
```

## Management
The [Kurtosis CLI](https://docs.kurtosis.com/cli) can be used to inspect and interact with the network. 

For example, if you need shell access, simply run:
```
kurtosis service shell my-testnet $SERVICE_NAME
```

And if you need the logs for a service, simply run:
```
kurtosis service logs my-testnet $SERVICE_NAME
```

Check out the full list of CLI commands [here](https://docs.kurtosis.com/cli)

## Debugging
To grab the genesis files for the network, simply run:
```
kurtosis files download my-testnet $FILE_NAME $OUTPUT_DIRECTORY
```
For example, to retrieve the Execution Layer (EL) genesis data, run:
```
kurtosis files download my-testnet el-genesis-data ~/Downloads
```

## Configuration
To configure the package behaviour, you can modify your `network_params.json` file. The full JSON schema that can be passed in is as follows with the defaults provided:

<details>
    <summary>Click to show all configuration options</summary>

<!-- Yes, it's weird that none of this is indented but it's intentional - indenting anything inside this "details" expandable will cause it to render weird" -->

```json
{
    //  Specification of the participants in the network
    "participants": [
        {
            //  The type of EL client that should be started
            //  Valid values are "geth", "nethermind", "erigon", "besu" and "reth"
            "el_client_type": "geth",

            //  The Docker image that should be used for the EL client; leave blank to use the default for the client type
            //  Defaults by client:
            //  - geth: ethereum/client-go:latest
            //  - erigon: thorax/erigon:devel
            //  - nethermind: nethermind/nethermind:latest
            //  - besu: hyperledger/besu:develop
            //  - reth: ghcr.io/paradigmxyz/reth
            "el_client_image": "",

            //  The log level string that this participant's EL client should log at
            //  If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
            //   global `logLevel` = `info` then Geth would receive `3`, Besu would receive `INFO`, etc.)
            //  If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
            //   over a specific participant's logging
            "el_client_log_level": "",

            //  A list of optional extra params that will be passed to the EL client container for modifying its behaviour
            "el_extra_params": [],

            //  The type of CL client that should be started
            //  Valid values are "nimbus", "lighthouse", "lodestar", "teku", and "prysm"
            "cl_client_type": "lighthouse",

            //  The Docker image that should be used for the EL client; leave blank to use the default for the client type
            //  Defaults by client (note that Prysm is different in that it requires two images - a Beacon and a validator - separated by a comma):
            //  - lighthouse: sigp/lighthouse:latest
            //  - teku: consensys/teku:latest
            //  - nimbus: statusim/nimbus-eth2:multiarch-latest
            //  - prysm: gcr.io/prysmaticlabs/prysm/beacon-chain:latest,gcr.io/prysmaticlabs/prysm/validator:latest
            //  - lodestar: chainsafe/lodestar:next
            "cl_client_image": "",

            //  The log level string that this participant's EL client should log at
            //  If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
            //   global `logLevel` = `info` then Teku would receive `INFO`, Prysm would receive `info`, etc.)
            //  If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
            //   over a specific participant's logging
            "cl_client_log_level": "",

            //  A list of optional extra params that will be passed to the CL client Beacon container for modifying its behaviour
            //  If the client combines the Beacon & validator nodes (e.g. Teku, Nimbus), then this list will be passed to the combined Beacon-validator node
            "beacon_extra_params": [],

            //  A list of optional extra params that will be passed to the CL client validator container for modifying its behaviour
            //  If the client combines the Beacon & validator nodes (e.g. Teku, Nimbus), then this list will also be passed to the combined Beacon-validator node
            "validator_extra_params": [],

            // A set of parameters the node needs to reach an external block building network
            // If `null` then the builder infrastructure will not be instantiated
            // Example:
            //
            // "relay_endpoints": [
            //   "https://0xdeadbeefcafa@relay.example.com",
            //   "https://0xdeadbeefcafb@relay.example.com",
            //   "https://0xdeadbeefcafc@relay.example.com",
            //   "https://0xdeadbeefcafd@relay.example.com"
            //  ]
            "builder_network_params": null
        }
    ],

    //  Default configuration parameters for the Eth network
    "network_params": {
        //  The network ID of the network.
        "network_id": "3151908",

        //  The address of the staking contract address on the Eth1 chain
        "deposit_contract_address": "0x4242424242424242424242424242424242424242",

        //  Number of seconds per slot on the Beacon chain
        "seconds_per_slot": 12,

        //  Number of slots in an epoch on the Beacon chain
        "slots_per_epoch": 32,

        //  The number of validator keys that each CL validator node should get
        "num_validator_keys_per_node": 64,

        //  This mnemonic will a) be used to create keystores for all the types of validators that we have and b) be used to generate a CL genesis.ssz that has the children
        //   validator keys already preregistered as validators
        "preregistered_validator_keys_mnemonic": "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete",

        // The epoch at which the capella and deneb forks are set to occur.
        "capella_fork_epoch": 2,
        "deneb_fork_epoch": 4
    },

    // True by defaults such that in addition to the Ethereum network:
    //  - A transaction spammer is launched to fake transactions sent to the network
    //  - Forkmon will be launched after CL genesis has happened
    //  - A prometheus will be started, coupled with grafana
    // If set to false:
    //  - only Ethereum network (EL and CL nodes) will be launched. Nothing else (no transaction spammer)
    //  - params for the CL nodes will be ignored (e.g. CL node image, CL node extra params)
    "launch_additional_services": true,

    //  If set, the package will block until a finalized epoch has occurred.
    //  If `waitForVerifications` is set to true, this extra wait will be skipped.
    "wait_for_finalization": false,

    //  If set to true, the package will block until all verifications have passed
    "wait_for_verifications": false,

    //  If set, after the merge, this will be the maximum number of epochs wait for the verifications to succeed.
    "verifications_epoch_limit": 5,

    //  The global log level that all clients should log at
    //  Valid values are "error", "warn", "info", "debug", and "trace"
    //  This value will be overridden by participant-specific values
    "global_client_log_level": "info",

    // EngineAPI Snooper
    "snooper_enabled": false,

    // Parallelizes keystore generation so that each node has keystores being generated in their own container
    // This will result in a large number of containers being spun up than normal. We advise users to only enable this on a sufficiently large machine or in the cloud as it can be resource consuming on a single machine.
    "parallel_keystore_generation": false,


    // Supports three valeus
    // Default: "None" - no mev boost, mev builder, mev flood or relays are spun up
    // "mock" - mock-builder & mev-boost are spun up
    // "full" - mev-boost, relays, flooder and builder are all spun up
    "mev_type": "None",

    // Parameters if MEV is used
    "mev_params": {
      // The image to use for MEV boot relay
      // This uses the h4ck3rk3y image instead of the flashbots image as that isn't published yet
		"mev_relay_image": "flashbots/mev-boost-relay",
      // Extra parameters to send to the API
		"mev_relay_api_extra_args": [],
      // Extra parameters to send to the housekeeper
		"mev_relay_housekeeper_extra_args": [],
      // Extra parameters to send to the website
		"mev_relay_website_extra_args": [],
      // Extra parameters to send to the builder
		"mev_builder_extra_args": [],
      // Image to use for mev-flood
		"mev_flood_image": "flashbots/mev-flood",
      // Extra parameters to send to mev-flood
		"mev_flood_extra_args": []
    }
}
```
</details>

#### Example configurations

<details>
    <summary>Verkle configuration example</summary>

```json
{
  "participants": [
    {
      "el_client_type": "geth",
      "el_client_image": "ethpandaops/geth:<VERKLE_IMAGE>",
      "elExtraParams": ["--override.verkle=<UNIXTIMESTAMP>"],
      "cl_client_type": "lighthouse",
      "cl_client_image": "sigp/lighthouse:latest"
    },
    {
      "el_client_type": "geth",
      "el_client_image": "ethpandaops/geth:<VERKLE_IMAGE>",
      "elExtraParams": ["--override.verkle=<UNIXTIMESTAMP>"],
      "cl_client_type": "lighthouse",
      "cl_client_image": "sigp/lighthouse:latest"
    },
    {
      "el_client_type": "geth",
      "el_client_image": "ethpandaops/geth:<VERKLE_IMAGE>",
      "elExtraParams": ["--override.verkle=<UNIXTIMESTAMP>"],
      "cl_client_type": "lighthouse",
      "cl_client_image": "sigp/lighthouse:latest"
    }
  ],
  "network_params": {
    "capella_fork_epoch": 2,
    "deneb_fork_epoch": 5
  },
  "launch_additional_services": false,
  "wait_for_finalization": false,
  "wait_for_verifications": false,
  "global_client_log_level": "info"
}
```
</details>

<details>
    <summary>A 3-node Ethereum network with "mock" MEV mode.</summary>
    Useful for testing mev-boost and the client implimentations without adding the complexity of the relay. This can be enabled by a single config command and would deploy the [mock-builder](https://github.com/marioevz/mock-builder), instead of the relay infrastructure.

```json
{
  "participants": [
    {
      "el_client_type": "geth",
      "el_client_image": "",
      "cl_client_type": "lighthouse",
      "cl_client_image": "",
      "count": 2
    },
    {
      "el_client_type": "nethermind",
      "el_client_image": "",
      "cl_client_type": "teku",
      "cl_client_image": "",
      "count": 1
    },
    {
      "el_client_type": "besu",
      "el_client_image": "",
      "cl_client_type": "prysm",
      "cl_client_image": "",
      "count": 2
    },
  ],
  "mev_type": "mock",
  "launch_additional_services": false
}
```
</details>

<details>
    <summary>A 5-node Ethereum network with three different CL and EL client combinations and mev-boost infrastructure in "full" mode.</summary>

```json
{
  "participants": [
    {
      "el_client_type": "geth",
      "el_client_image": "",
      "cl_client_type": "lighthouse",
      "cl_client_image": "",
      "count": 2
    },
    {
      "el_client_type": "nethermind",
      "el_client_image": "",
      "cl_client_type": "teku",
      "cl_client_image": "",
      "count": 1
    },
    {
      "el_client_type": "besu",
      "el_client_image": "",
      "cl_client_type": "prysm",
      "cl_client_image": "",
      "count": 2
    },
  ],
  "mev_type": "full",
  "launch_additional_services": false
}
```
</details>

<details>
    <summary>A 2-node geth/lighthouse network with optional services (Grafana, Prometheus, transaction-spammer, EngineAPI snooper, and a testnet verifier)</summary>

```json
{
  "participants": [
    {
      "el_client_type": "geth",
      "el_client_image": "",
      "cl_client_type": "lighthouse",
      "cl_client_image": "",
      "count": 2
    }
  ],
  "launch_additional_services": true,
  "snooper_enabled": true
}
```
</details>

## Proposer Builder Separation (PBS) emulation
To spin up the network of Ethereum nodes with an external block building network (using Flashbot's `mev-boost` protocol), simply use:
```
kurtosis run github.com/kurtosis-tech/eth2-package '{"mev_type": "full"}'
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

* The mev-boost-relay service requires Capella at an epoch of non-zero. For the eth2-package, the Capella fork is set to happen after the first epoch to be started up and fully connected to the CL client.
* Validators (64 per node by default, so 128 in the example in this guide) will get registered with the relay automatically after the 2nd epoch. This registration process is simply a configuration addition to the mev-boost config - which Kurtosis will automatically take care of as part of the set up. This means that the mev-relay infrastructure only becomes aware of the existence of the validators after the 2nd epoch.
* After the 3rd epoch, the mev-relay service will begin to receive execution payloads (eth_sendPayload, which does not contain transaction content) from the mev-builder service (or mock-builder in mock-mev mode).
* Validators will start to receive validated execution payload headers from the mev-relay service (via mev-boost) after the 4th epoch. The validator selects the most valuable header, signs the payload, and returns the signed header to the relay - effectively proposing the payload of transactions to be included in the soon-to-be-proposed block. Once the relay verifies the block proposer's signature, the relay will respond with the full execution payload body (incl. the transaction contents) for the validator to use when proposing a SignedBeaconBlock to the network.
</details>


This package also supports a `"mev_type": "mock"` mode that will only bring up:

1. `mock-builder` - a server that listens for builder API directives and responds with payloads built using an execution client
1. `mev-boost` - for every EL/CL pair launched

For more details, including a guide and architecture of the `mev-boost` infrastructure, go [here](https://docs.kurtosis.com/how-to-full-mev-with-eth2-package). 

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
   * `h4ck3rk3y` (Kurtosis)
   * `mieubrisse` (Kurtosis)
   * `leederek` (Kurtosis)
1. Once everything works, merge!

<!------------------------ Only links below here -------------------------------->

[docker-installation]: https://docs.docker.com/get-docker/
[kurtosis-cli-installation]: https://docs.kurtosis.com/install
[starlark-docs]: https://docs.kurtosis.com/starlark-reference
[using-the-cli]: https://docs.kurtosis.com/cli
[prysm-issue]: https://github.com/prysmaticlabs/prysm/issues/11508
[erigon-issue]: https://github.com/kurtosis-tech/eth2-merge-kurtosis-module/issues/154
