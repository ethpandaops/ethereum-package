Package Architecture
===================
This repo is a Kurtosis package. To get general information on what a Kurtosis package is and how it works, visit [the Starlark documentation](https://docs.kurtosis.com/explanations/starlark).

The overview of this particular package's operation is as follows:

1. Parse user parameters
1. Launch a network of Ethereum participants
    1. Generate execution layer (EL) client config data
    1. Launch EL clients
    1. Wait for EL clients to start mining, such that all EL clients have a nonzero block number
    1. Generate consensus layer (CL) client config data
    1. Launch CL clients
1. Launch auxiliary services (Grafana, Forkmon, etc.)
1. Run Ethereum Merge verification logic
1. Return information to the user

Overview
--------
The package has six main components, in accordance with the above operation:

1. [Main Function][main-function]
1. [Package I/O][package-io]
1. [Static Files][static-files]
1. [Participant Network][participant-network]
1. [Auxiliary Services][auxiliary-services]
1. [Merge Verification Logic][testnet-verifier]

[Main][main-function]
------------------------------------
The main function is the package's entrypoint, where parameters are received from the user, lower-level calls are made, and a response is returned.

[Package I/O][package-io]
-----------------------
This particular package has many configuration options (see the "Configuration" section in the README for the full list of values). These are passed in as a JSON-serialized string, and arrive to the package's main function via the `input_args` variable. The process of setting defaults, overriding them with the user's desired options, and validating the resulting config object requires some space in the codebase. All this logic happens inside the `package_io` directory, so you'll want to visit this directory if you want to:

- View or change parameters that the package can receive
- Change the default values of package parameters
- View or change the validation logic that the package applies to configuration parameters
- View or change the properties that the package passes back to the user after execution is complete

[Static Files][static-files]
----------------------------
Kurtosis packages can have static files that are made available inside the container during the package's operation. For this package, [the static files included][static-files] are various key files and config templates which get used during participant network operation.

[Participant Network][participant-network]
------------------------------------------
The participant network is the beating heart at the center of the package. The participant network code is responsible for:

1. Generating EL client config data
1. Starting the EL clients
1. Waiting until the EL clients have started mining
1. Generating CL client config data
1. Starting the CL clients

We'll explain these phases one by one.

### Generating EL client data
All EL clients require both a genesis file and a JWT secret. The exact format of the genesis file differs per client, so we first leverage [a Docker image containing tools for generating this genesis data][ethereum-genesis-generator] to create the actual files that the EL clients-to-be will need. This is accomplished by filling in several genesis generation config files found in [the `static_files` directory][static-files].

The generated output files then get stored in the Kurtosis enclave, ready for use when we start the EL clients. The information about these stored files is tracked in [the `el_genesis_data` struct](https://github.com/kurtosis-tech/eth2-package/blob/main/src/participant_network/prelaunch_data_generator/el_genesis/el_genesis_data.star).

### Starting EL clients
Next, we plug the generated genesis data [into EL client "launchers"](https://github.com/kurtosis-tech/eth2-package/tree/main/src/participant_network/el) to start a mining network of EL nodes. The launchers come with a `launch` function that consumes EL genesis data and produces information about the running EL client node. Running EL node information is represented by [an `el_client_context` struct](https://github.com/kurtosis-tech/eth2-package/blob/main/src/participant_network/el/el_client_context.star). Each EL client type has its own launcher (e.g. [Geth](https://github.com/kurtosis-tech/eth2-package/tree/main/src/participant_network/el/geth), [Besu](https://github.com/kurtosis-tech/eth2-package/tree/main/src/participant_network/el/besu)) because each EL client will require different environment variables and flags to be set when launching the client's container.

### Waiting until EL clients have started mining
Once we have a network of EL nodes started, we block until all EL clients have a block number > 0 to ensure that they are in fact working. After the nodes have started mining, we're ready to move on to adding the CL client network.

### Generating CL client data
CL clients, like EL clients, also have genesis and config files that they need. We use [the same Docker image with tools for generating genesis data][ethereum-genesis-generator] to create the necessary CL files, we provide the genesis generation config using templates in [the `static_files` directory][static-files], and we store the generated output files in the Kurtosis enclave in the same way as the EL client genesis files. Like with EL nodes, CL genesis data information is tracked in [the `cl_client_context` struct](https://github.com/kurtosis-tech/eth2-package/blob/main/src/participant_network/el/el_client_context.star).

The major difference with CL clients is that CL clients have validator keys, so we need to generate keys for the CL clients to use during validation. The generation happens using [the same genesis-generating Docker image][ethereum-genesis-generator], but via a call to [a different tool bundled inside the Docker image](https://github.com/protolambda/eth2-val-tools).

### Starting CL clients
Once CL genesis data and keys have been created, the CL client nodes are started via [the CL client launchers](https://github.com/kurtosis-tech/eth2-package/tree/main/src/participant_network/cl). Just as with EL clients:

- CL client launchers implement come with a `launch` method
- One CL client launcher exists per client type (e.g. [Nimbus](https://github.com/kurtosis-tech/eth2-package/tree/main/src/participant_network/cl/nimbus), [Lighthouse](https://github.com/kurtosis-tech/eth2-package/tree/main/src/participant_network/cl/lighthouse))
- Launched CL node information is tracked in [a `cl_client_context` struct](https://github.com/kurtosis-tech/eth2-package/blob/main/src/participant_network/cl/cl_client_context.star)

There are only two major difference between CL client and EL client launchers. First, the `cl_client_launcher.launch` method also consumes an `el_client_context`, because each CL client is connected in a 1:1 relationship with an EL client. Second, because CL clients have keys, the keystore files are passed in to the `launch` function as well.

Auxiliary Services
------------------
After the Ethereum network is up and running, this package starts several auxiliary containers to make it easier to work with the Ethereum network. At time of writing, these are:

- [Forkmon](https://github.com/kurtosis-tech/eth2-package/tree/main/src/forkmon), a "fork monitor" web UI for visualizing the CL clients' forks
- [Prometheus](https://github.com/kurtosis-tech/eth2-package/tree/main/src/prometheus) for collecting client node metrics
- [Grafana](https://github.com/kurtosis-tech/eth2-package/tree/main/src/grafana) for visualizing client node metrics
- [An ETH transaction spammer](https://github.com/kurtosis-tech/eth2-package/tree/main/src/transaction_spammer), which [has been forked off](https://github.com/kurtosis-tech/tx-fuzz) of [Marius' transaction spammer code](https://github.com/MariusVanDerWijden/tx-fuzz) so that it can run as a container

[Testnet Verifier][testnet-verifier]
------------------------------------
Once the Ethereum network is up and running, verification logic will be run to ensure that the Merge has happened successfully. This happens via [a testnet-verifying Docker image](https://github.com/ethereum/merge-testnet-verifier) that periodically polls the network to check the state of the merge. If the merge doesn't occur, the testnet-verifying image returns an unsuccessful exit code which in turn signals the Kurtosis package to exit with an error. This merge verification can be disabled in the package's configuration (see the "Configuration" section in the README).

<!------------------------ Only links below here -------------------------------->

[enclave-context]: https://docs.kurtosistech.com/kurtosis/core-lib-documentation#enclavecontext

[main-function]: https://github.com/kurtosis-tech/eth2-package/blob/main/main.star#22
[package-io]: https://github.com/kurtosis-tech/eth2-package/tree/main/src/package_io
[participant-network]: https://github.com/kurtosis-tech/eth2-package/tree/main/src/participant_network
[ethereum-genesis-generator]: https://github.com/skylenet/ethereum-genesis-generator
[static-files]: https://github.com/kurtosis-tech/eth2-package/tree/main/static_files
[testnet-verifier]: https://github.com/kurtosis-tech/eth2-package/tree/main/src/testnet_verifier

[auxiliary-services]: #auxiliary-services