Ethereum Package
=======================

This is a [Kurtosis Starlark Package][starlark-docs] that will:

1. Generate EL & CL genesis information using [this genesis generator](https://github.com/skylenet/ethereum-genesis-generator)
1. Spin up a network of mining Eth1 clients
1. Spin up a network of Eth2 Beacon/validator clients
1. Add [a transaction spammer](https://github.com/kurtosis-tech/tx-fuzz) that will repeatedly send transactions to the network
1. Launch [a consensus monitor](https://github.com/ralexstokes/ethereum_consensus_monitor) instance attached to the network
1. Optionally block until the Beacon nodes finalize an epoch (i.e. finalized_epoch > 0)

For much more detailed information about how the merge works in Ethereum testnets, see [this document](https://notes.ethereum.org/@ExXcnR0-SJGthjz1dwkA1A/H1MSKgm3F).

Quickstart
----------

1. [Install Docker if you haven't done so already][docker-installation]
1. [Install the Kurtosis CLI, or upgrade it to the latest version if it's already installed][kurtosis-cli-installation]
1. Ensure your Docker engine is running:
   ```bash
   docker image ls
   ```
1. Create a file in your home directory `eth2-package-params.json` with the following contents:

   ```yaml
   global_client_log_level: "info"
   ```

1. Run the package, passing in the params from the file:
   ```bash
   kurtosis run --enclave-id eth2 github.com/kurtosis-tech/eth2-package "$(cat ~/eth2-package-params.json)"
   ```

Management
----------

Kurtosis will create a new enclave to house the services of the Ethereum network. [This page][using-the-cli] contains documentation for managing the created enclave & viewing detailed information about it.

Configuration
-------------

To configure the package behaviour, you can modify your `eth2-package-params.yaml` file. The full YAML schema that can be passed in is as follows with the defaults provided:

<details>
    <summary>Click to show all configuration options</summary>

<!-- Yes, it's weird that none of this is indented but it's intentional - indenting anything inside this "details" expandable will cause it to render weird" -->
```json
{
    //  Specification of the participants in the network
    "participants": [
        {
            //  The type of EL client that should be started
            //  Valid values are "geth", "nethermind", "erigon" and "besu"
            "el_client_type": "geth",

            //  The Docker image that should be used for the EL client; leave blank to use the default for the client type
            //  Defaults by client:
            //  - geth: ethereum/client-go:latest
            //  - erigon: thorax/erigon:devel
            //  - nethermind: nethermind/nethermind:latest
            //  - besu: hyperledger/besu:develop            
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

    //  Configuration parameters for the Eth network
    "network_params": {
        //  The network ID of the Eth1 network
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
        "preregistered_validator_keys_mnemonic": "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete"

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
    "global_client_log_level": "info"
}
```
</details>

Note: Following an update starting the network post-merge, `erigon`, and `prysm` clients don't work anymore. Fixes are tracked in the following Github issues:
- Prysm: [#11508][prysm-issue]
- Erigon: [#154][erigon-issue]

You can find the latest Kiln compatible docker images here: https://notes.ethereum.org/@launchpad/kiln

Developing On This Package
-------------------------
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
- Add an entry to `docs/changelog.md` under the `# TBD` header describing your changes (this is required for CI checks to pass!)
- Create a PR
- Add one of the maintainers of the repo as a "Review Request":
    - `parithosh` (Ethereum)
    - `gbouv` (Kurtosis)
    - `h4ck3rk3y` (Kurtosis)
    - `mieubrisse` (Kurtosis)
- Once everything works, merge! 

## Known Bugs

`wait_for_epoch_finalization` - doesn't work as expected, as Starlark doesn't have ways to do assertions on facts just yet. The [issue](https://github.com/kurtosis-tech/eth2-package/issues/15) tracks this.

<!------------------------ Only links below here -------------------------------->
[docker-installation]: https://docs.docker.com/get-docker/
[kurtosis-cli-installation]: https://docs.kurtosis.com/install
[starlark-docs]: https://docs.kurtosis.com/explanations/starlark
[using-the-cli]: https://docs.kurtosis.com/cli
[prysm-issue]: https://github.com/prysmaticlabs/prysm/issues/11508
[erigon-issue]: https://github.com/kurtosis-tech/eth2-merge-kurtosis-module/issues/154
