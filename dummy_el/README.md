# Using Dummy EL

This is a dummy EL that can be used with zk attester nodes. These nodes do not require an EL to function since they verify zkEVM proofs that attest to the validity of the execution payload.

## Quick Start

### 1. Build the Docker Image

From the ethereum-package repository root:

```bash
docker build -f dummy_el/Dockerfile -t dummy_el:local .
```

### 2. Adding to Kurtosis

In Kurtosis, you can add the following:

```yaml
  - el_type: dummy
    el_image: dummy_el:local
```
