FROM e2bdev/code-interpreter:latest

ARG EL_CLIENT_URL=https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.17.4-36a7dc72.tar.gz
ARG EL_CLIENT_SHA256=9113657e52d41879b8feaca8a4163d325ccce5b038aea59775a0bb3b26d2100a
ARG CL_CLIENT_URL=https://github.com/sigp/lighthouse/releases/download/v8.2.1/lighthouse-v8.2.1-x86_64-unknown-linux-gnu.tar.gz
ARG CL_CLIENT_SHA256=51754fc07e337a2ccbc9afa0037e268d4cf1b19fb69e9b2a272b5dd44a401496

USER root
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL "$EL_CLIENT_URL" -o /tmp/geth.tar.gz \
 && echo "$EL_CLIENT_SHA256  /tmp/geth.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/geth.tar.gz -C /tmp \
 && install -m 0755 /tmp/geth-linux-amd64-1.17.4-36a7dc72/geth /usr/local/bin/geth \
 && curl -fsSL "$CL_CLIENT_URL" -o /tmp/lighthouse.tar.gz \
 && echo "$CL_CLIENT_SHA256  /tmp/lighthouse.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/lighthouse.tar.gz -C /usr/local/bin lighthouse \
 && rm -rf /tmp/geth* /tmp/lighthouse.tar.gz \
 && mkdir -p /home/user/ethereum/geth /home/user/ethereum/lighthouse \
 && chown -R user:user /home/user/ethereum \
 && geth version \
 && lighthouse --version

USER user
WORKDIR /home/user
