# Dockerfile for Evidence CoC Chaincode (CCaaS Mode)
# This allows building the chaincode image externally for Chaincode-as-a-Service

FROM golang:1.21-alpine AS builder

WORKDIR /chaincode

# Install git for go mod download
RUN apk add --no-cache git

# Copy go mod files first for better caching
COPY go.mod go.sum* ./

# Download dependencies
RUN go mod download || go mod tidy

# Copy source code
COPY . .

# Ensure dependencies are vendored
RUN go mod tidy && go mod vendor

# Build the chaincode
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -mod=vendor -o chaincode -v .

# Production image - minimal
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /chaincode

# Copy the binary
COPY --from=builder /chaincode/chaincode /chaincode/chaincode

# Expose the chaincode port
EXPOSE 9999

# Run as non-root user
RUN adduser -D -u 1000 chaincode
USER chaincode

# Set the entrypoint
ENTRYPOINT ["/chaincode/chaincode"]

