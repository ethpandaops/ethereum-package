# Ethereum Package

A Kurtosis package for orchestrating multi-client Ethereum network deployments, supporting private testnets, public networks, shadowforks, and comprehensive testing infrastructure.

## Project Structure
Claude MUST read the `.cursor/rules/project_architecture.mdc` file before making any structural changes to the project.

## Code Standards  
Claude MUST read the `.cursor/rules/code_standards.mdc` file before writing any code in this project.

## Development Workflow
Claude MUST read the `.cursor/rules/development_workflow.mdc` file before making changes to build, test, or deployment configurations.

## Component Documentation
Individual components have their own CLAUDE.md files with component-specific rules. Always check for and read component-level documentation when working on specific parts of the codebase.

## Key Capabilities
- Multi-client support for both execution (Geth, Nethermind, Besu, Erigon, Reth) and consensus layers (Lighthouse, Teku, Nimbus, Prysm, Lodestar, Grandine)
- MEV infrastructure integration (mev-boost, builders, relays)
- Comprehensive monitoring and observability (Prometheus, Grafana)
- Testing tools (Assertoor, tx-fuzz, spamoor)
- Block explorers and analysis tools (Dora, Blockscout, Blobscan)
- Support for various network types including shadowforks and ephemery

## Quick Start
```bash
# Run with default configuration
kurtosis run github.com/ethpandaops/ethereum-package

# Run with custom parameters
kurtosis run . --args-file network_params.yaml
```

## Important Notes
- All orchestration logic is written in Starlark (.star files)
- Configuration templates are stored in static_files/
- Each service runs in isolated containers managed by Kurtosis
- Resource limits and network parameters are highly configurable