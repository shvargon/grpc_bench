ARG GO_VERSION=1.26.2-bookworm
FROM golang:${GO_VERSION} as builder
RUN apt update && apt install -y protobuf-compiler
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.33.0
COPY proto /app/proto

FROM builder

WORKDIR /app
RUN go install github.com/planetscale/vtprotobuf/cmd/protoc-gen-go-vtproto@v0.6.0
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.3.0
COPY go_vtgrpc_bench /app

ENV GOBIN /go/bin
RUN protoc -I /app/proto/helloworld /app/proto/helloworld/helloworld.proto --go-grpc_out=/app/ --go_out=/app/ --go-vtproto_out=/app/ --plugin protoc-gen-go-vtproto="${GOBIN}/protoc-gen-go-vtproto" --go-vtproto_opt=features=marshal+unmarshal+size 
RUN go mod tidy && go build ./... && go install ./...

ENTRYPOINT example
