#!/bin/bash

echo "==================================="
echo "Kaspa TX Generator Build Script"
echo "==================================="
echo ""

# Check if setup has been run
if [ ! -d "rusty-kaspa/Tx_gen" ]; then
    echo "⚠ Setup has not been run. Running setup first..."
    ./setup.sh
    if [ $? -ne 0 ]; then
        echo "✗ Setup failed"
        exit 1
    fi
    echo ""
fi

# Sync files to workspace
echo "→ Syncing files to workspace..."
cp Cargo.toml rusty-kaspa/Tx_gen/
cp -r src/* rusty-kaspa/Tx_gen/src/
echo "✓ Files synced"

# Build the project
echo "→ Building Tx_gen (this may take a while on first run)..."
cd rusty-kaspa

cargo build --release --bin Tx_gen
if [ $? -ne 0 ]; then
    echo "✗ Build failed"
    exit 1
fi

echo "✓ Build successful!"
echo ""
echo "==================================="
echo "Build complete!"
echo ""
echo "Binary location:"
echo "  rusty-kaspa/target/release/Tx_gen"
echo ""
echo "To run:"
echo "  ./rusty-kaspa/target/release/Tx_gen --help"
echo ""
echo "Example usage:"
echo "  cd rusty-kaspa"
echo "  cargo run --release --bin Tx_gen -- --network testnet10"
echo ""
echo "Or with environment variable:"
echo "  PRIVATE_KEY_HEX=your_key cargo run --release --bin Tx_gen"
echo "==================================="