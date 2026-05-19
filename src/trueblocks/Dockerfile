# Builds chifra from trueblocks-core source.

ARG TRUEBLOCKS_VERSION

# --- builder ---------------------------------------------------------------
FROM golang:1.25.1-bookworm AS builder

ARG TRUEBLOCKS_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        cmake \
        g++ \
        gcc \
        git \
        libcurl4-openssl-dev \
        make \
        python3 \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${TRUEBLOCKS_VERSION}" --recurse-submodules \
        https://github.com/TrueBlocks/trueblocks-core.git /src

WORKDIR /src
RUN scripts/go-work-sync.sh
RUN mkdir build && cd build && cmake ../src && make -j"$(nproc)"

# --- runtime ---------------------------------------------------------------
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libcurl4 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/bin/chifra /usr/local/bin/chifra

# Ship chifra's per-chain config bundle for known public networks.
# The ethereum-package entrypoint creates an allocs.csv for unknown chains
# (e.g. kurtosis devnets) at runtime.
COPY --from=builder /src/src/other/install/per-chain /root/.local/share/trueblocks/config

EXPOSE 8080
ENTRYPOINT ["chifra"]
