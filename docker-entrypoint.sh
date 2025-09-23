#!/bin/bash
set -e

# Kaspa Transaction Generator Docker Entrypoint
# This script generates a config.toml from environment variables and runs Tx_gen

echo "======================================"
echo "Kaspa Transaction Generator"
echo "======================================"

# Check for required PRIVATE_KEY_HEX
if [ -z "$PRIVATE_KEY_HEX" ]; then
    echo "ERROR: PRIVATE_KEY_HEX environment variable is required!"
    echo ""
    echo "Usage: docker run -e PRIVATE_KEY_HEX=your_key zorglub4242/kaspa-tx-generator"
    echo ""
    echo "Available environment variables:"
    echo "  Required:"
    echo "    PRIVATE_KEY_HEX         - Your private key (64 hex chars)"
    echo ""
    echo "  Network:"
    echo "    NETWORK                 - Network type (default: testnet10)"
    echo "    RPC_ENDPOINT           - Kaspad RPC endpoint (default: auto)"
    echo ""
    echo "  UTXO Management:"
    echo "    TARGET_UTXO_COUNT      - Target UTXO count (default: 100)"
    echo "    AMOUNT_PER_UTXO        - Amount per UTXO in sompi (default: 150000000)"
    echo "    OUTPUTS_PER_TRANSACTION - Outputs per split tx (default: 20)"
    echo "    MIN_CHANGE_SOMPI       - Minimum change (default: 10000)"
    echo "    UTXO_REFRESH_SECS      - UTXO refresh interval (default: 30)"
    echo ""
    echo "  Transaction Generation:"
    echo "    TARGET_TPS             - Target TPS (default: 10)"
    echo "    DURATION               - Duration in seconds, 0=infinite (default: 0)"
    echo "    UNLEASHED              - Remove 100 TPS cap (default: false)"
    echo "    MILLIS_PER_TICK        - Pacing tick ms (default: 10)"
    echo ""
    echo "  Fees:"
    echo "    BASE_FEE_RATE          - Base fee rate (default: 1)"
    echo "    SPLITTING_FEE_RATE     - Splitting fee rate (default: 10)"
    echo ""
    echo "  Advanced:"
    echo "    CLIENT_POOL_SIZE       - gRPC client pool (default: 16)"
    echo "    MAX_PENDING_AGE_SECS   - Max pending age (default: 60)"
    echo "    MAX_INFLIGHT           - Max inflight txs (default: 50000)"
    echo ""
    echo "  Logging:"
    echo "    LOG_LEVEL              - Log level (default: info)"
    echo "======================================"
    exit 1
fi

# Set defaults
NETWORK=${NETWORK:-testnet10}
TARGET_TPS=${TARGET_TPS:-10}
DURATION=${DURATION:-0}
TARGET_UTXO_COUNT=${TARGET_UTXO_COUNT:-100}
AMOUNT_PER_UTXO=${AMOUNT_PER_UTXO:-150000000}
OUTPUTS_PER_TRANSACTION=${OUTPUTS_PER_TRANSACTION:-20}
MIN_CHANGE_SOMPI=${MIN_CHANGE_SOMPI:-10000}
UTXO_REFRESH_SECS=${UTXO_REFRESH_SECS:-30}
UNLEASHED=${UNLEASHED:-false}
MILLIS_PER_TICK=${MILLIS_PER_TICK:-10}
BASE_FEE_RATE=${BASE_FEE_RATE:-1}
SPLITTING_FEE_RATE=${SPLITTING_FEE_RATE:-10}
CLIENT_POOL_SIZE=${CLIENT_POOL_SIZE:-16}
MAX_PENDING_AGE_SECS=${MAX_PENDING_AGE_SECS:-60}
MAX_INFLIGHT=${MAX_INFLIGHT:-50000}
COINBASE_MATURITY=${COINBASE_MATURITY:-100}
CONFIRMATION_DEPTH=${CONFIRMATION_DEPTH:-10}
LOG_LEVEL=${LOG_LEVEL:-info}
LOG_COLORED=${LOG_COLORED:-true}
LOG_TIMESTAMPS=${LOG_TIMESTAMPS:-true}

