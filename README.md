# Ethereum Package

![Run of the Ethereum Network Package](run.gif)

This is a [Kurtosis][kurtosis-repo] package that will spin up a private Ethereum testnet over Docker or Kubernetes with multi-client support, Flashbot's `mev-boost` infrastructure for PBS-related testing/validation, and other useful network tools (transaction spammer, monitoring tools, etc). Kurtosis packages are entirely reproducible and composable, so this will work the same way over Docker or Kubernetes, in the cloud or locally on your machine.

You now have the ability to spin up a private Ethereum testnet or public network (e.g. mainnet, sepolia, hoodi) with a single command. This package is designed to be used for testing, validation, and development of Ethereum clients, and is not intended for production use. For more details check network_params.network in the [configuration section](./README.md#configuration).

Specifically, this [package][package-reference] will:

1. Generate Execution Layer (EL) & Consensus Layer (CL) genesis information using [the Ethereum genesis generator](https://github.com/ethpandaops/ethereum-genesis-generator).
2. Configure & bootstrap a network of Ethereum nodes of *n* size using the genesis data generated above
3. Spin up a [transaction spammer](https://github.com/MariusVanDerWijden/tx-fuzz) to send fake transactions to the network
4. Spin up a Grafana and Prometheus instance to observe the network
5. Spin up a Blobscan instance to analyze blob transactions (EIP-4844)

Optional features (enabled via flags or parameter files at runtime):

- Block until the Beacon nodes finalize an epoch (i.e. finalized_epoch > 0)
- Spin up & configure parameters for the infrastructure behind PBS (Proposer-Builder Separation) using `mev-boost`, with support for multiple relay implementations:
  - `flashbots` - Full Flashbots MEV infrastructure
  - `helix` - High-performance [Helix relay](https://github.com/gattaca-com/helix) with TimescaleDB backend
  - `mev-rs` - Alternative relay implementation
  - `commit-boost` - Commit-boost based infrastructure
  - `mock` - Mock builder for testing
  - [More details on PBS implementation](./README.md#proposer-builder-separation-pbs-emulation).
- Spin up and connect a [JSON RPC Snooper](https://github.com/ethDreamer/json_rpc_snoop) to the network log responses & requests between the EL engine API and the CL client.
- Specify extra parameters to be passed in for any of the: CL client Beacon, and CL client validator, and/or EL client containers
- Specify the required parameters for the nodes to reach an external block building network
- Generate keystores for each node in parallel
- Spin up [TrueBlocks](https://github.com/TrueBlocks/trueblocks-core) (`chifra daemon`) to serve the chifra REST API on port 8080 (`/status`, `/blocks`, `/list`, `/chunks`, etc.). The scraper isn't started automatically; POST `/scrape` (or run `chifra scrape` against the same data dir) when you want to build the local [Unchained Index](https://trueblocks.io/docs/install/get-the-index/). Auto-tunes scrape parameters for devnets vs public networks.
- Ship traces from every EL/CL/VC to the engine-level Kurtosis OTel stack started with `kurtosis otel start` by adding `otel` to `additional_services`. Traces land in the shared ClickHouse tenanted by enclave; requires the Docker backend.

## Quickstart

1. [Install Docker & start the Docker Daemon if you haven't done so already][docker-installation]
2. [Install the Kurtosis CLI, or upgrade it to the latest version if it's already installed][kurtosis-cli-installation]
3. Run the package with default configurations from the command line:

   ```bash
   kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package
   ```

### Run with your own configuration

Kurtosis packages are parameterizable, meaning you can customize your network and its behavior to suit your needs by storing parameters in a file that you can pass in at runtime like so:

```bash
kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package --args-file network_params.yaml
```

Where `network_params.yaml` contains the parameters for your network in your home directory.

#### Run on Kubernetes

Kurtosis packages work the same way over Docker or on Kubernetes. Please visit our [Kubernetes docs](https://docs.kurtosis.com/k8s) to learn how to spin up a private testnet on a Kubernetes cluster.

### Considerations for Running on a Public Testnet with a Cloud Provider

When running on a public testnet using a cloud provider's Kubernetes cluster, there are a few important factors to consider:

1. State Growth: The growth of the state might be faster than anticipated. This could potentially lead to issues if the default parameters become insufficient over time. It's important to monitor state growth and adjust parameters as necessary.

2. Persistent Storage Speed: Most cloud providers provision their Kubernetes clusters with relatively slow persistent storage by default. This can cause performance issues, particularly with Execution Layer (EL) clients.

3. Network Syncing: The disk speed provided by cloud providers may not be sufficient to sync with networks that have high demands, such as the mainnet. This could lead to syncing issues and delays.

To mitigate these issues, you can use the `el_volume_size` and `cl_volume_size` flags to override the default settings locally. This allows you to allocate more storage to the EL and CL clients, which can help accommodate faster state growth and improve syncing performance. However, keep in mind that increasing the volume size may also increase your cloud provider costs. Always monitor your usage and adjust as necessary to balance performance and cost.

For optimal performance, we recommend using a cloud provider that allows you to provision Kubernetes clusters with fast persistent storage or self hosting your own Kubernetes cluster with fast persistent storage.

### Shadowforking

In order to enable shadowfork capabilities, you can use the `network_params.network` flag. The expected value is the name of the network you want to shadowfork followed by `-shadowfork`. Please note that `persistent` configuration parameter has to be enabled for shadowforks to work! Current limitation on k8s is it is only working on a single node cluster. For example, to shadowfork the Hoodi testnet, you can use the following command:

```yaml
...
network_params:
  network: "hoodi-shadowfork"
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

Check out the [full list of Kurtosis CLI commands](https://docs.kurtosis.com/cli)

## Debugging

To grab the genesis files for the network, simply run:

```bash
kurtosis files download my-testnet $FILE_NAME $OUTPUT_DIRECTORY
```

For example, to retrieve the Execution Layer (EL) genesis data, run:

```bash
kurtosis files download my-testnet el-genesis-data ~/Downloads
```

## Basic file sharing

Nginx is included in the package to allow for basic file sharing. The nginx service is started when additional services are enabled. It exposes the contents of the `network-configs` directory at the URL root, including the canonical metadata files used by the bal-devnets layout:

- `/enodes.txt` — newline-separated EL enodes
- `/bootstrap_nodes.txt` — newline-separated CL ENRs
- `/bootstrap_nodes.yaml` — same ENRs as a YAML list
- `/network-config.tar` — full genesis bundle (`config.yaml`, `genesis.ssz`, `genesis.json`, etc.) plus the three files above

```yaml
additional_services:
  - nginx
```

## Syncing one enclave from another

You can have a target enclave (B) sync from a running source enclave (A). Source A runs `nginx` and publishes its enodes/ENRs/genesis bundle; target B sets `network: kt-<A-host>:<A-nginx-port>` and bootstraps off A.

Source enclave A — must publish EL/CL ports with a routable NAT IP, otherwise the published enodes advertise unreachable docker-internal IPs:

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
  - el_type: reth
    cl_type: teku

# nginx_port defaults to 9090 — set it here only if you want a different port

port_publisher:
  nat_exit_ip: <A-routable-host-ip>  # or "auto"
  el:
    enabled: true
  cl:
    enabled: true

additional_services:
  - nginx
```

Target enclave B — point `network` at A's nginx:

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
    el_extra_params:
      - --syncmode=full   # see caveat below

network_params:
  network: kt-<A-host>:9090
```

Validator counts are auto-zeroed for `kt-` networks, so B is observer-mode by default.

> [!NOTE]
> Geth's snap-sync wedges with `missing trie node ... layer stale` when joining a fresh devnet that's still building state. Either set `el_extra_params: [--syncmode=full]` on the target, or wait until the source has finalized at least one epoch before launching the target.

### How it works

The flow is intentionally a thin wrapper around the existing devnet-sync path:

1. **Source A's nginx** mounts the `el_cl_genesis_data` artifact at `/network-configs/`, generates `enodes.txt` / `bootstrap_nodes.txt` / `bootstrap_nodes.yaml` from the live EL/CL contexts at startup (so the addresses inside reflect the actual NAT IPs and published ports), bundles everything into `network-config.tar`, and serves the tar plus the three loose files from the nginx root URL.
2. **Source A's EL clients** advertise their enodes using `port_publisher.el.nat_exit_ip` (e.g. `geth --nat=extip:<ip>`). That's why the warning fires when `nat_exit_ip` is unset: without it, every enode in `enodes.txt` points at a docker-internal address that nobody else can reach.
3. **Target B's network launcher** sees `network: kt-<host>:<port>`, curls `http://<host>:<port>/network-config.tar`, and extracts it into the same `el_cl_genesis_data` files artifact name the other launchers use. From here, B's EL/CL launchers fall through to the existing devnet code paths — they read `/network-configs/enodes.txt` and `/network-configs/bootstrap_nodes.txt` to populate `--bootnodes` / `--boot-nodes` flags on the clients. **No client launcher code is aware of cross-enclave sync.**
4. **Validator counts are zeroed on B** by the existing logic that already excludes non-`kurtosis`/`shadowfork` networks from validator key generation, so B starts as an observer.

In effect, A's nginx plays the same role for B that the GitHub-hosted `network-configs/<devnet>/metadata` directory plays for a normal `network: foo-devnet-N` config — it's the canonical bundle of "everything you need to join this network."

#### What gets reused vs. what's new

- **Reused:** EL/CL bootnode wiring (`shared_utils.get_devnet_enodes` / `get_devnet_enrs_list`), genesis-bundle file layout, port publishing, NAT-IP enode advertisement.
- **New:** `kt-<host>:<port>` parsing (`src/network_launcher/remote_enclave.star`), nginx file naming + URL layout match the bal-devnets metadata convention.

#### Limits / gotchas

- The two enclaves must reside on a network where B's curl/discovery containers can reach A's published nginx port and EL/CL public ports. Same-host works because Docker publishes ports on the host's interfaces; cross-host works as long as the NAT IP set on A is routable from B.
- A's nginx snapshot is taken at A's startup. If A restarts and gets new node identities, B must be torn down and redeployed against the new bundle.
- Geth snap-sync brittleness applies as noted above; CL sync is unaffected.

## More config examples

Looking for ready-to-run YAML configs beyond the snippets above?

- [`.github/tests/`](https://github.com/ethpandaops/ethereum-package/tree/main/.github/tests) — every config in this directory is exercised by CI (`per-pr.yml` / `nightly.yml`), so they're the broadest source of known-working examples (single-client, MEV, mix-with-tools, persistence, shadowforks, etc.).
- [`.github/tests/examples/`](https://github.com/ethpandaops/ethereum-package/tree/main/.github/tests/examples) — opt-in examples that CI does not auto-run (large GPU configs, mainnet/shadowfork setups, the `source-enclave-nginx.yaml` / `remote-enclave-nginx.yaml` pair from the section above).

Copy any of them to your local working directory and run with `kurtosis run --enclave <name> . --args-file <path>`.

### Disruptoor example

Use [`.github/tests/examples/disruptoor.yaml`](.github/tests/examples/disruptoor.yaml) to launch a small two-node network with Disruptoor and Dora. The example applies a CL partition between node 1 and node 2 at startup, then adds latency and jitter to every component on node 1.

```bash
kurtosis run --enclave disruptoor-example . --args-file .github/tests/examples/disruptoor.yaml --privileged --verbosity detailed
```

Disruptoor is Docker-only. The package fails early on Kubernetes because Disruptoor needs privileged mode, `/var/run/docker.sock`, and the host PID namespace to shape peer traffic. The `--privileged` run flag is required so Kurtosis allows those Docker-only service settings.

The friendly Disruptoor config in `disruptoor_params` uses ethereum-package participant numbers. `participants: [1]` targets the first configured node, `participants: [2]` targets the second, and `participants: all` targets all nodes. `components` can be `el`, `cl`, `vc`, or `all`; `components: all` expands to all three and cannot be mixed with other component names. The example enables `port_publisher.additional_services` so `kurtosis enclave inspect disruptoor-example` shows forwarded HTTP ports for additional services such as Disruptoor and Dora.

`partitions` split selected peer traffic into isolated groups. In the example, the partition targets only `components: [cl]`, so the beacon-node P2P traffic for node 1 and node 2 is separated while their EL and VC services are not part of that partition. If no explicit `scope` is provided, the package derives the partition scope from the selected EL/CL components (`el_p2p` and/or `cl_p2p`). VC-only partitions need an explicit native `scope` because validators do not add a default P2P partition scope.

`shaping` changes network conditions for selected services without fully disconnecting them. A shaping rule can add `delay`, add `jitter` when `delay` is set, inject `loss`, cap `bandwidth`, and optionally set `direction`. In the example, `components: all` selects node 1's EL, CL, and VC services, then adds 50ms of delay plus 10ms of jitter to matching traffic.

`include_control: true` tells the friendly config translator to include Disruptoor's control/acknowledgement traffic in the generated shaping scope. Disruptoor v0 shaping requires that control traffic so the shaper can apply and acknowledge the rule.

Common issues:

- `unknown flag: --privileged` or `ServiceConfig: unexpected keyword argument "privileged"`: upgrade both the Kurtosis CLI and engine to a build that supports privileged runs for Docker-only services.
- `disruptoor requires Kurtosis' Docker backend`: switch Kurtosis to the Docker backend and rerun the package.
- Shaping rules fail with `include_control must be true`: add `include_control: true`, or set `scope` explicitly with `include_control` included.
- `disruptoor_params.config cannot be used together with disruptoor_params.partitions or disruptoor_params.shaping`: use either native Disruptoor state under `config` or the friendly `partitions` / `shaping` fields, not both.
- A partition using only `components: [vc]` fails unless you set `scope` explicitly; the default partition scope is derived from EL/CL P2P traffic.

## Configuration

To configure the package behaviour, you can modify your `network_params.yaml` file. The full YAML schema that can be passed in is as follows with the defaults provided:

```yaml
# Specification of the participants in the network
participants:
  # EL(Execution Layer) Specific flags
    # The type of EL client that should be started
    # Valid values are geth, nethermind, erigon, besu, ethereumjs, reth, nimbus-eth1, ethrex, None
    # Use el_type: None to run the participant without an execution client (CL-only; execution-endpoint and JWT secret are omitted)
  - el_type: geth

    # The Docker image that should be used for the EL client; leave blank to use the default for the client type
    # Defaults by client:
    # - geth: ethereum/client-go:latest
    # - erigon: erigontech/erigon:latest
    # - nethermind: ethpandaops/nethermind:master
    # - besu: hyperledger/besu:latest
    # - reth: ghcr.io/paradigmxyz/reth
    # - ethereumjs: ethpandaops/ethereumjs:master
    # - nimbus-eth1: statusim/nimbus-eth1:master
    # - ethrex: ethpandaops/ethrex:main
    el_image: ""

    # Path to a local EL binary to inject into the container (Docker only)
    # When set, the binary will be uploaded and mounted into the container,
    # replacing the default binary from the Docker image
    # Useful for rapid debugging with locally compiled binaries
    # IMPORTANT: el_force_restart must be set to true when using this option
    # IMPORTANT: The binary file must live inside the ethereum-package directory
    # Build the client in its own repo, then copy ONLY the binary to ethereum-package
    # Do not run builds inside ethereum-package or copy build dependencies - only the final binary
    # IMPORTANT: The binary must be compiled on a Linux system with compatible libraries
    # matching those in the client's Dockerfile to avoid dependency issues
    # Example workflow (from reth repo):
    #   cargo build --release --bin reth && cp target/release/reth ../ethereum-package/binaries/
    # Then set: el_binary_path: "./binaries/reth"
    el_binary_path: ""

    # The log level string that this participant's EL client should log at
    # If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
    # global `logLevel` = `info` then Geth would receive `3`, Besu would receive `INFO`, etc.)
    # If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
    # over a specific participant's logging
    # Set to "custom" (Besu only) to disable global logging settings and leave it up to the client configuration,
    # for example, when using a custom log4j2.xml file
    el_log_level: ""

    # The storage type for the EL client: "full" or "archive"
    # IMPORTANT: Consider updating el_volume_size if you set this
    # If this is emptystring, each client will use its default behavior:
    #   - reth, erigon: default to archive (use "full" to save space)
    #   - geth, besu, nethermind: default to full (use "archive" to keep historical data)
    #   - ethereumjs, ethrex, nimbus-eth1: unused (full only?)
    # Example: el_storage_type: "full" or "archive"
    el_storage_type: ""

    # A list of optional extra env_vars the el container should spin up with
    el_extra_env_vars: {}

    # A list of optional extra labels the el container should spin up with
    # Example: el_extra_labels: {"ethereum-package.partition": "1"}
    el_extra_labels: {}

    # A list of optional extra params that will be passed to the EL client container for modifying its behaviour
    el_extra_params: []

    # A list of optional extra mount points that will be passed to the EL client container
    # Key is the mount path (becomes a directory), value MUST reference a key from extra_files
    # The file will be available at <mount_path>/<extra_files_key>
    # Example: el_extra_mounts: {"/config": "my_config_file"}  # Creates /config/my_config_file
    el_extra_mounts: {}

    # A list of host devices to mount into the EL client container
    # Useful for hardware device access like TPM, HSM, etc.
    # Example: el_devices: ["/dev/tpm0"]
    # Defaults to empty list
    el_devices: []

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
    # IMPORTANT: Consider settings this if you are setting el_storage_type
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

    # Force container recreation on next run (Docker only)
    # When set to true, the container will be recreated even if the image tag hasn't changed
    # Useful when rebuilding Docker images with the same tag or recompiling binaries with the same name
    # Defaults to false
    el_force_restart: false

  # CL(Consensus Layer) Specific flags
    # The type of CL client that should be started
    # Valid values are nimbus, lighthouse, lodestar, teku, prysm, and grandine
    cl_type: lighthouse

    # The Docker image that should be used for the CL client; leave blank to use the default for the client type
    # Defaults by client:
    # - lighthouse: ethpandaops/lighthouse:unstable
    # - teku: ethpandaops/teku:master
    # - nimbus: ethpandaops/nimbus-eth2:unstable
    # - prysm: ethpandaops/prysm-beacon-chain:develop
    # - lodestar: chainsafe/lodestar:latest
    # - grandine: sifrai/grandine:stable
    cl_image: ""

    # Path to a local CL binary to inject into the container (Docker only)
    # When set, the binary will be uploaded and mounted into the container,
    # replacing the default binary from the Docker image
    # Useful for rapid debugging with locally compiled binaries
    # IMPORTANT: cl_force_restart must be set to true when using this option
    # IMPORTANT: The binary file must live inside the ethereum-package directory
    # Build the client in its own repo, then copy ONLY the binary to ethereum-package
    # Do not run builds inside ethereum-package or copy build dependencies - only the final binary
    # IMPORTANT: The binary must be compiled on a Linux system with compatible libraries
    # matching those in the client's Dockerfile to avoid dependency issues
    # Example workflow (from lighthouse repo):
    #   cargo build --release --bin lighthouse && cp target/release/lighthouse ../ethereum-package/binaries/
    # Then set: cl_binary_path: "./binaries/lighthouse"
    cl_binary_path: ""

    # The log level string that this participant's CL client should log at
    # If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
    # global `logLevel` = `info` then Teku would receive `INFO`, Prysm would receive `info`, etc.)
    # If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
    # over a specific participant's logging
    # Set to "custom" (Teku only) to disable global logging settings and leave it up to the client configuration,
    # for example, when using a custom log4j.xml file
    cl_log_level: ""

    # A list of optional extra env_vars the cl container should spin up with
    cl_extra_env_vars: {}

    # A list of optional extra labels that will be passed to the CL client Beacon container.
    # Example; cl_extra_labels: {"ethereum-package.partition": "1"}
    cl_extra_labels: {}

    # A list of optional extra params that will be passed to the CL client Beacon container for modifying its behaviour
    # If the client combines the Beacon & validator nodes (e.g. Teku, Nimbus), then this list will be passed to the combined Beacon-validator node
    cl_extra_params: []

    # A list of optional extra mount points that will be passed to the CL client container
    # Key is the mount path (becomes a directory), value MUST reference a key from extra_files
    # The file will be available at <mount_path>/<extra_files_key>
    # Example: cl_extra_mounts: {"/config": "my_config_file"}  # Creates /config/my_config_file
    cl_extra_mounts: {}

    # A list of host devices to mount into the CL client container
    # Useful for hardware device access like TPM, HSM, etc.
    # Example: cl_devices: ["/dev/tpm0"]
    # Defaults to empty list
    cl_devices: []

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

    # Force container recreation on next run (Docker only)
    # When set to true, the container will be recreated even if the image tag hasn't changed
    # Useful when rebuilding Docker images with the same tag or recompiling binaries with the same name
    # Defaults to false
    cl_force_restart: false

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
    # - nimbus: ethpandaops/nimbus-validator-client:unstable
    # - prysm: ethpandaops/prysm-validator:develop
    # - teku: ethpandaops/teku:master
    # - vero: ghcr.io/serenita-org/vero:latest
    vc_image: ""

    # Path to a local VC binary to inject into the container (Docker only)
    # When set, the binary will be uploaded and mounted into the container,
    # replacing the default binary from the Docker image
    # Useful for rapid debugging with locally compiled binaries
    # IMPORTANT: vc_force_restart must be set to true when using this option
    # IMPORTANT: The binary file must live inside the ethereum-package directory
    # Build the client in its own repo, then copy ONLY the binary to ethereum-package
    # Do not run builds inside ethereum-package or copy build dependencies - only the final binary
    # IMPORTANT: The binary must be compiled on a Linux system with compatible libraries
    # matching those in the client's Dockerfile to avoid dependency issues
    # Example workflow (from lighthouse repo):
    #   cargo build --release --bin lighthouse && cp target/release/lighthouse ../ethereum-package/binaries/
    # Then set: vc_binary_path: "./binaries/lighthouse"
    vc_binary_path: ""

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

    # A list of optional extra mount points that will be passed to the validator client container
    # Key is the mount path (becomes a directory), value MUST reference a key from extra_files
    # The file will be available at <mount_path>/<extra_files_key>
    # Example: vc_extra_mounts: {"/config": "my_validator_config"}  # Creates /config/my_validator_config
    vc_extra_mounts: {}

    # A list of host devices to mount into the validator client container
    # Useful for hardware device access like TPM, HSM, etc.
    # Example: vc_devices: ["/dev/tpm0"]
    # Defaults to empty list
    vc_devices: []

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

    # Force container recreation on next run (Docker only)
    # When set to true, the container will be recreated even if the image tag hasn't changed
    # Useful when rebuilding Docker images with the same tag or recompiling binaries with the same name
    # Defaults to false
    vc_force_restart: false

    # A list of indices of the beacon nodes that the validator client should connect to
    # Defaults to null
    vc_beacon_node_indices: null

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

    # Buildoor (a self-contained block builder) is configured independently of the
    # participants via `buildoor_params.instances` (see below), not per participant.

    # Blobber can be enabled with the `blobber_enabled` flag per client or globally
    # Defaults to false
    blobber_enabled: false

    # Blobber extra params can be passed in to the blobber container
    # Defaults to empty
    blobber_extra_params: []

    # Blobber image to be used for the blobber container
    # Defaults to empty
    blobber_image: ethpandaops/blobber:latest

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

    # Per-participant override for checkpoint sync. If set, this will override the global checkpoint_sync_enabled flag for this participant.
    # Defaults to null (uses global checkpoint_sync_enabled setting)
    checkpoint_sync_enabled: null

    # If set to true, the beacon node will be created and then immediately stopped.
    # No health checks are performed during creation (ready_conditions are disabled).
    # The service can be started later using: kurtosis service start <enclave> <service-name>
    # This is useful for testing or when you want to manually control when the beacon node starts.
    # Defaults to false
    skip_start: false

# Participants matrix creates a participant for each combination of EL, CL, VC
# and remote signer clients.
# Each el/cl/vc/remote_signer item can provide the same parameters as a standard participant.
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
  # remote_signer:
  #   - remote_signer_type: web3signer
  #     remote_signer_image: consensys/web3signer:develop
  # Defining a remote_signer entry enables it automatically.
  # NOTE: a remote signer requires `use_separate_vc: true` on the matching cl item.


# Default configuration parameters for the network
network_params:
  # Network name, used to enable syncing of alternative networks
  # Defaults to "kurtosis"
  # You can sync any public network by setting this to the network name (e.g. "mainnet", "sepolia", "hoodi")
  # You can sync any devnet by setting this to its name (e.g. "peerdas-devnet-N", "fusaka-devnet-N", "berlinterop-devnet-N")
  # You can sync from another running kurtosis enclave by setting this to "kt-<host>:<nginx-port>"
  # (see "Syncing one enclave from another" above)
  network: "kurtosis"

  # The network ID of the network.
  network_id: "3151908"

  # The address of the staking contract address on the Eth1 chain
  deposit_contract_address: "0x00000000219ab540356cBB839Cbe05303d7705Fa"

  # Number of seconds per slot on the Beacon chain
  seconds_per_slot: 12

  # Duration of a slot in milliseconds
  # Defaults to 12000ms (12 seconds)
  slot_duration_ms: 12000

  # Gloas fork timing parameters (optimized for faster slots)
  # Attestation due timing for Gloas fork
  # Defaults to 2500 basis points (25% of slot duration)
  attestation_due_bps_gloas: 2500

  # Aggregate due timing for Gloas fork
  # Defaults to 5000 basis points (50% of slot duration)
  aggregate_due_bps_gloas: 5000

  # Sync message due timing for Gloas fork
  # Defaults to 2500 basis points (25% of slot duration)
  sync_message_due_bps_gloas: 2500

  # Contribution due timing for Gloas fork
  # Defaults to 5000 basis points (50% of slot duration)
  contribution_due_bps_gloas: 5000

  # Payload availability deadline for Gloas fork
  # Defaults to 5000 basis points (50% of slot duration)
  payload_due_bps: 5000

  # Payload attestation due timing for Gloas fork
  # Defaults to 7500 basis points (75% of slot duration)
  payload_attestation_due_bps: 7500

  # Heze timing parameters
  # View freeze cutoff timing
  # Defaults to 7500 basis points (75% of slot duration)
  view_freeze_cutoff_bps: 7500

  # Inclusion list submission due timing
  # Defaults to 6667 basis points (~67% of slot duration)
  inclusion_list_submission_due_bps: 6667

  # Proposer inclusion list cutoff timing
  # Defaults to 9167 basis points (~92% of slot duration)
  proposer_inclusion_list_cutoff_bps: 9167

  # Maximum request blocks for Deneb fork
  # Defaults to 128
  max_request_blocks_deneb: 128

  # The number of validator keys that each CL validator node should get
  num_validator_keys_per_node: 128

  # This mnemonic will a) be used to create keystores for all the types of validators that we have and b) be used to generate a CL genesis.ssz that has the children
  # validator keys already preregistered as validators
  preregistered_validator_keys_mnemonic: "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete"

  # The number of pre-registered validators for genesis. If 0 or not specified then the value will be calculated from the participants
  preregistered_validator_count: 0

  # Additional mnemonics to generate validators from
  # These validators will be included in genesis but won't have keystores generated
  # Useful for pre-registering validators with custom withdrawal credentials or states
  # Default: []
  additional_mnemonics:
    - # The mnemonic to derive validator keys from
      mnemonic: "estate dog switch misery manage room million bleak wrap distance always insane usage busy chicken limit already duck feature unhappy dial emotion expire please"
      # The validator index to start deriving keys from
      # Defaults to 0
      start: 0
      # The number of validators to generate from this mnemonic
      count: 10
      # The withdrawal address for these validators
      # Only used when wd_prefix is 0x01 or 0x02 (execution layer withdrawal credentials)
      wd_address: 0x000000000000000000000000000000000000dEaD
      # The withdrawal credentials prefix
      # 0x00: BLS withdrawal credentials (default)
      # 0x01: Execution layer withdrawal credentials (uses wd_address)
      # 0x02: Compounding withdrawal credentials (uses wd_address)
      wd_prefix: 0x01
      # The validator balance in gwei
      # Defaults to 32000000000 (32 ETH)
      balance: 32000000000
      # The initial validator status
      # 0: active (default)
      # 1: slashed
      # 2: exited
      status: 1

  # Shuffle genesis validator ranges to start with a more realistic, non-contiguous validator allocation
  shuffle_genesis_validators: false

  # How long you want the network to wait before starting up
  genesis_delay: 20

  # Unix timestamp for genesis. If specified (non-zero), this overrides genesis_delay.
  # When set to 0 (default), the genesis time is automatically calculated based on current time and genesis_delay.
  # Use this field to set a specific genesis time for the network.
  # Defaults to 0
  genesis_time: 0

  # The gas limit of the network set at genesis
  # Defaults to 60000000, but bumped to 200000000 when gloas_fork_epoch is set (not far-future)

  genesis_gaslimit: 60000000

  # Max churn rate for the network introduced by
  # EIP-7514 https://eips.ethereum.org/EIPS/eip-7514
  # Defaults to 8
  max_per_epoch_activation_churn_limit: 8

  # Churn limit quotient for the network
  # Defaults to 65536
  churn_limit_quotient: 65536

  # Byzantine threshold (in percent) used by the confirmation rule
  # Defaults to 25
  confirmation_byzantine_threshold: 25

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

  # The minimum number of epochs for builder withdrawability delay
  # Defaults to 64, 2 for minimal preset
  min_builder_withdrawability_delay: 64

  # Whether to include the EIP-8282 builder deposit/exit predeploys in genesis
  # when Gloas is scheduled (requires ethereum-genesis-generator >= 6.1.3)
  # Defaults to true
  deploy_eip8282_contracts: true

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
  # Defaults to 0
  fulu_fork_epoch: 0

  # Gloas fork epoch
  # Defaults to 18446744073709551615
  gloas_fork_epoch: 18446744073709551615

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
  # Example: shadowfork_block_height: 340000 for hoodi
  shadowfork_block_height: "latest"

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

  # Heze fork epoch
  # Defaults to 18446744073709551615
  heze_fork_epoch: 18446744073709551615


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
  # Default to 0, but bumped to 200000000 when gloas_fork_epoch is set (not far-future)
  # If set to 0, the gas limit will be set to the default gas limit for the clients
  # Set this value to gas limit in millionths of a gwei
  # Example: gas_limit: 60000000
  # This will override the gas limit for each EL client
  # Do not confuse with genesis_gaslimit which sets the gas limit at the genesis file level
  gas_limit: 0


  # BPO
  # BPO1-5 epoch (default 0/18446744073709551615)
  bpo_1_epoch: 0
  # Maximum number of blobs per block for BPO1-5
  # If only max is set, target is auto-calculated as 2/3 of max
  # If only target is set, max is auto-calculated as 3/2 of target
  bpo_1_max_blobs: 15
  # Target number of blobs per block for BPO1-5
  bpo_1_target_blobs: 10
  # Base fee update fraction for BPO1-5 (default 0)
  bpo_1_base_fee_update_fraction: 8346193

  bpo_2_epoch: 18446744073709551615
  bpo_2_max_blobs: 21
  bpo_2_target_blobs: 14
  bpo_2_base_fee_update_fraction: 11684671

  bpo_3_epoch: 18446744073709551615
  bpo_3_max_blobs: 0
  bpo_3_target_blobs: 0
  bpo_3_base_fee_update_fraction: 0

  bpo_4_epoch: 18446744073709551615
  bpo_4_max_blobs: 0
  bpo_4_target_blobs: 0
  bpo_4_base_fee_update_fraction: 0

  bpo_5_epoch: 18446744073709551615
  bpo_5_max_blobs: 0
  bpo_5_target_blobs: 0
  bpo_5_base_fee_update_fraction: 0

  # Withdrawal type - available options (0x00, 0x01, 0x02)
  # Default to "0x00"
  withdrawal_type: "0x00"

  # Withdrawal address
  # Default to "0x8943545177806ED17B9F23F0a21ee5948eCaa776" - 0 address of mnemonic
  withdrawal_address: "0x8943545177806ED17B9F23F0a21ee5948eCaa776"

  # Validator balance (available ranges: 32-2048)
  # Default to 32 ETH
  validator_balance: 32

  # Minimum number of epochs for data column sidecars requests
  # Default to 4096
  min_epochs_for_data_column_sidecars_requests: 4096

  # Number of ePBS builders to register at genesis with 0xB0 withdrawal credentials
  # Requires gloas_fork_epoch to be 0 (GLOAS at genesis)
  # Default to 0
  builder_count: 0

  # Balance of each builder in ETH
  # Default to 100 ETH
  builder_balance: 100


# Global parameters for the network

# By default we do not launch anything
# - Default: []
additional_services:
  - assertoor
  - blobscan
  - blockscout
  - blutgang
  - bootnodoor
  - broadcaster
  - checkpointz
  - custom_flood
  - dora
  - disruptoor
  - dugtrio
  - erpc
  - zkboost
  - forkmon
  - forky
  - full_beaconchain_explorer
  - grafana
  - mempool_bridge
  - nginx
  - otel
  - prometheus
  - rakoon
  - slashoor
  - spamoor
  - tempo
  - tracoor
  - trueblocks
  - tx_fuzz

# Configuration place for blockscout explorer - https://github.com/blockscout/blockscout
blockscout_params:
  # blockscout docker image to use
  # Defaults to ghcr.io/blockscout/blockscout:latest
  image: "ghcr.io/blockscout/blockscout:latest"
  # blockscout smart contract verifier image to use
  # Defaults to ghcr.io/blockscout/smart-contract-verifier:latest
  verif_image: "ghcr.io/blockscout/smart-contract-verifier:latest"
  # Frontend image
  # Defaults to ghcr.io/blockscout/frontend:latest
  frontend_image: "ghcr.io/blockscout/frontend:latest"
  # Environment variables
  env: {}

# Configuration place for dora the explorer - https://github.com/ethpandaops/dora
dora_params:
  # Dora docker image to use
  # Defaults to the latest image
  image: "ethpandaops/dora:latest"
  # A list of optional extra env_vars the dora container should spin up with
  env: {}

# Configuration place for checkpointz - https://github.com/ethpandaops/checkpointz
checkpointz_params:
  # Checkpointz docker image to use
  # Defaults to the latest image
  image: "ethpandaops/checkpointz:latest"

# Configuration place for trueblocks-core (chifra daemon) - https://github.com/TrueBlocks/trueblocks-core
trueblocks_params:
  # chifra docker image
  image: "ethpandaops/trueblocks:v5.9.3"
  # Written into [version].current in the rendered trueBlocks.toml. Bump if
  # you point `image` at a chifra release that requires a newer config schema.
  config_version: "v5.0.0"
  # Verbatim RPC URL chifra should target. Leave empty to use
  # all_el_contexts[target_index] (the in-cluster participant).
  target_rpc_url: ""
  target_index: 0
  # Per-chain scrape tuning, written into the rendered trueBlocks.toml.
  # 0 means "network-aware default" — chifra's mainnet values on public
  # networks, small/responsive values on devnets. The package runs only
  # chifra daemon; the scraper is not started automatically. Hit POST
  # /scrape on the daemon (or run `chifra scrape` against the same data
  # dir) when you want to build the local Unchained Index.
  scrape:
    apps_per_chunk: 0
    snap_to_grid: 0
    first_snap: 0
    unripe_dist: 0
  # Extra env vars passed to the chifra container.
  env: {}

# Define custom file contents to be mounted into containers
# These files are referenced by name in el_extra_mounts, cl_extra_mounts, and vc_extra_mounts
extra_files: {}
  # Example:
  # my_config_file.yaml: |
  #   setting1: value1
  #   setting2: value2
  # my_script.sh: |
  #   #!/bin/bash
  #   echo "Custom script"

# Configuration place for transaction spammer - https://github.com/MariusVanDerWijden/tx-fuzz
tx_fuzz_params:
  # TX Spammer docker image to use
  # Defaults to the latest master image
  image: "ethpandaops/tx-fuzz:master"
  # A list of optional extra params that will be passed to the TX Spammer container for modifying its behaviour
  tx_fuzz_extra_args: []

# Configuration place for rakoon transaction fuzzer - https://github.com/protocol-security/fuzztools
rakoon_params:
  # Rakoon docker image to use
  image: "ethpandaops/fuzztools:v1"
  # Transaction type to fuzz (eip7702, eip1559, eip2930, legacy)
  # Note: blob transactions are not supported by design
  tx_type: "eip7702"
  # Number of concurrent workers
  workers: 50
  # Number of transactions per batch
  batch_size: 100
  # Seed for reproducible fuzzing (empty string = random)
  seed: ""
  # Enable fuzzing mode
  fuzzing: true
  # Poll interval for gas price queries (empty string = use default)
  poll_interval: ""
  # A list of optional extra params that will be passed to rakoon
  extra_args: []

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
  # A list of locators for grafana dashboards to be loaded by the grafana service.
  # Each entry must be a Kurtosis locator: a GitHub locator (e.g.
  # "github.com/<org>/<repo>/path/to/dashboards") or an absolute http(s) URL.
  # When inheriting this package from your own, a local/relative path will NOT
  # work: upload_files runs inside the ethereum-package and resolves relative
  # paths against it, not against your package. Use a github.com/... locator
  # pointing at your own repo instead.
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

# Bootnodoor params
bootnodoor_params:
  # Bootnodoor docker image to use
  # Defaults to the latest image
  image: "ethpandaops/bootnodoor:latest"
  min_cpu: 100
  max_cpu: 1000
  min_mem: 128
  max_mem: 512
  # A list of optional extra args the bootnodoor container should spin up with
  extra_args: []

# Configuration place for zkboost - https://github.com/eth-act/zkboost
# The dashboard is automatically enabled when grafana is in additional_services.
zkboost_params:
  # zkboost docker image to use
  # Defaults to the latest image
  image: "ghcr.io/eth-act/zkboost/zkboost:latest"
  # List of zkboost instances, each running a separate zkboost container.
  # Each instance watches one EL participant for new blocks.
  #   name (required): Kurtosis service name, must be unique across instances
  #   el_participant_index (required): index of the EL participant to connect to (must not be el_type=None)
  # Defaults to a single instance named "zkboost" connected to the first EL participant.
  instances:
    - name: zkboost
      el_participant_index: 0
  # List of zkVM backend configurations.
  # If empty or not set, a mock reth-zisk zkvm is auto-configured with
  # random timing scaled to slot duration. Each entry must have a unique proof_type.
  #
  # Common fields for all entries:
  #   kind (required): the zkVM backend type
  #     "mock"     - in-process mock backend for testing, no real proving
  #     "ere"      - launches a GPU ere-server and connects to it
  #     "external" - connects to an already-deployed prover via HTTP
  #   proof_type (required): identifies the EL client + zkVM combination
  #     "ethrex-risc0", "ethrex-sp1", "ethrex-zisk", "reth-openvm", "reth-risc0", "reth-sp1", "reth-zisk"
  #   proof_timeout_secs: timeout for proof generation in seconds (default: 3/4 of slot duration, must be > 0)
  #
  # Mock-specific fields (only for kind: mock):
  #   mock_proving_time: controls simulated proving duration
  #     { kind: constant, ms: <ms> }                   - fixed duration (default: 2/3 of slot_duration_ms)
  #     { kind: random, min_ms: <min>, max_ms: <max> } - uniformly random (defaults: min=1/3, max=4/3 of slot)
  #     { kind: linear, ms_per_mgas: <ms> }            - proportional to block gas (default: 150 ms/Mgas)
  #   mock_proof_size: simulated proof size in bytes, must be >= 32 (default: 131072 / 128 KiB)
  #   mock_failure: whether to simulate proving failures (default: false)
  #
  # ere-specific fields (only for kind: ere):
  #   PREREQUISITE: Running an ere-server with GPU support requires the
  #   NVIDIA Container Toolkit to be installed on the Docker host.
  #   Install it by following the official guide:
  #   https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
  #   After installation, configure the Docker daemon (/etc/docker/daemon.json) with:
  #     "default-runtime": "nvidia"
  #   and restart Docker.
  #
  #   image (required): docker image for the ere-server
  #   program_url: URL to download the EVM program binary (or use program_path for a path
  #     already present in the image)
  #   port: port the ere-server listens on (default 3000)
  #   image: docker image for the ere-server (default: resolved from zkboost's
  #     pinned ere version in its Cargo.toml)
  #   elf_url: HTTPS URL of the guest ELF to prove. ere-server fetches it
  #     itself at startup. (default: resolved from zkboost's pinned ere-guests
  #     version).
  #   gpu: GPU configuration (default: no GPU)
  #     count: number of GPUs to allocate (default 0)
  #         NOTE: if more than one ere service uses gpu.count, Docker will assign
  #         the same GPU(s) to all of them. Use gpu.device_ids instead when running
  #         multiple GPU-enabled ere services.
  #     device_ids: list of specific GPU device IDs to pin to this service (default [])
  #         Use this to assign distinct GPUs across multiple ere services
  #         (e.g. ["0"] for the first service and ["1"] for the second).
  #     shm_size: shared memory size in MB (default 0)
  #     ulimits: ulimit overrides as a map (default {})
  #     driver: GPU driver to use (default "nvidia")
  #         Accepts a string shorthand or a per-backend dict:
  #         - string: used directly as the Docker DeviceRequest driver; Kubernetes resource
  #           name is derived as "<driver>.com/gpu"
  #           e.g. "nvidia" → Docker driver "nvidia", K8s resource "nvidia.com/gpu"
  #                "amd"    → Docker driver "amd",    K8s resource "amd.com/gpu"
  #         - dict: explicit per-backend override
  #           e.g. {docker: "amd", kubernetes: "amd.com/gpu"}
  #   env: extra environment variables as a map (default {})
  #
  # external-specific fields (only for kind: external):
  #   endpoint (required): full HTTP URL of the already-deployed prover
  #
  # example:
  # - kind: mock
  #   proof_type: ethrex-zisk
  #   mock_proving_time: { kind: constant, ms: 5000 }
  #   mock_proof_size: 1024
  # - kind: mock
  #   proof_type: reth-zisk
  #   mock_proving_time: { kind: random, min_ms: 2000, max_ms: 8000 }
  # - kind: mock
  #   proof_type: reth-sp1
  #   mock_proving_time: { kind: linear, ms_per_mgas: 150 }
  # - kind: ere
  #   proof_type: reth-zisk
  #   image: "ghcr.io/eth-act/ere/ere-server-zisk:latest"
  #   elf_url: "https://github.com/eth-act/ere-guests/releases/download/v0.8.0/stateless-validator-reth-zisk.elf"
  #   gpu:
  #     count: 1
  #     driver: "nvidia"
  # - kind: external
  #   proof_type: reth-zisk
  #   endpoint: "http://my-prover:3000"
  zkvms:
    - kind: mock
      proof_type: reth-zisk
      mock_proving_time: { kind: random, min_ms: 2000, max_ms: 8000 }
      mock_proof_size: 1024
  # RUST_LOG defaults to "info,zkboost=debug" if not set; other vars pass through unchanged.
  env:
    RUST_LOG: "info,zkboost=debug"

# Configuration place for tempo tracing backend
tempo_params:
  # Resource management for tempo container
  # CPU is milicores
  # RAM is in MB
  min_cpu: 10
  max_cpu: 1000
  min_mem: 128
  max_mem: 2048
  # Tempo docker image to use
  # Defaults to the latest image
  image: "grafana/tempo:latest"

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

  # Check block proposals
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

# Configuration for snooper - dumps all JSON-RPC requests and responses
# including BeaconAPI, EngineAPI and ExecutionAPI
snooper_params:
  # Enable snooper globally for all participants
  enabled: false
  # The image to use for snooper
  # Defaults to ethpandaops/rpc-snooper:latest
  image: ""
  # Extra arguments to pass to the snooper binary
  extra_args: []
  # Extra environment variables to set on the snooper container
  extra_env_vars: {}

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


# Configuration place for mempool bridge (https://github.com/ethpandaops/mempool-bridge)
mempool_bridge_params:
  # The image to use for mempool bridge
  image: ethpandaops/mempool-bridge:latest
  # The mode for mempool bridge operation
  # Valid values are "p2p" or "rpc"
  # Default: "p2p"
  mode: "p2p"
  # The source enodes to use for mempool bridge
  # Example:
  # P2P mode:
  # source_enodes:
  #   - enode://1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef@127.0.0.1:30303
  #   - enode://1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef@127.0.0.1:30304
  # RPC mode:
  # source_enodes:
  #   - http://127.0.0.1:8545
  #   - http://127.0.0.1:8546
  # Default: []
  source_enodes: []

  # The log level for mempool bridge
  # Valid values are "error", "warn", "info", "debug", and "trace"
  # If empty, will use the global_log_level value
  # Default: "" (uses global_log_level)
  log_level: ""

  # The number of concurrent goroutines to use when sending transactions to targets
  # Default: 10
  send_concurrency: 10

  # The interval in seconds for polling the source for new transactions
  # Default: "10s"
  polling_interval: "10s"

  # The retry interval duration for retrying failed operations
  # Default: "30s"
  retry_interval: "30s"

# Supports seven values
# Default: "null" - no mev boost, mev builder, mev flood or relays are spun up
# "mock" - mock-builder & mev-boost are spun up
# "flashbots" - mev-boost, relays, flooder and builder are all spun up, powered by [flashbots](https://github.com/flashbots)
# "mev-rs" - mev-boost, relays and builder are all spun up, powered by [mev-rs](https://github.com/ralexstokes/mev-rs/)
# "commit-boost" - mev-boost, relays and builder are all spun up, powered by [commit-boost](https://github.com/Commit-Boost/commit-boost-client)
# "helix" - helix relay, flashbots builder and mev-boost are spun up, powered by [helix](https://github.com/gattaca-com/helix)
#            Note: Helix uses TimescaleDB (PostgreSQL with time-series extension) for data storage
# "buildoor" - a self-contained builder+relay service & mev-boost are spun up, powered by [buildoor](https://github.com/ethpandaops/buildoor)
#              Supports both legacy builder API and ePBS bidding. No separate relay infrastructure or builder participant needed.
#              DEPRECATED: this single shared-builder mode will be dropped after the gloas fork. Use
#              `buildoor_params.instances` for dedicated per-participant builders instead.
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
  # Extra parameters to send to the CL builder
  mev_builder_cl_extra_params: []
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
  # Image to use for mock mev
  mock_mev_image: ethpandaops/rustic-builder:main
  # Whether to launch Adminer for the MEV relay PostgreSQL database
  launch_adminer: false
  # When true, launches both flashbots and helix relays
  # The reth-rbuilder will submit bids to both relays and mev-boost will query both relays for bids
  # Works with mev_type: flashbots
  run_multiple_relays: false
  # The image to use for helix relay (used when run_multiple_relays is true or mev_type is helix)
  helix_relay_image: ghcr.io/gattaca-com/helix-relay:main
  # Inline Commit-Boost config template. When set, replaces the default auto-generated
  # config. Template variables {{ .Timestamp }}, {{ .Network }}, {{ .Port }}, {{ .Relays }}
  # are rendered at enclave creation. Only used when mev_type is "commit-boost".
  # Example:
  #   commit_boost_config: |
  #     chain = { genesis_time_secs = {{ .Timestamp }}, path = "{{ .Network }}" }
  #     [pbs]
  #     host = "0.0.0.0"
  #     port = {{ .Port }}
  #     skip_sigverify = true
  #     {{ range $index, $relay := .Relays }}
  #     [[relays]]
  #     id = "mev_relay_{{$index}}"
  #     url = "{{ $relay }}"
  #     {{- end }}
  #     [logs.stdout]
  #     level = "debug"
  commit_boost_config: ""

# Parameters for the buildoor builder service.
# buildoor is an additional_service: add "buildoor" to additional_services to spin
# it up, then configure its targeting here. With "buildoor" enabled and no
# instances set, a single builder is wired to the first participant by default.
buildoor_params:
  # The image to use for buildoor
  image: ethpandaops/buildoor:main
  # Enable the legacy builder API (traditional block building via relay)
  builder_api: true
  # Enable ePBS bidding and revealing
  epbs_builder: true
  # Extra parameters to pass to the buildoor service
  extra_args: []
  # Enable buildoor's builder lifecycle: each builder deposits/onboards itself
  # after genesis (and tops itself up) via the EL, so builders work even when
  # gloas is not at genesis. Built blocks are tagged with the instance's service
  # name in their extra-data so they can be traced back to the builder.
  # Defaults to true
  lifecycle: true
  # Dedicated per-participant buildoor builders, configured independently of the
  # participants (a builder is independent of the network: it reads one
  # participant's CL payload_attributes stream and, under ePBS, gossips bids to
  # the whole network). Each entry spins up `count` buildoor builder instances
  # wired to the named participant's CL/EL. Services are named
  # `buildoor-<cl>-<el>-<participant>` (with a `-<n>` suffix when count > 1).
  # Requires "buildoor" in additional_services; no `mev_type` is needed, and it
  # cannot be combined with the (deprecated) network-wide `mev_type: buildoor`.
  # Each instance is its own builder; with lifecycle enabled (default) it onboards
  # itself after genesis, so genesis builder registration is not required and gloas
  # may activate at any epoch.
  # Each entry may set an optional `image` to override buildoor_params.image for
  # just that instance (A/B testing).
  # Defaults to [] (no per-participant buildoors).
  # Example:
  # instances:
  #   - participant: 1   # 1-based participant index
  #     count: 1
  #   - participant: 3
  #     count: 2
  #     image: ethpandaops/buildoor:my-fix   # per-instance override (optional)
  instances: []

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
    - single_attestation
    - block
    - block_gossip
    - chain_reorg
    - finalized_checkpoint
    - head
    - voluntary_exit
    - contribution_and_proof
    - blob_sidecar
    - data_column_sidecar
# Nginx params
# Nginx public port to port forward to local machine
# Defaults to 9090; only takes effect when the nginx additional service is enabled
nginx_port: 9090

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
# Default to false
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

# Configuration place for disruptoor - https://github.com/ethpandaops/disruptoor
# Disruptoor is Docker-only and requires running Kurtosis with privileged mode enabled.
disruptoor_params:
  # The image to use for disruptoor
  image: ethpandaops/disruptoor:latest
  # Resource management for disruptoor
  # CPU is milicores
  # RAM is in MB
  min_cpu: 100
  max_cpu: 1000
  min_mem: 128
  max_mem: 512
  # Log level for disruptoor (error, warn, info, debug)
  log_level: info
  # Log format for disruptoor (json or text)
  log_format: json
  # Optional partitions applied at startup. Leave empty to use the HTTP API only.
  # participants are ethereum-package participant/node indexes; components can be el, cl, vc, or all.
  # Example:
  # partitions:
  #   - name: three-way-split
  #     groups:
  #       - participants: [1, 2]
  #       - participants: [3, 4]
  #       - participants: [5, 6]
  #     components: [el, cl]
  partitions: []
  # Optional traffic shaping applied at startup.
  # include_control must be true because disruptoor shaping requires explicit control traffic acknowledgement.
  # Example:
  # shaping:
  #   - name: jitter-node-1
  #     participants: [1]
  #     components: [el, cl]
  #     delay: 50ms
  #     jitter: 10ms
  #     include_control: true
  shaping: []
  # Optional native disruptoor state applied at startup.
  # Cannot be used together with partitions or shaping.
  # Selectors use ethereum-package labels without the full Kurtosis prefix.
  config: {}
  # A list of optional params that will be passed to disruptoor
  extra_args: []

# Configuration place for slashoor - https://github.com/ethpandaops/slashoor
# Slashoor is a lazy slasher that monitors validators for slashing violations
# and automatically submits attester slashings to the beacon chain
slashoor_params:
  # The image to use for slashoor
  image: ethpandaops/slashoor:latest
  # Resource management for slashoor
  # CPU is milicores
  # RAM is in MB
  min_cpu: 100
  max_cpu: 1000
  min_mem: 128
  max_mem: 512
  # Log level for slashoor (error, warn, info, debug, trace)
  log_level: info
  # Timeout for beacon API requests
  beacon_timeout: 30s
  # Maximum epochs to keep in memory for slashing detection
  max_epochs_to_keep: 54000
  # Number of slots to backfill on startup
  backfill_slots: 64
  # Enable the detector service
  detector_enabled: true
  # Enable the proposer slashing service
  proposer_enabled: true
  # Enable the submitter service
  submitter_enabled: true
  # Run in dry-run mode (detect but don't submit slashings)
  submitter_dry_run: false
  # Enable dora as a slashing database source
  dora_enabled: true
  # Custom dora URL (auto-detected if dora is in additional_services or on public networks)
  dora_url: ""
  # Scan dora on startup for existing slashings
  dora_scan_on_startup: true
  # A list of optional extra args
  extra_args: []

# Ethereum genesis generator params
ethereum_genesis_generator_params:
  # The image to use for ethereum genesis generator
  image: ethpandaops/ethereum-genesis-generator:6.1.3
  # Pass custom environment variables to the genesis generator (e.g. MY_VAR: my_value)
  extra_env: {}

# Configuration for public ports and NAT exit IP addresses
port_publisher:
  # Global NAT exit IP address for all services (optional)
  # If set, this will be used for all service groups (overrides individual nat_exit_ip settings)
  # Set to "auto" to automatically detect public IP from ident.me
  # Defaults to KURTOSIS_IP_ADDR_PLACEHOLDER (uses per-service settings)
  nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER

  # Execution Layer public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 32000
  # You can't run multiple enclaves on the same port settings
  el:
    enabled: false
    public_port_start: 32000
    # nat_exit_ip: IP address to expose for EL P2P networking (optional)
    # Only used if global nat_exit_ip is not set
    # Set to "auto" to automatically detect public IP from ident.me
    # Defaults to KURTOSIS_IP_ADDR_PLACEHOLDER (container IP)
    nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER

  # Consensus Layer public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 33000
  # You can't run multiple enclaves on the same port settings
  cl:
    enabled: false
    public_port_start: 33000
    # nat_exit_ip: IP address to expose for CL P2P networking (optional)
    # Only used if global nat_exit_ip is not set
    # Set to "auto" to automatically detect public IP from ident.me
    # Defaults to KURTOSIS_IP_ADDR_PLACEHOLDER (container IP)
    nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER

  # Validator client public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 34000
  # You can't run multiple enclaves on the same port settings
  vc:
    enabled: false
    public_port_start: 34000
    # nat_exit_ip: IP address to expose for VC networking (optional)
    # Only used if global nat_exit_ip is not set
    # Set to "auto" to automatically detect public IP from ident.me
    # Defaults to KURTOSIS_IP_ADDR_PLACEHOLDER (container IP)
    nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER

  # remote signer public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 35000
  # You can't run multiple enclaves on the same port settings
  remote_signer:
    enabled: false
    public_port_start: 35000
    # nat_exit_ip: IP address to expose for remote signer networking (optional)
    # Only used if global nat_exit_ip is not set
    # Set to "auto" to automatically detect public IP from ident.me
    # Defaults to KURTOSIS_IP_ADDR_PLACEHOLDER (container IP)
    nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER

  # Additional services public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 36000
  # You can't run multiple enclaves on the same port settings
  additional_services:
    enabled: false
    public_port_start: 36000
    # nat_exit_ip: IP address to expose for additional services (optional)
    # Only used if global nat_exit_ip is not set
    # Set to "auto" to automatically detect public IP from ident.me
    # Defaults to KURTOSIS_IP_ADDR_PLACEHOLDER (container IP)
    nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER

  # MEV public port exposed to your local machine
  # Disabled by default
  # Public port start defaults to 37000
  # You can't run multiple enclaves on the same port settings
  mev:
    enabled: false
    public_port_start: 37000
    # nat_exit_ip: IP address to expose for MEV services (optional)
    # Only used if global nat_exit_ip is not set
    # Set to "auto" to automatically detect public IP from ident.me
    # Defaults to KURTOSIS_IP_ADDR_PLACEHOLDER (container IP)
    nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER

  # Other public port exposed to your local machine (like ethereum metrics exporter, snooper)
  # Disabled by default
  # Public port start defaults to 38000
  # You can't run multiple enclaves on the same port settings
  other:
    enabled: false
    public_port_start: 38000
    # nat_exit_ip: IP address to expose for other services (optional)
    # Only used if global nat_exit_ip is not set
    # Set to "auto" to automatically detect public IP from ident.me
    # Defaults to KURTOSIS_IP_ADDR_PLACEHOLDER (container IP)
    nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER
```

### Example configurations

<details>
    <summary>Port Publisher Configuration Examples</summary>

**Global NAT Exit IP (Backward Compatible)**

```yaml
port_publisher:
  nat_exit_ip: "auto"  # All services use auto-detected public IP
  el:
    enabled: true
    public_port_start: 32000
  cl:
    enabled: true
    public_port_start: 33000
  additional_services:
    enabled: true
    public_port_start: 36000
```

**Per-Service NAT Exit IP (Granular Control)**

```yaml
port_publisher:
  nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER  # Not set globally
  el:
    enabled: true
    public_port_start: 32000
    nat_exit_ip: "auto"  # Only EL uses public IP
  cl:
    enabled: true
    public_port_start: 33000
    nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER  # CL uses container IP
  additional_services:
    enabled: true
    public_port_start: 36000
    nat_exit_ip: "192.168.1.100"  # Custom IP for additional services
```

**Mixed Configuration**

```yaml
port_publisher:
  nat_exit_ip: KURTOSIS_IP_ADDR_PLACEHOLDER  # Not set globally
  el:
    enabled: true
    public_port_start: 32000
    nat_exit_ip: "auto"  # Auto-detect for EL
  cl:
    enabled: true
    public_port_start: 33000
    nat_exit_ip: "auto"  # Auto-detect for CL
  additional_services:
    enabled: true
    public_port_start: 36000
    # Uses default KURTOSIS_IP_ADDR_PLACEHOLDER for additional services
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
    <summary>A 2-node Ethereum network with dedicated per-participant buildoor builders</summary>

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
  - el_type: reth
    cl_type: prysm
buildoor_params:
  builder_api: true
  epbs_builder: true
  # one buildoor wired to participant 1, two wired to participant 2
  instances:
    - participant: 1
      count: 1
    - participant: 2
      count: 2
additional_services:
  - buildoor
  - dora
  - spamoor
```

</details>

<details>
    <summary>A 2-node Ethereum network with the (deprecated) shared buildoor builder</summary>

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
    count: 2
# Deprecated: prefer buildoor_params.instances (see example above).
mev_type: buildoor
network_params:
  builder_count: 1
  gloas_fork_epoch: 0
buildoor_params:
  builder_api: true
  epbs_builder: true
additional_services:
  - dora
  - spamoor
```

</details>

<details>
    <summary>A 3-node Ethereum network with Helix relay for MEV-boost infrastructure</summary>

```yaml
participants:
  - el_type: geth
    el_image: ethpandaops/geth:master
    cl_type: lighthouse
    cl_image: ethpandaops/lighthouse:unstable
    count: 2
  - el_type: nethermind
    el_image: ethpandaops/nethermind:master
    cl_type: prysm
    cl_image: ethpandaops/prysm-beacon-chain:develop

mev_type: helix
mev_params:
  mev_relay_image: ghcr.io/gattaca-com/helix-relay:main
  mev_builder_image: ethpandaops/reth-rbuilder:develop
  mev_boost_image: ethpandaops/mev-boost:develop
  mev_builder_cl_image: ethpandaops/lighthouse:unstable
  mev_builder_subsidy: 1

additional_services:
  - dora
  - spamoor

network_params:
  min_validator_withdrawability_delay: 1
  shard_committee_period: 1
```

</details>

<details>
    <summary>A 2-node geth/lighthouse network with optional services (Grafana, Prometheus, tx_fuzz, EngineAPI snooper)</summary>

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
    count: 2
snooper_params:
  enabled: true
additional_services:
  - prometheus
  - grafana
  - tx_fuzz
ethereum_metrics_exporter_enabled: true
```

</details>

<details>
    <summary>Network with rakoon transaction fuzzer</summary>

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
  - el_type: reth
    cl_type: teku
additional_services:
  - rakoon
rakoon_params:
  tx_type: "eip7702"
  workers: 50
  batch_size: 100
```

For advanced fuzzing with broadcaster:

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
  - el_type: reth
    cl_type: teku
additional_services:
  - broadcaster  # Broadcasts to all nodes
  - rakoon
rakoon_params:
  tx_type: "eip1559"
  workers: 100
  batch_size: 200
  seed: "12345"  # Reproducible fuzzing
```

</details>

## Extra Files and Mounts

The `extra_files` feature allows you to define custom file contents in your configuration and mount them into any container (EL, CL, or VC).

### How It Works

1. **Define file contents** in the top-level `extra_files` section
2. **Mount the files** into containers using `el_extra_mounts`, `cl_extra_mounts`, or `vc_extra_mounts`
3. **Access the files** inside the container at `<mount_path>/<file_name>`

### Important: Understanding Mount Paths

Due to how Kurtosis handles artifacts, mount paths become **directories**, not files. When you mount a file:

- The mount path you specify becomes a directory
- Your file is placed inside that directory with its original name from `extra_files`

### Complete Example

```yaml
# Define your custom files at the top level
extra_files:
  validator_config.json: |
    {
      "graffiti": "MyValidator",
      "enable_doppelganger": true,
      "suggested_fee_recipient": "0x1234..."
    }

participants:
  - el_type: geth
    cl_type: lighthouse

    # Mount files into the consensus layer client
    cl_extra_mounts:
      "/configs": "validator_config.json" # File available at: /configs/validator_config.json
```

## Beacon Node <> Validator Client compatibility

|               | Lighthouse VC | Prysm VC | Teku VC | Lodestar VC | Nimbus VC
|---------------|---------------|----------|---------|-------------|-----------|
| Lighthouse BN | ✅            | ✅       | ✅      | ✅          | ✅
| Prysm BN      | ✅            | ✅       | ✅      | ✅          | ✅
| Teku BN       | ✅            | ✅       | ✅      | ✅          | ✅
| Lodestar BN   | ✅            | ✅       | ✅      | ✅          | ✅
| Nimbus BN     | ✅            | ✅       | ✅      | ✅          | ✅
| Grandine BN   | ✅            | ✅       | ✅      | ✅          | ✅

## Custom labels for Docker and Kubernetes

There are 6 custom labels that can be used to identify the nodes in the network. These labels are used to identify the nodes in the network and can be used to run chaos tests on specific nodes. An example for these labels are as follows:

Execution Layer (EL) nodes:

```sh
  "kurtosistech.com.custom/ethereum-package.client": "geth",
  "kurtosistech.com.custom/ethereum-package.client-image": "ethereum-client-go-latest",
  "kurtosistech.com.custom/ethereum-package.client-language:": "go",
  "kurtosistech.com.custom/ethereum-package.client-type": "execution",
  "kurtosistech.com.custom/ethereum-package.connected-client": "lighthouse",
  "kurtosistech.com.custom/ethereum-package.node-index": "1",
```

Consensus Layer (CL) nodes - Beacon:

```sh
  "kurtosistech.com.custom/ethereum-package.client": "lighthouse",
  "kurtosistech.com.custom/ethereum-package.client-image": "sigp-lighthouse-latest",
  "kurtosistech.com.custom/ethereum-package.client-language:": "rust",
  "kurtosistech.com.custom/ethereum-package.client-type": "beacon",
  "kurtosistech.com.custom/ethereum-package.connected-client": "geth",
  "kurtosistech.com.custom/ethereum-package.node-index": "1",
```

Consensus Layer (CL) nodes - Validator:

```sh
  "kurtosistech.com.custom/ethereum-package.client": "lighthouse",
  "kurtosistech.com.custom/ethereum-package.client-image": "sigp-lighthouse-latest",
  "kurtosistech.com.custom/ethereum-package.client-language:": "rust",
  "kurtosistech.com.custom/ethereum-package.client-type": "validator",
  "kurtosistech.com.custom/ethereum-package.connected-client": "geth",
  "kurtosistech.com.custom/ethereum-package.node-index": "1",
```

- `ethereum-package.client` describes which client is running on the node.
- `ethereum-package.client-image` describes the image that is used for the client.
- `ethereum-package.client-type` describes the type of client that is running on the node (`execution`,`beacon` or `validator`).
- `ethereum-package.connected-client` describes the CL/EL client that is connected to the EL/CL client.
- `ethereum-package.client-language` describes the implementation language of the running service.
- `ethereum-package.node-index` describes the index of the node (participant) that the service belongs to.

## Proposer Builder Separation (PBS) emulation

To spin up the network of Ethereum nodes with an external block building network (using Flashbot's `mev-boost` protocol), simply use:

```bash
kurtosis run github.com/ethpandaops/ethereum-package '{"mev_type": "flashbots"}'
```

Starting your network up with `"mev_type": "flashbots"` will instantiate and connect the following infrastructure to your network:

1. `Flashbot's block builder & CL validator + beacon` - A modified Geth client that builds blocks. The CL validator and beacon clients are lighthouse clients configured to receive payloads from the relay.
2. `mev-relay-api` - Services that provide APIs for (a) proposers, (b) block builders, (c) data
3. `mev-relay-website` - A website to monitor payloads that have been delivered
4. `mev-relay-housekeeper` - Updates known validators, proposer duties, and more in the background. Only a single instance of this should run.
5. `mev-boost` - open-source middleware instantiated for each EL/Cl pair in the network, including the builder

The package also supports other MEV implementations:

- `"mev_type": "helix"` - Uses the high-performance [Helix relay](https://github.com/gattaca-com/helix) with TimescaleDB backend for data storage
- `"mev_type": "mev-rs"` - Alternative relay implementation powered by [mev-rs](https://github.com/ralexstokes/mev-rs/)
- `"mev_type": "commit-boost"` - Infrastructure powered by [commit-boost](https://github.com/Commit-Boost/commit-boost-client)
- `"mev_type": "buildoor"` - A self-contained builder+relay service powered by [buildoor](https://github.com/ethpandaops/buildoor). Supports both legacy builder API and ePBS bidding without requiring separate relay infrastructure or a dedicated builder participant. **Deprecated:** this single shared-builder mode will be dropped after the gloas fork - use `buildoor_params.instances` for dedicated per-participant builders instead.

Each implementation provides different features and performance characteristics suitable for various testing and development scenarios.

<details>
    <summary>Caveats when using "mev_type": "flashbots"</summary>

- Validators (64 per node by default, so 128 in the example in this guide) will get registered with the relay automatically after the 1st epoch. This registration process is simply a configuration addition to the mev-boost config - which Kurtosis will automatically take care of as part of the set up. This means that the mev-relay infrastructure only becomes aware of the existence of the validators after the 1st epoch.
- After the 3rd epoch, the mev-relay service will begin to receive execution payloads (eth_sendPayload, which does not contain transaction content) from the mev-builder service (or mock-builder in mock-mev mode).
- Validators will start to receive validated execution payload headers from the mev-relay service (via mev-boost) after the 4th epoch. The validator selects the most valuable header, signs the payload, and returns the signed header to the relay - effectively proposing the payload of transactions to be included in the soon-to-be-proposed block. Once the relay verifies the block proposer's signature, the relay will respond with the full execution payload body (incl. the transaction contents) for the validator to use when proposing a SignedBeaconBlock to the network.

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
| 3             | tx_fuzz | ✅                |                 | To spam transactions with  |
| 8             | assertoor           | ✅                | ✅              | As the funding for tests   |
| 11            | mev_custom_flood    | ✅                |                 | As the sender of balance   |
| 12            | l2_contracts        | ✅                |                 | Contract deployer address  |
| 13            | spamoor             | ✅                |                 | Spams transactions         |
| 14            | rakoon              | ✅                |                 | Protocol fuzzing           |

## Developing On This Package

First, install prerequisites:

1. [Install Kurtosis itself][kurtosis-cli-installation]

Then, run the dev loop:

1. Make your code changes
1. **Run the linter to format and check your code:**

   ```bash
   kurtosis lint --format
   ```

   This ensures your Starlark code follows the project's formatting standards and catches any syntax issues.

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
   - `parithosh` (Ethereum Foundation)
   - `barnabasbusa` (Ethereum Foundation)
   - `pk910` (Ethereum Foundation)
   - `samcm` (Ethereum Foundation)
   - `h4ck3rk3y` (Kurtosis)
   - `mieubrisse` (Kurtosis)
   - `leederek` (Kurtosis)
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

## AI Agent Skill (Claude Code & Codex)

This repository ships with an AI agent skill called `kurtosis-ethereum` that lets AI coding agents spin up and manage Ethereum devnets. The skill is automatically discovered by both [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [OpenAI Codex](https://developers.openai.com/codex/skills/) when working in this repo.

The canonical skill lives at `.claude/skills/kurtosis-ethereum/` with a symlink at `.agents/skills/kurtosis-ethereum/` for Codex compatibility. The same `SKILL.md` works for both agents.

### Installation

**Claude Code:**

Clone the repo and copy the skill to your personal Claude skills folder:

```bash
git clone https://github.com/ethpandaops/ethereum-package.git
cp -r ethereum-package/.claude/skills/kurtosis-ethereum ~/.claude/skills/
```

Claude Code auto-discovers skills in `~/.claude/skills/`. Once copied, invoke with `/kurtosis-ethereum`.

**Codex:** The skill is auto-discovered from `.agents/skills/` when working in this repo. No extra installation needed.

### Usage

Once available, invoke the skill with a natural language prompt:

```
# Claude Code
/kurtosis-ethereum spin up a 4-node devnet with geth+lighthouse and reth+prysm with assertoor stability checks

# Codex — the skill is invoked implicitly or via /skills
spin up a 4-node devnet with geth+lighthouse and reth+prysm with assertoor stability checks
```

The skill provides:
- Configuration generation for multi-client devnets
- A reference tool (`kurtosis-ref.sh`) for looking up supported clients, parameters, fork epochs, MEV options, and CI test examples
- Templates for common setups (mixed clients, custom images, observer nodes, MEV infrastructure)

<!------------------------ Only links below here -------------------------------->

[docker-installation]: https://docs.docker.com/get-docker/
[kurtosis-cli-installation]: https://docs.kurtosis.com/install
[kurtosis-repo]: https://github.com/kurtosis-tech/kurtosis
[enclave]: https://docs.kurtosis.com/advanced-concepts/enclaves/
[package-reference]: https://docs.kurtosis.com/advanced-concepts/packages
