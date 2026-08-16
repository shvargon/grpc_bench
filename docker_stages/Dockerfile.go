ARG GO_VERSION=1.26.2-bookworm
FROM golang:${GO_VERSION} as builder
RUN apt update && apt install -y protobuf-compiler
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.33.0
COPY proto /app/proto

FROM builder

WORKDIR /app
RUN go install github.com/planetscale/vtprotobuf/cmd/protoc-gen-go-vtproto@v0.6.0
