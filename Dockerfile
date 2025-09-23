# Multi-stage Dockerfile for Kaspa Transaction Generator
# Stage 1: Builder
FROM rust:latest AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    libprotobuf-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy the entire rusty-kaspa source
COPY rusty-kaspa/ ./rusty-kaspa/

# Build the transaction generator
WORKDIR /build/rusty-kaspa
RUN PROTOC=/usr/bin/protoc cargo build --release --bin Tx_gen

# Stage 2: Runtime
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy the compiled binary from builder
COPY --from=builder /build/rusty-kaspa/target/release/Tx_gen /app/Tx_gen

# Copy the entrypoint script (make sure it exists in build context)
COPY --chmod=755 docker-entrypoint.sh /app/docker-entrypoint.sh

# Install bc for calculations in the entrypoint script
RUN apt-get update && apt-get install -y bc && rm -rf /var/lib/apt/lists/*

# Set environment defaults (can be overridden at runtime)
ENV NETWORK=testnet10 \
    TARGET_TPS=10 \
    DURATION=0 \
    TARGET_UTXO_COUNT=100 \
    AMOUNT_PER_UTXO=150000000 \
    OUTPUTS_PER_TRANSACTION=20 \
    LOG_LEVEL=info

# Expose common Kaspa RPC ports (for reference)
EXPOSE 16110 16210

# Health check (optional - checks if binary is runnable)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD /app/Tx_gen --help || exit 1

# Use the entrypoint script
ENTRYPOINT ["/app/docker-entrypoint.sh"]

# Default command (can be overridden)
CMD []