ARG RUST_VERSION=1.97
FROM rust:${RUST_VERSION} as builder

RUN apt update && apt install -y protobuf-compiler-grpc cmake
COPY proto /app/proto

FROM builder

WORKDIR /app
COPY rust_pajamax_bench /app
RUN cargo build --release

ENTRYPOINT ["/app/target/release/helloworld"]
