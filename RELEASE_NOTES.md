# Release v0.2.0 - Improved Kaspa Transaction Generator

## 🚀 Major Improvements

This release represents a complete refactor of the original transaction generator with focus on security, usability, and maintainability.

### ✨ Key Features

- **🔒 Secure Configuration**: No more hardcoded private keys! Now supports:
  - Environment variables (`.env` file)
  - Command-line arguments
  - TOML configuration files

- **📦 Modular Architecture**: Clean code organization with dedicated modules:
  - `config.rs` - Configuration management
  - `error.rs` - Custom error types
  - `network.rs` - Network handling
  - `transaction.rs` - Transaction building
  - `utxo.rs` - UTXO management
  - `spam.rs` - Transaction generation loop

- **📝 Professional Logging**: Structured logging with configurable levels using `tracing`

- **🛡️ Safety Features**:
  - Network verification (ensures address matches network)
  - TPS safety cap (can be overridden with `unleashed` flag)
  - Comprehensive error handling

## 📥 Download

### Windows x64
- **File**: `kaspa-tx-generator-v0.2.0-windows-x64.zip` (4.25 MB)
- **Requirements**: Windows 10 or later (64-bit)

## 🚀 Quick Start

1. **Download and extract** the zip file
2. **Copy** `.env.example` to `.env`
3. **Add your private key** to the `.env` file
4. **Run** `run-testnet.bat` for testnet or `run-mainnet.bat` for mainnet

## 📖 Usage

### Basic Commands

```bash
# Run on testnet (default)
Tx_gen.exe --network testnet10

# Run on mainnet
Tx_gen.exe --network mainnet

# Specify target TPS and duration
Tx_gen.exe --target-tps 50 --duration 60

# Use command-line private key (instead of .env)
Tx_gen.exe --private-key YOUR_KEY_HERE

# Use custom config file
Tx_gen.exe --config myconfig.toml
```

### Configuration Options

The tool supports three levels of configuration:
1. **Environment variables** (`.env` file)
2. **Configuration file** (`config.toml`)
3. **Command-line arguments** (highest priority)

## 🔑 Getting a Private Key

### For Testing (Testnet)
- Generate at [K Social Network](https://ksocialnetwork.pages.dev/watching)
- Or use [Kaspa Wallet Generator](https://github.com/deepakdhaka-1/Kaspa-Wallet-Generate)

### For Production (Mainnet)
- Export from your Kaspa wallet
- **⚠️ SECURITY WARNING**: Never share your private key!

## 📊 What's Included

- `Tx_gen.exe` - Main executable
- `.env.example` - Environment variable template
- `config.example.toml` - Advanced configuration template
- `README.txt` - Detailed instructions
- `run-testnet.bat` - Easy testnet launcher
- `run-mainnet.bat` - Mainnet launcher (use with caution)
- `LICENSE` - MIT License

## 🛠️ Technical Details

- **Language**: Rust
- **Framework**: rusty-kaspa
- **Build**: Release mode with optimizations
- **Size**: ~10MB executable, 4.25MB compressed

## ⚠️ Important Notes

1. **Always test on testnet first** before using on mainnet
2. **Start with low TPS** (5-10) and increase gradually
3. **Monitor your system resources** when running at high TPS
4. **Keep `unleashed = false`** in config unless you know what you're doing
5. **Secure your private key** - never commit it to version control

## 🐛 Known Limitations

- Currently only Windows x64 binary is provided
- Linux and macOS users need to build from source
- Requires protoc for building from source

## 🔮 Future Releases

Planned for future releases:
- Linux x64 binary
- macOS ARM64 binary
- Docker container
- Cross-platform GUI

## 📝 Building from Source

If you want to build for other platforms:

1. Clone the repository
2. Install Rust and protoc
3. Run `./setup.sh` (Unix) or `.\setup.ps1` (Windows)
4. Run `./build.sh` (Unix) or `.\build.ps1` (Windows)

## 🤝 Contributing

Contributions are welcome! Please submit pull requests or open issues on GitHub.

## 📄 License

MIT License - See LICENSE file for details

## 🙏 Credits

- Based on the original Rothschild transaction generator
- Built on the [rusty-kaspa](https://github.com/kaspanet/rusty-kaspa) framework
- Improved version by the community

---

**Version**: 0.2.0
**Release Date**: September 2024
**Compatibility**: Kaspa Testnet-10 and Mainnet