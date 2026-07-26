FROM e2bdev/code-interpreter@sha256:442ec598ec8ca4ed01b5bb24ad6e4f2e6ac80fd88f1564ff9a01e82da18e1e3b
ARG CRANE_URL=https://github.com/google/go-containerregistry/releases/download/v0.20.6/go-containerregistry_Linux_x86_64.tar.gz
ARG CRANE_SHA256=c1d593d01551f2c9a3df5ca0a0be4385a839bd9b86d4a76e18d7b17d16559127
ARG GENESIS_GENERATOR_IMAGE=ethpandaops/ethereum-genesis-generator@sha256:e6c136de21d1502cacf14a56b4e47e82a8774ff7cec3de993439440a96a74cfd

ARG EL_CLIENT_URL=https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.17.4-36a7dc72.tar.gz
ARG EL_CLIENT_SHA256=9113657e52d41879b8feaca8a4163d325ccce5b038aea59775a0bb3b26d2100a
ARG CL_CLIENT_URL=https://github.com/sigp/lighthouse/releases/download/v8.2.1/lighthouse-v8.2.1-x86_64-unknown-linux-gnu.tar.gz
ARG CL_CLIENT_SHA256=51754fc07e337a2ccbc9afa0037e268d4cf1b19fb69e9b2a272b5dd44a401496
ARG PRYSM_URL=https://github.com/OffchainLabs/prysm/releases/download/v7.1.7/beacon-chain-v7.1.7-linux-amd64
ARG PRYSM_SHA256=a30973627c52516c2fb044469875f99e53fa00bf4cfa2c2f71b655f2df6cf7e4
ARG PRYSM_VALIDATOR_URL=https://github.com/OffchainLabs/prysm/releases/download/v7.1.7/validator-v7.1.7-linux-amd64
ARG PRYSM_VALIDATOR_SHA256=1c080dfb141fa7fee74c588c3158aa74682a860bf2dc9974f65994b1df6649f2

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      bc ca-certificates curl gettext-base jq openssl wget yq \
 && rm -rf /var/lib/apt/lists/* \
 && download_verified() { curl -fsSL --connect-timeout 15 --max-time 600 --retry 5 --retry-all-errors --retry-delay 2 "$1" -o "$3" && echo "$2  $3" | sha256sum -c -; } \
 && download_verified "$CRANE_URL" "$CRANE_SHA256" /tmp/crane.tar.gz \
 && mkdir -p /tmp/crane /tmp/genesis-root /work \
 && tar -xzf /tmp/crane.tar.gz -C /tmp/crane crane \
 && timeout 600 /tmp/crane/crane export "$GENESIS_GENERATOR_IMAGE" /tmp/genesis-root.tar \
 && tar -xf /tmp/genesis-root.tar -C /tmp/genesis-root \
 && cp -a /tmp/genesis-root/apps /apps \
 && cp -a /tmp/genesis-root/config /config \
 && cp -a /tmp/genesis-root/defaults /defaults \
 && cp -a /tmp/genesis-root/work/entrypoint.sh /work/entrypoint.sh \
 && install -m 0755 /tmp/genesis-root/usr/local/bin/eth-genesis-state-generator /usr/local/bin/eth-genesis-state-generator \
 && install -m 0755 /tmp/genesis-root/usr/local/bin/eth2-val-tools /usr/local/bin/eth2-val-tools \
 && install -m 0755 /tmp/genesis-root/usr/local/bin/geth-hdwallet /usr/local/bin/geth-hdwallet \
 && rm -rf /tmp/crane /tmp/crane.tar.gz /tmp/genesis-root /tmp/genesis-root.tar \
 && download_verified "$EL_CLIENT_URL" "$EL_CLIENT_SHA256" /tmp/geth.tar.gz \
 && tar -xzf /tmp/geth.tar.gz -C /tmp \
 && install -m 0755 /tmp/geth-linux-amd64-1.17.4-36a7dc72/geth /usr/local/bin/geth \
 && download_verified "$CL_CLIENT_URL" "$CL_CLIENT_SHA256" /tmp/lighthouse.tar.gz \
 && tar -xzf /tmp/lighthouse.tar.gz -C /usr/local/bin lighthouse \
 && download_verified "$PRYSM_URL" "$PRYSM_SHA256" /tmp/beacon-chain \
 && install -m 0755 /tmp/beacon-chain /usr/local/bin/beacon-chain \
 && download_verified "$PRYSM_VALIDATOR_URL" "$PRYSM_VALIDATOR_SHA256" /tmp/validator \
 && install -m 0755 /tmp/validator /usr/local/bin/validator \
 && rm -rf /tmp/geth* /tmp/lighthouse.tar.gz /tmp/beacon-chain /tmp/validator \
 && mkdir -p /home/user/ethereum/geth /home/user/ethereum/lighthouse /home/user/ethereum/prysm /data /work \
 && chown -R user:user /home/user/ethereum \
 && geth version \
 && lighthouse --version \
 && beacon-chain --version

RUN chown -R user:user /config /data /home/user /work \
 && validator --version \
 && eth2-val-tools --help >/dev/null

USER user
WORKDIR /home/user
