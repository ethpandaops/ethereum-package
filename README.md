Ethereum Module
=======================

This is a [Kurtosis Starlark module][starlark-docs] that will:

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
1. Create a file in your home directory `eth2-module-params.yaml` with the following contents:

   ```yaml
   logLevel: "info"
   ```

1. Execute the module, passing in the params from the file:
   ```bash
   kurtosis module exec --enclave-id eth2 github.com/kurtosis-tech/eth2-module --args "$(cat ~/eth2-module-params.yaml)"
   ```

Management
----------

Kurtosis will create a new enclave to house the services of the Ethereum network. [This page][using-the-cli] contains documentation for managing the created enclave & viewing detailed information about it.

Configuration
-------------

To configure the module behaviour, you can modify your `eth2-module-params.yaml` file. The full YAML schema that can be passed in is as follows with the defaults ([from here](https://github.com/kurtosis-tech/eth2-module/blob/master/types.proto) provided:

Note: Following an update starting the network post-merge, `nimbus` and `prysm` clients don't work anymore. Fixes are tracked in the following Github issues:
- Prysm: [#11508][prysm-issue]
- Nimbus: [#4193][nimbus-issue]

<details>
    <summary>Click to show all configuration options</summary>

<!-- Yes, it's weird that none of this is indented but it's intentional - indenting anything inside this "details" expandable will cause it to render weird" -->
```
```
</details>

You can find the latest Kiln compatible docker images here: https://notes.ethereum.org/@launchpad/kiln

Developing On This Module
-------------------------
First, install prerequisites:
1. Install Go
1. [Install Kurtosis itself](https://docs.kurtosistech.com/installation.html)

Then, run the dev loop:
1. Make your code changes
1. Rebuild and re-execute the module by running the following from the root of the repo:
   ```bash
   source scripts/_constants.env && \
       kurtosis enclave rm -f eth2-local && \
       bash scripts/build.sh && \
       kurtosis module exec --enclave-id eth2-local "${IMAGE_ORG_AND_REPO}:$(bash scripts/get-docker-image-tag.sh)" --execute-params "{}"
   ```
   NOTE 1: You can change the value of the `--execute-params` flag to pass in extra configuration to the module per the "Configuration" section above!
   NOTE 2: The `--execute-params` flag accepts YAML and YAML is a superset of JSON, so you can pass in either.

To get detailed information about the structure of the module, visit [the architecture docs](./docs/architecture.md).

When you're happy with your changes:
- Add an entry to `docs/changelog.md` under the `# TBD` header describing your changes (this is required for CI checks to pass!)
- Create a PR
- Add one of the maintainers of the repo as a "Review Request":
    - `parithosh` (Ethereum)
    - `gbouv` (Kurtosis)
    - `h4ck3rk3y` (Kurtosis)
    - `mieubrisse` (Kurtosis)
- Once everything works, merge! 

<!------------------------ Only links below here -------------------------------->
[docker-installation]: https://docs.docker.com/get-docker/
[kurtosis-cli-installation]: https://docs.kurtosistech.com/installation.html
[starlark-docs]: https://docs.kurtosis.com/starlark
[enclave-context]: https://docs.kurtosistech.com/kurtosis-core/lib-documentation#enclavecontext
[using-the-cli]: https://docs.kurtosistech.com/using-the-cli.html
[prysm-issue]: https://github.com/prysmaticlabs/prysm/issues/11508
[nimbus-issue]: https://github.com/status-im/nimbus-eth2/issues/4193

## Known Bugs

`wait_for_epoch_finalization` - doesn't work as expected, as Starlark doesn't have ways to do assertions on facts just yet. The issue #15 tracks this.