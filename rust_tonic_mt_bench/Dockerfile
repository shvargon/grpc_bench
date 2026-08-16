ARG RUST_VERSION=1.97
FROM rust:${RUST_VERSION} as builder

RUN apt update && apt install -y protobuf-compiler-grpc cmake
RUN rustup component add rustfmt
COPY proto /app/proto

FROM builder

WORKDIR /app
COPY rust_tonic_mt_bench /app
RUN cargo build --release --locked

ENTRYPOINT ["/app/target/release/helloworld-server"]
