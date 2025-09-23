Kaspa Transaction Generator v0.2.0 - Windows x64
=================================================

QUICK START GUIDE
-----------------

1. SETUP YOUR PRIVATE KEY
   - Copy .env.example to .env
   - Edit .env and add your private key (64 hex characters)
   - SECURITY WARNING: Never share your private key!

2. GET A PRIVATE KEY
   Option A: Generate one at https://github.com/deepakdhaka-1/Kaspa-Wallet-Generate
   Option B: For testnet, get one from https://ksocialnetwork.pages.dev/watching
   Option C: Export from an existing Kaspa wallet

3. BASIC USAGE

   For testnet (recommended for testing):
   Tx_gen.exe --network testnet10

   For mainnet (use with caution):
   Tx_gen.exe --network mainnet

4. COMMAND LINE OPTIONS

   Tx_gen.exe [OPTIONS]

   -n, --network <NETWORK>       Network: mainnet or testnet10 [default: testnet10]
   -k, --private-key <KEY>       Private key (overrides .env file)
   -t, --target-tps <TPS>        Target transactions per second
   -d, --duration <SECONDS>      Duration in seconds (0 = forever)
   -l, --log-level <LEVEL>       Log level: error, warn, info, debug, trace
   -c, --config <FILE>           Config file path (optional)
   -h, --help                    Show help
   -V, --version                 Show version

5. EXAMPLES

   # Run on testnet for 60 seconds at 10 TPS
   Tx_gen.exe --network testnet10 --target-tps 10 --duration 60

   # Run with environment variable instead of .env file
   set PRIVATE_KEY_HEX=your_key_here
   Tx_gen.exe

   # Run with custom config file
   Tx_gen.exe --config myconfig.toml

   # Run with debug logging
   Tx_gen.exe --log-level debug

6. CONFIGURATION FILE (OPTIONAL)

   Copy config.example.toml to config.toml and customize settings:
   - Target TPS
   - UTXO management
   - Fee rates
   - Advanced settings

7. HOW IT WORKS

   Phase 1: UTXO Preparation
   - Analyzes your wallet's UTXOs
   - Splits large UTXOs if needed
   - Creates a pool for high-rate transactions

   Phase 2: Transaction Generation
   - Sends transactions at configured TPS
   - Uses parallel processing
   - Shows real-time statistics

8. REQUIREMENTS

   - Windows 10 or later (64-bit)
   - Internet connection
   - Funded Kaspa address (use testnet for testing)

9. TROUBLESHOOTING

   "Address prefix does not match network"
   - Mainnet addresses start with: kaspa:
   - Testnet addresses start with: kaspatest:

   "Insufficient funds"
   - You need at least 10 KAS in a single UTXO
   - Check your balance and consolidate if needed

   Connection issues:
   - Check internet connection
   - Verify firewall settings
   - Try again later if node is busy

10. SAFETY TIPS

   - Always test on testnet first
   - Start with low TPS (5-10)
   - Monitor CPU and network usage
   - Keep unleashed = false in config
   - Never share your private key!

11. SUPPORT

   GitHub: https://github.com/Zorglub4242/A-Simple-Transaction-Generator-for-Kaspa
   Report issues: https://github.com/Zorglub4242/A-Simple-Transaction-Generator-for-Kaspa/issues

=================================================
Version: 0.2.0
License: MIT
Based on rusty-kaspa framework