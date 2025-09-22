#!/bin/bash

echo "==================================="
echo "Kaspa TX Generator Setup Script"
echo "==================================="
echo ""

# Check if rusty-kaspa already exists
if [ -d "rusty-kaspa" ]; then
    echo "✓ rusty-kaspa directory already exists"
else
    echo "→ Cloning rusty-kaspa repository..."
    git clone https://github.com/kaspanet/rusty-kaspa.git rusty-kaspa
    if [ $? -ne 0 ]; then
        echo "✗ Failed to clone rusty-kaspa"
        exit 1
    fi
    echo "✓ rusty-kaspa cloned successfully"
fi

# Add Tx_gen to workspace if not already added
if grep -q "Tx_gen" rusty-kaspa/Cargo.toml; then
    echo "✓ Tx_gen already in workspace"
else
    echo "→ Adding Tx_gen to workspace..."
    sed -i '3a\    "Tx_gen",' rusty-kaspa/Cargo.toml
    echo "✓ Tx_gen added to workspace"
fi

# Create Tx_gen directory in rusty-kaspa
echo "→ Setting up Tx_gen in workspace..."
mkdir -p rusty-kaspa/Tx_gen/src

# Copy files to workspace
cp Cargo.toml rusty-kaspa/Tx_gen/
cp -r src/* rusty-kaspa/Tx_gen/src/

echo "✓ Files copied to workspace"

# Check for .env file
if [ -f ".env" ]; then
    echo "✓ .env file found"
else
    if [ -f ".env.example" ]; then
        echo ""
        echo "⚠ No .env file found. Please copy .env.example to .env and add your private key:"
        echo "  cp .env.example .env"
        echo "  Then edit .env and set PRIVATE_KEY_HEX"
    fi
fi

# Check for config.toml
if [ -f "config.toml" ]; then
    echo "✓ config.toml found"
else
    if [ -f "config.example.toml" ]; then
        echo ""
        echo "ℹ No config.toml found. You can optionally copy config.example.toml:"
        echo "  cp config.example.toml config.toml"
        echo "  Then customize the settings as needed"
    fi
fi

echo ""
echo "==================================="
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Ensure you have a .env file with your PRIVATE_KEY_HEX set"
echo "2. Optionally create config.toml from config.example.toml"
echo "3. Build the project: ./build.sh"
echo "4. Run the generator:"
echo "   cd rusty-kaspa"
echo "   cargo run --release --bin Tx_gen -- --network testnet10"
echo "==================================="