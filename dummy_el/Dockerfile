FROM rust:1.88.0-bullseye AS builder

WORKDIR /build

ENV CARGO_TARGET_DIR=/build/target

COPY dummy_el/Cargo.toml dummy_el/Cargo.toml
COPY dummy_el/src dummy_el/src

WORKDIR /build/dummy_el
RUN cargo build --release && \
    cp /build/target/release/dummy_el /dummy_el

FROM ubuntu:22.04

RUN apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends \
  ca-certificates \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /dummy_el /usr/local/bin/dummy_el

ENTRYPOINT ["/usr/local/bin/dummy_el"]
