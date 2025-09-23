# Kaspa Transaction Generator - Docker Guide

## Quick Start

Pull and run the pre-built image:

```bash
docker run -e PRIVATE_KEY_HEX=your_private_key_here \
  zorglub4242/kaspa-tx-generator:latest
```

## Available Images

- `zorglub4242/kaspa-tx-generator:latest` - Latest stable version
- `zorglub4242/kaspa-tx-generator:v0.3.0` - Specific version
- `zorglub4242/kaspa-tx-generator:testnet` - Pre-configured for testnet
- `zorglub4242/kaspa-tx-generator:mainnet` - Pre-configured for mainnet

## Environment Variables

### Required
- `PRIVATE_KEY_HEX` - Your 64-character hex private key

### Network Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `NETWORK` | `testnet10` | Network type: `mainnet` or `testnet10` |
| `RPC_ENDPOINT` | Auto | Kaspad RPC endpoint (e.g., `grpc://localhost:16210`) |

### UTXO Management
| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_UTXO_COUNT` | `100` | Target number of UTXOs to maintain |
| `AMOUNT_PER_UTXO` | `150000000` | Amount per UTXO in sompi (150M = 1.5 KAS) |
| `OUTPUTS_PER_TRANSACTION` | `20` | Outputs per splitting transaction |
| `MIN_CHANGE_SOMPI` | `10000` | Minimum change to keep (avoid dust) |
| `UTXO_REFRESH_SECS` | `30` | UTXO list refresh interval |

### Transaction Generation
| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_TPS` | `10` | Target transactions per second |
| `DURATION` | `0` | Test duration in seconds (0 = infinite) |
| `UNLEASHED` | `false` | Remove 100 TPS safety cap |
| `MILLIS_PER_TICK` | `10` | Pacing tick in milliseconds |

### Fee Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_FEE_RATE` | `1` | Fee rate for spam transactions (sompi/gram) |
| `SPLITTING_FEE_RATE` | `10` | Fee rate for UTXO splitting |

### Advanced Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `CLIENT_POOL_SIZE` | `16` | Number of gRPC client connections |
| `MAX_PENDING_AGE_SECS` | `60` | Maximum age for pending transactions |
| `MAX_INFLIGHT` | `50000` | Maximum concurrent submissions |
| `COINBASE_MATURITY` | `100` | Blocks before coinbase is spendable |
| `CONFIRMATION_DEPTH` | `10` | Blocks for transaction confirmation |

### Logging
| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `info` | Log level: error, warn, info, debug, trace |
| `LOG_COLORED` | `true` | Use colored output |
| `LOG_TIMESTAMPS` | `true` | Include timestamps in logs |

## Usage Examples

### Basic Testnet Run
```bash
docker run -e PRIVATE_KEY_HEX=your_key \
  zorglub4242/kaspa-tx-generator:testnet
```

### High Performance Configuration
```bash
docker run \
  -e PRIVATE_KEY_HEX=your_key \
  -e TARGET_UTXO_COUNT=500 \
  -e TARGET_TPS=1000 \
  -e UNLEASHED=true \
  -e CLIENT_POOL_SIZE=64 \
  zorglub4242/kaspa-tx-generator:latest
```

### Mainnet with Safety Limits
```bash
docker run \
  -e PRIVATE_KEY_HEX=your_mainnet_key \
  -e NETWORK=mainnet \
  -e TARGET_TPS=5 \
  -e DURATION=60 \
  -e RPC_ENDPOINT=grpc://my-mainnet-node:16110 \
  zorglub4242/kaspa-tx-generator:mainnet
```

### Using Docker Compose

1. Create `docker-compose.yml`:
```yaml
version: '3.8'

services:
  kaspad:
    image: supertypo/rusty-kaspad:latest
    ports:
      - "16210:16210"
    command: ["kaspad", "--testnet", "--rpclisten=0.0.0.0:16210", "--utxoindex"]

  tx-generator:
    image: zorglub4242/kaspa-tx-generator:latest
    depends_on:
      - kaspad
    environment:
      PRIVATE_KEY_HEX: ${PRIVATE_KEY_HEX}
      TARGET_TPS: 100
      TARGET_UTXO_COUNT: 200
      RPC_ENDPOINT: grpc://kaspad:16210
```

2. Create `.env` file:
```
PRIVATE_KEY_HEX=your_private_key_here
```

3. Run:
```bash
docker-compose up
```

### With Existing Kaspad Node
```bash
docker run \
  --network host \
  -e PRIVATE_KEY_HEX=your_key \
  -e RPC_ENDPOINT=grpc://localhost:16210 \
  zorglub4242/kaspa-tx-generator:latest
```

## Building From Source

If you want to build the image yourself:

```bash
# Clone the repository
git clone https://github.com/Zorglub4242/A-Simple-Transaction-Generator-for-Kaspa.git
cd A-Simple-Transaction-Generator-for-Kaspa

# Build the image
docker build -t my-kaspa-tx-generator .

# Run your local build
docker run -e PRIVATE_KEY_HEX=your_key my-kaspa-tx-generator
```

## Performance Tuning

### For Maximum TPS
- Increase `TARGET_UTXO_COUNT` (200-500)
- Set `UNLEASHED=true` to remove 100 TPS cap
- Increase `CLIENT_POOL_SIZE` (32-64)
- Decrease `MILLIS_PER_TICK` (5-10)
- Ensure sufficient `AMOUNT_PER_UTXO` funding

### For Stability
- Keep `UNLEASHED=false`
- Use moderate `TARGET_TPS` (10-50)
- Keep default `CLIENT_POOL_SIZE` (16)
- Set reasonable `DURATION` limit

### For Mainnet
- **Always** use low `TARGET_TPS` (1-10)
- **Always** set `DURATION` limit
- **Never** use `UNLEASHED=true` without testing
- Monitor fees carefully

## Troubleshooting

### "PRIVATE_KEY_HEX environment variable is required!"
Set your private key: `-e PRIVATE_KEY_HEX=your_64_char_hex_key`

### Cannot connect to Kaspad
- Check if kaspad is running: `docker ps`
- Verify network connectivity: `docker network ls`
- Use explicit RPC_ENDPOINT: `-e RPC_ENDPOINT=grpc://your-kaspad:16210`

### "Insufficient funds"
- Fund your wallet address (shown in logs)
- For testnet: Use https://faucet.kaspad.net/
- Ensure sufficient balance for UTXO splitting

### Low TPS despite high target
- Increase `TARGET_UTXO_COUNT`
- Check wallet balance
- Set `UNLEASHED=true` if targeting >100 TPS
- Verify network acceptance with `LOG_LEVEL=debug`

## Security Notes

⚠️ **NEVER** commit or share your `PRIVATE_KEY_HEX`
⚠️ **NEVER** use production wallets for testing
⚠️ **ALWAYS** test on testnet first
⚠️ **BE CAREFUL** with mainnet - real money at risk

## Support

For issues or questions:
- GitHub: https://github.com/Zorglub4242/A-Simple-Transaction-Generator-for-Kaspa
- Docker Hub: https://hub.docker.com/r/zorglub4242/kaspa-tx-generator