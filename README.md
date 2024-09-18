## How to run the private network.
[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/new/?editor=code#https://github.com/ethpandaops/ethereum-package)
1. [Install Docker & start the Docker Daemon if you haven't done so already][docker-installation]
2. [Install the Kurtosis CLI, or upgrade it to the latest version if it's already installed][kurtosis-cli-installation]
3. Run the package with default configurations from the command line:
```bash
kurtosis run --enclave interstate-devnet ./ --args-file network_params.yaml
```