# Set RPC endpoint based on network if not provided
if [ -z "$RPC_ENDPOINT" ]; then
    if [ "$NETWORK" = "mainnet" ]; then
        # Check if running in Docker network with kaspad container
        if nc -zv kaspad-mainnet 16110 2>/dev/null; then
            RPC_ENDPOINT="grpc://kaspad-mainnet:16110"
        elif nc -zv kaspad 16110 2>/dev/null; then
            RPC_ENDPOINT="grpc://kaspad:16110"
        else
            RPC_ENDPOINT="grpc://n-mainnet.kaspa.ws:16110"
        fi
    else
        # Testnet
        if nc -zv kaspad-testnet 16210 2>/dev/null; then
            RPC_ENDPOINT="grpc://kaspad-testnet:16210"
        elif nc -zv kaspad 16210 2>/dev/null; then
            RPC_ENDPOINT="grpc://kaspad:16210"
        else
            RPC_ENDPOINT="grpc://n-testnet-10.kaspa.ws:16210"
        fi
    fi
fi

echo "Configuration:"
echo "  Network: $NETWORK"
echo "  RPC Endpoint: $RPC_ENDPOINT"
echo "  Target TPS: $TARGET_TPS"
echo "  Duration: $DURATION seconds (0=infinite)"
echo "  Target UTXOs: $TARGET_UTXO_COUNT"
echo "  Amount per UTXO: $(echo "scale=2; $AMOUNT_PER_UTXO / 100000000" | bc -l) KAS"
echo "  Unleashed: $UNLEASHED"
echo "  Log Level: $LOG_LEVEL"
echo "======================================"

# Generate config.toml
cat > /app/config.toml << EOF
# Auto-generated config from environment variables

[network]
network = "$NETWORK"
rpc_endpoint = "$RPC_ENDPOINT"

[utxo]
target_utxo_count = $TARGET_UTXO_COUNT
amount_per_utxo = $AMOUNT_PER_UTXO
outputs_per_transaction = $OUTPUTS_PER_TRANSACTION
min_change_sompi = $MIN_CHANGE_SOMPI
refresh_interval_secs = $UTXO_REFRESH_SECS

[spam]
target_tps = $TARGET_TPS
duration_seconds = $DURATION
unleashed = $UNLEASHED
millis_per_tick = $MILLIS_PER_TICK

[fees]
base_fee_rate = $BASE_FEE_RATE
splitting_fee_rate = $SPLITTING_FEE_RATE

[advanced]
client_pool_size = $CLIENT_POOL_SIZE
max_pending_age_secs = $MAX_PENDING_AGE_SECS
max_inflight = $MAX_INFLIGHT
coinbase_maturity = $COINBASE_MATURITY
confirmation_depth = $CONFIRMATION_DEPTH

[logging]
level = "$LOG_LEVEL"
colored = $LOG_COLORED
timestamps = $LOG_TIMESTAMPS
EOF

# Show warning for mainnet
if [ "$NETWORK" = "mainnet" ]; then
    echo ""
    echo "WARNING: Running on MAINNET - Real funds will be used!"
    echo ""
    sleep 3
fi

# Wait for kaspad if in Docker network
echo "Checking connectivity to Kaspad..."
if [[ "$RPC_ENDPOINT" == *"kaspad"* ]]; then
    # Extract host and port from RPC_ENDPOINT
    HOST=$(echo $RPC_ENDPOINT | sed 's/grpc:\/\///' | cut -d: -f1)
    PORT=$(echo $RPC_ENDPOINT | sed 's/grpc:\/\///' | cut -d: -f2)

    echo "Waiting for $HOST:$PORT to be ready..."
    for i in {1..30}; do
        if nc -zv $HOST $PORT 2>/dev/null; then
            echo "Connected to Kaspad!"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "Warning: Could not connect to $HOST:$PORT, proceeding anyway..."
        fi
        sleep 2
    done
fi

# Run the transaction generator with the config
echo ""
echo "Starting transaction generator..."
echo "======================================"
exec /app/Tx_gen \
    --config /app/config.toml \
    --network "$NETWORK" \
    --target-tps "$TARGET_TPS" \
    --duration "$DURATION" \
    --log-level "$LOG_LEVEL" \
    "$@"