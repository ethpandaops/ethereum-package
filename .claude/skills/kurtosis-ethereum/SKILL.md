---
name: kurtosis-ethereum
description: Run Ethereum multi-client devnets using Kurtosis and the ethpandaops/ethereum-package. Use for spinning up local devnets, syncing public testnets, validating cross-client interop, testing fork transitions, shadowforks, running assertoor checks, debugging CL/EL client interactions, or verifying new feature implementations across multiple consensus and execution clients.
allowed-tools: Bash, Read, Write, Edit, WebFetch, Glob, Grep
---

# Kurtosis Devnet

Run Ethereum consensus/execution client devnets via [kurtosis](https://github.com/kurtosis-tech/kurtosis) + [ethereum-package](https://github.com/ethpandaops/ethereum-package).

## Config Principle

**Only include fields that differ from defaults.** If the task doesn't mention a setting, don't include it. Shorter configs are better — let the defaults handle the rest.

## Quick Start

```bash
# ALWAYS start grafloki first — enables Loki log collection for debugging
kurtosis grafloki start

# Write a network_params.yaml, then:
kurtosis run github.com/ethpandaops/ethereum-package \
  --enclave <name> \
  --args-file network_params.yaml \
  --image-download always

kurtosis enclave ls                    # list enclaves
kurtosis enclave inspect <name>        # inspect services + ports
kurtosis service logs <enclave> <svc>  # view logs
kurtosis enclave rm -f <name>          # cleanup
```

**If you are told to use a fork or a branch of the ethereum-package, then replace github.com/ethpandaops/ethereum-package with github.com/<fork>/ethereum-package@branch**

**If you want to quickly sanity check something, then use preset: "minimal". This will lead to much faster networks, but do not default to this approach. Only use it when you are sure you want to quickly check something. When the user expects it to behave like mainnet, then use preset: "mainnet".**

## Config Structure (`network_params.yaml`)

### `participants`

Each entry is a CL+EL node. Only specify fields you need to override:

```yaml
participants:
  - el_type: geth           # geth, reth, nethermind, besu, erigon
    cl_type: lighthouse      # lighthouse, lodestar, prysm, teku, nimbus
```

Available overrides (only use when needed):
- `el_image` / `cl_image` / `vc_image` — custom Docker images
- `el_extra_params` / `cl_extra_params` / `vc_extra_params` — extra CLI flags
- `el_max_cpu` / `el_max_mem` / `cl_max_cpu` / `cl_max_mem` — resource limits (millicores / MB)
- `vc_type` — separate validator client type (creates a dedicated vc service)
- `use_remote_signer: true` + `remote_signer_type: web3signer` — remote signing
- `count` — number of identical instances (default: 1)
- `validator_count` — validators assigned (default: from network config)

### `network_params`

Network-level settings. Only include fields you need to change. Use `kurtosis-ref.sh search <term>` to find exact field names — do not guess.

```yaml
network_params:
  # Only add fields the task requires. Examples of available settings:
  # preset, seconds_per_slot, fork epochs, gas limits, etc.
  # Verify field names with: bash .claude/skills/kurtosis-ethereum/kurtosis-ref.sh search <term>
```

### `additional_services`

```yaml
additional_services:
  - dora                     # block explorer
  - assertoor                # automated testing
```

## Reference Tool

One script for all lookups. Use targeted sections instead of `all`.

```bash
bash .claude/skills/kurtosis-ethereum/kurtosis-ref.sh <section>
```

| Section | What it shows |
|---------|--------------|
| `clients` | Supported EL/CL/VC client types |
| `participants` | Participant fields with defaults |
| `network` | network_params fields with defaults |
| `forks` | Fork epoch fields and defaults |
| `mev` | MEV types and params |
| `services` | Additional services list |
| `sections` | Config subcategory and root-level params |
| `search <term>` | Search the README for a field/concept |
| `example <name>` | Fetch a real CI test config (e.g. `remote-signer`, `minimal`, `mix`) |
| `examples` | List all available CI test configs |

Use targeted sections instead of dumping everything. For example:
- Need to know MEV options? `kurtosis-ref.sh mev`
- Unsure about a field name? `kurtosis-ref.sh search gas_limit`
- Need fork epoch names? `kurtosis-ref.sh forks`
- Setting up something complex? `kurtosis-ref.sh example remote-signer` to see a working CI config

## Service Naming Convention

- EL: `el-{index}-{el_type}-{cl_type}`
- CL: `cl-{index}-{cl_type}-{el_type}`
- VC: `vc-{index}-{el_type}-{cl_type}-{vc_type}` (only when vc_type differs from cl_type)

## Examples

### 2-node devnet

```yaml
participants:
  - el_type: geth
    cl_type: lodestar
  - el_type: reth
    cl_type: lighthouse

network_params:
  preset: minimal
```

### Mixed clients with monitoring

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
  - el_type: nethermind
    cl_type: prysm
  - el_type: besu
    cl_type: teku

network_params:
  preset: minimal

additional_services:
  - dora
  - assertoor

assertoor_params:
  run_stability_check: true
```

### Custom images

```yaml
participants:
  - el_type: geth
    el_image: ethpandaops/geth:my-branch
    cl_type: lighthouse
    cl_image: ethpandaops/lighthouse:my-branch

network_params:
  preset: minimal
```

### Observer node (no validators)

```yaml
participants:
  - el_type: geth
    cl_type: lighthouse
    validator_count: 0

network_params:
  preset: minimal
```

## Monitoring

```bash
# Check finality
curl -s http://127.0.0.1:<cl-port>/eth/v1/beacon/states/head/finality_checkpoints | jq

# Check peers
curl -s http://127.0.0.1:<cl-port>/eth/v1/node/peers | jq '.data | length'
```

Finality requires ~6-8 min after genesis with default settings (32 slots/epoch, 12s/slot).

## Troubleshooting

| Issue | Fix                                                            |
|-------|----------------------------------------------------------------|
| Image not found | Verify image exists in registry; use `--image-download always` |
| Port conflicts | May be conflicting enclaves, ask user how to proceed           |
