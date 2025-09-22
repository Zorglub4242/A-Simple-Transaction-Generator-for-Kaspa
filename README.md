# Kaspa Transaction Generator (Improved)

A high-performance transaction generator for the Kaspa blockchain, designed for testing network throughput and stress testing. This improved version features modular architecture, secure configuration management, and comprehensive error handling.

## Features

- **Secure Configuration**: No hardcoded private keys - uses environment variables, config files, or CLI arguments
- **Modular Architecture**: Clean separation of concerns with dedicated modules
- **Advanced Error Handling**: Comprehensive error types with detailed messages
- **Flexible Configuration**: TOML-based config with CLI overrides
- **Production-Ready Logging**: Structured logging with configurable levels
- **High Performance**: Parallel transaction building with async submission
- **Network Safety**: Built-in safety caps and network verification

## Quick Start

### Prerequisites

- Rust 1.70 or later
- Git
- A Kaspa wallet with funds (for mainnet) or test funds (for testnet)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/Zorglub4242/A-Simple-Transaction-Generator-for-Kaspa.git
cd A-Simple-Transaction-Generator-for-Kaspa
```

2. **Run the setup script**

**Linux/Mac:**
```bash
chmod +x setup.sh
./setup.sh
```

**Windows:**
```powershell
.\setup.ps1
```

3. **Configure your private key**
```bash
cp .env.example .env
# Edit .env and set your PRIVATE_KEY_HEX
```

4. **Build the project**

**Linux/Mac:**
```bash
./build.sh
```

**Windows:**
```powershell
.\build.ps1
```

## Configuration

### Environment Variables (.env)

Create a `.env` file from the example:
```bash
cp .env.example .env
```

Required variable:
- `PRIVATE_KEY_HEX`: Your 64-character hexadecimal private key

### Configuration File (config.toml)

Optionally create a custom configuration:
```bash
cp config.example.toml config.toml
```

Key settings:
- `network.network`: "mainnet" or "testnet10"
- `spam.target_tps`: Target transactions per second
- `spam.unleashed`: Remove 100 TPS safety cap (use carefully!)
- `utxo.target_utxo_count`: Number of UTXOs to maintain

### Command Line Options

```bash
Tx_gen [OPTIONS]

Options:
  -n, --network <NETWORK>      Network to use [default: testnet10]
  -k, --private-key <KEY>      Private key (overrides env var)
  -r, --rpc-endpoint <URL>     RPC endpoint (overrides config)
  -t, --target-tps <TPS>       Target transactions per second
  -d, --duration <SECONDS>     Duration in seconds (0 = forever)
  -l, --log-level <LEVEL>      Log level [default: info]
  -c, --config <FILE>          Config file path
  -h, --help                    Print help
  -V, --version                 Print version
```

## Usage Examples

### Basic Usage (Testnet)

```bash
cd rusty-kaspa
cargo run --release --bin Tx_gen
```

### With CLI Options

```bash
cargo run --release --bin Tx_gen -- \
  --network testnet10 \
  --target-tps 100 \
  --duration 3600 \
  --log-level debug
```

### Using Environment Variable

```bash
PRIVATE_KEY_HEX=your_key_here cargo run --release --bin Tx_gen
```

### Production Mode (Mainnet)

```bash
cargo run --release --bin Tx_gen -- \
  --network mainnet \
  --config production.toml \
  --log-level warn
```

## How It Works

### Phase 1: UTXO Preparation
- Analyzes your wallet's UTXOs
- If needed, splits large UTXOs into smaller ones
- Creates a pool of spendable UTXOs for high-rate transactions

### Phase 2: Transaction Generation
- Sends self-payment transactions at the configured TPS rate
- Uses parallel processing for transaction creation
- Implements async submission with connection pooling
- Monitors performance with rolling averages

## Getting a Private Key

### Option 1: Kaspa Wallet Generator
Use the community tool: [Kaspa Wallet Generator](https://github.com/deepakdhaka-1/Kaspa-Wallet-Generate)

### Option 2: From Existing Wallet
Export your private key from a compatible Kaspa wallet (ensure you understand the security implications)

### Option 3: For Testnet
Create a testnet account on [K Social Network](https://ksocialnetwork.pages.dev/watching)

**Security Warning**: Never share or commit your private key!

## Project Structure

```
├── src/
│   ├── main.rs         # Entry point and orchestration
│   ├── config.rs       # Configuration management
│   ├── error.rs        # Error types and handling
│   ├── network.rs      # Network connection and verification
│   ├── transaction.rs  # Transaction building and signing
│   ├── utxo.rs        # UTXO management
│   └── spam.rs        # Transaction spam loop
├── .env.example       # Example environment variables
├── config.example.toml # Example configuration
├── setup.sh/ps1       # Setup scripts
└── build.sh/ps1       # Build scripts
```

## Advanced Configuration

### Performance Tuning

```toml
[spam]
target_tps = 200           # Transactions per second
unleashed = true           # Remove safety cap
millis_per_tick = 10       # Pacing granularity

[advanced]
client_pool_size = 16      # gRPC connections
max_inflight = 50000       # Max concurrent submits
```

### Fee Configuration

```toml
[fees]
base_fee_rate = 1          # For spam transactions
splitting_fee_rate = 10    # For UTXO splitting
```

### UTXO Management

```toml
[utxo]
target_utxo_count = 200    # More UTXOs = higher sustainable TPS
amount_per_utxo = 150000000 # 1.5 KAS per UTXO
outputs_per_transaction = 20 # Splitting efficiency
```

## Troubleshooting

### "Address prefix does not match network"
- Ensure your address matches the selected network
- Mainnet addresses start with `kaspa:`
- Testnet addresses start with `kaspatest:`

### "Insufficient funds"
- You need at least 10 KAS in a single UTXO for splitting
- Check your balance and consolidate if needed

### Build Errors
- Ensure Rust is up to date: `rustup update`
- Clean and rebuild: `cargo clean && cargo build --release`

### Connection Issues
- Check your internet connection
- Try alternative RPC endpoints
- Verify firewall settings

## Safety & Best Practices

1. **Start with Testnet**: Always test on testnet first
2. **Use Safety Caps**: Keep `unleashed = false` until you're confident
3. **Monitor Resources**: Watch CPU, memory, and network usage
4. **Gradual Increases**: Start with low TPS and increase gradually
5. **Secure Keys**: Never commit private keys to version control

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Credits

- Based on the original Rothschild transaction generator
- Built on the [rusty-kaspa](https://github.com/kaspanet/rusty-kaspa) framework
- Improved version by the community

## Disclaimer

This tool is for testing and educational purposes. Use responsibly and be aware of network impact when running at high TPS rates. The authors are not responsible for any misuse or damages caused by this software.

## Support

For issues, questions, or suggestions:
- Open an issue on [GitHub](https://github.com/Zorglub4242/A-Simple-Transaction-Generator-for-Kaspa/issues)
- Join the Kaspa Discord community

---

**Version**: 0.2.0
**Last Updated**: 2024