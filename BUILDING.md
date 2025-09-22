# Building Kaspa Transaction Generator

## Prerequisites

### All Platforms
- Rust 1.70 or later
- Git
- Protocol Buffers compiler (protoc)

### Platform-Specific Requirements

#### Windows
- Visual Studio Build Tools or Visual Studio 2019+
- Windows SDK

#### Linux
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install build-essential pkg-config libssl-dev protobuf-compiler

# Fedora/RHEL
sudo dnf install gcc openssl-devel protobuf-compiler

# Arch
sudo pacman -S base-devel openssl protobuf
```

#### macOS
```bash
# Using Homebrew
brew install protobuf
```

## Building from Source

### Step 1: Clone the Repository
```bash
git clone https://github.com/Zorglub4242/A-Simple-Transaction-Generator-for-Kaspa.git
cd A-Simple-Transaction-Generator-for-Kaspa
```

### Step 2: Clone rusty-kaspa
```bash
git clone https://github.com/kaspanet/rusty-kaspa.git
```

### Step 3: Set Up Workspace
```bash
# Add Tx_gen to rusty-kaspa workspace
# Edit rusty-kaspa/Cargo.toml and add "Tx_gen" to the members list

# Create Tx_gen directory
mkdir -p rusty-kaspa/Tx_gen

# Copy source files
cp -r src rusty-kaspa/Tx_gen/
cp Cargo.toml rusty-kaspa/Tx_gen/
```

### Step 4: Build

#### Windows
```powershell
cd rusty-kaspa
$env:PROTOC = "path\to\protoc.exe"
cargo build --release --bin Tx_gen
```

#### Linux/macOS
```bash
cd rusty-kaspa
export PROTOC=$(which protoc)
cargo build --release --bin Tx_gen
```

## Cross-Compilation

### Building for Different Targets

#### From Linux to Windows
```bash
# Install cross-compilation toolchain
rustup target add x86_64-pc-windows-gnu
sudo apt-get install mingw-w64

# Build
cargo build --release --target x86_64-pc-windows-gnu --bin Tx_gen
```

#### From Windows to Linux
```powershell
# Install target
rustup target add x86_64-unknown-linux-gnu

# You'll need a Linux toolchain - this is complex on Windows
# Consider using WSL2 or Docker instead
```

#### For macOS (Apple Silicon)
```bash
rustup target add aarch64-apple-darwin
cargo build --release --target aarch64-apple-darwin --bin Tx_gen
```

## Using Docker for Cross-Platform Builds

### Create a Dockerfile
```dockerfile
FROM rust:1.75

# Install protoc
RUN apt-get update && apt-get install -y protobuf-compiler

# Install cross-compilation targets
RUN rustup target add x86_64-pc-windows-gnu
RUN rustup target add x86_64-unknown-linux-musl

# Install mingw for Windows builds
RUN apt-get install -y mingw-w64

WORKDIR /build
```

### Build with Docker
```bash
# Build the Docker image
docker build -t kaspa-builder .

# Run builds for different platforms
docker run -v $(pwd):/build kaspa-builder cargo build --release --bin Tx_gen
```

## Creating Release Binaries

### Optimized Release Build
```bash
# Maximum optimization
RUSTFLAGS="-C target-cpu=native" cargo build --release --bin Tx_gen

# Strip symbols to reduce size
strip target/release/Tx_gen  # Linux/macOS
# or
strip target/release/Tx_gen.exe  # Windows
```

### Size Optimization
Add to Cargo.toml for smaller binaries:
```toml
[profile.release]
opt-level = "z"     # Optimize for size
lto = true          # Link-time optimization
codegen-units = 1   # Single codegen unit
strip = true        # Strip symbols
panic = "abort"     # Smaller panic handler
```

## Troubleshooting

### protoc not found
- **Windows**: Download from GitHub releases and add to PATH
- **Linux**: Install `protobuf-compiler` package
- **macOS**: Install via Homebrew: `brew install protobuf`

### Linking errors
- Ensure you have the appropriate C++ build tools installed
- On Windows, install Visual Studio Build Tools
- On Linux, install `build-essential`

### Out of memory during build
- Reduce parallel jobs: `cargo build -j 2`
- Close other applications
- Consider building in release mode only

## Binary Locations

After successful build, binaries are located at:
- **Windows**: `rusty-kaspa/target/release/Tx_gen.exe`
- **Linux/macOS**: `rusty-kaspa/target/release/Tx_gen`

## Testing Your Build

```bash
# Check version
./Tx_gen --version

# Show help
./Tx_gen --help

# Test on testnet (requires .env with private key)
./Tx_gen --network testnet10 --duration 10 --target-tps 1
```

## Creating a Release Package

### Windows
```powershell
.\create-release.ps1
```

### Linux/macOS
```bash
# Create release directory
mkdir -p release/linux-x64
cp target/release/Tx_gen release/linux-x64/
cp .env.example config.example.toml LICENSE release/linux-x64/

# Create tarball
tar -czf kaspa-tx-generator-v0.2.0-linux-x64.tar.gz -C release linux-x64
```

## Contributing

When contributing, please:
1. Test on your platform
2. Include build instructions for new platforms
3. Update this document with any new requirements