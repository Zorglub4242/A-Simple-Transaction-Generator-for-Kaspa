mod config;
mod error;
mod network;
mod spam;
mod transaction;
mod utxo;

use crate::config::{load_config, Cli, Config};
use crate::error::{Result, TxGenError};
use crate::transaction::{calculate_fee, create_splitting_transaction};
use clap::Parser;
use kaspa_addresses::{Address, Version};
use kaspa_consensus_core::tx::TransactionOutpoint;
use kaspa_grpc_client::GrpcClient;
use kaspa_rpc_core::{api::rpc::RpcApi, model::SubmitTransactionRequest, RpcTransaction};
use secp256k1::{Keypair, SecretKey, SECP256K1};
use std::str::FromStr;
use std::sync::Arc;
use tokio::time::{sleep, Duration};
use tracing::{error, info, warn};
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    if let Err(e) = run().await {
        error!("Fatal error: {}", e);
        std::process::exit(1);
    }
}

async fn run() -> Result<()> {
    // Parse CLI arguments
    let cli = Cli::parse();

    // Load configuration
    let (config, private_key_hex) = load_config(&cli)?;

    // Initialize logging
    init_logging(&config)?;

    info!("Kaspa Transaction Generator v{}", env!("CARGO_PKG_VERSION"));
    info!("Network: {:?}", config.network.network);

    // Parse private key and create keypair
    let secret_key = SecretKey::from_str(&private_key_hex)
        .map_err(|e| TxGenError::InvalidPrivateKey(format!("Invalid private key: {}", e)))?;
    let keypair = Keypair::from_secret_key(&SECP256K1, &secret_key);

    // Create address
    let address = Address::new(
        config.network.network.prefix(),
        Version::PubKey,
        &keypair.x_only_public_key().0.serialize(),
    );

    info!("Using address: {}", address);

    // Create client pool
    let clients = network::create_client_pool(&config).await?;

    // Verify network matches
    let server_info = network::verify_network(&clients[0], config.network.network, &address).await?;
    info!("Connected to {} (DAA score: {})", server_info.network_id, server_info.virtual_daa_score);

    // Fetch initial UTXOs
    let utxos = utxo::fetch_spendable_utxos(&clients[0], address.clone(), &config).await?;
    let current_utxo_count = utxos.len();
    let total_balance: u64 = utxos.iter().map(|(_, entry)| entry.amount).sum();

    info!("=== UTXO Analysis ===");
    info!("Current UTXOs: {}", current_utxo_count);
    info!("Total balance: {:.2} KAS", total_balance as f64 / 100_000_000.0);

    // Check if we need to split UTXOs
    if current_utxo_count < config.utxo.target_utxo_count {
        perform_utxo_splitting(&clients[0], &keypair, &address, utxos, &config).await?;
    } else {
        info!(
            "Already have {} UTXOs (target: {}), skipping splitting phase",
            current_utxo_count, config.utxo.target_utxo_count
        );
    }

    // Run spam loop
    info!("=== Starting Transaction Spam ===");
    spam::run_spam_loop(&clients, address, Arc::new(keypair), &config).await?;

    Ok(())
}

async fn perform_utxo_splitting(
    client: &GrpcClient,
    keypair: &Keypair,
    address: &Address,
    mut utxos: Vec<(TransactionOutpoint, kaspa_consensus_core::tx::UtxoEntry)>,
    config: &Config,
) -> Result<()> {
    info!("=== Phase 1: UTXO Splitting ===");

    let utxos_needed = config.utxo.target_utxo_count - utxos.len();
    info!("Need to create {} more UTXOs", utxos_needed);

    // Find largest UTXO
    let largest_utxo = utxos
        .iter()
        .max_by_key(|(_, e)| e.amount)
        .ok_or_else(|| TxGenError::InsufficientFunds {
            required: 10.0,
            available: 0.0,
        })?
        .clone();

    let kas_amount = largest_utxo.1.amount as f64 / 100_000_000.0;
    info!("Using largest UTXO with {:.2} KAS for splitting", kas_amount);

    if kas_amount < 10.0 {
        return Err(TxGenError::InsufficientFunds {
            required: 10.0,
            available: kas_amount,
        });
    }

    let mut current_utxo = largest_utxo;
    let mut created = 0usize;

    let transactions_count = (config.utxo.target_utxo_count + config.utxo.outputs_per_transaction - 1)
        / config.utxo.outputs_per_transaction;

    for i in 0..transactions_count {
        let remaining_tx = transactions_count - i;
        let outputs_this_tx = if remaining_tx == 1 {
            config.utxo.target_utxo_count - (i * config.utxo.outputs_per_transaction)
        } else {
            config.utxo.outputs_per_transaction
        };

        let total_output_value = config.utxo.amount_per_utxo * outputs_this_tx as u64;
        let estimated_fee = calculate_fee(config, 1, outputs_this_tx as u64 + 1, true);
        let change_value = current_utxo.1.amount.saturating_sub(total_output_value + estimated_fee);

        if change_value < config.utxo.min_change_sompi && i < transactions_count - 1 {
            warn!("Insufficient funds for change in tx {}, stopping", i + 1);
            break;
        }

        let tx = create_splitting_transaction(
            keypair,
            &current_utxo,
            config.utxo.amount_per_utxo,
            outputs_this_tx,
            change_value,
            address,
            config.utxo.min_change_sompi,
        )?;

        info!("Submitting splitting transaction {} with {} outputs", i + 1, outputs_this_tx);

        client
            .submit_transaction_call(None, SubmitTransactionRequest {
                transaction: RpcTransaction::from(&tx),
                allow_orphan: true,
            })
            .await?;

        created += 1;

        // Update current UTXO to the change output for next iteration
        if i < transactions_count - 1 && change_value >= config.utxo.min_change_sompi {
            let change_outpoint = TransactionOutpoint::new(tx.id(), outputs_this_tx as u32);
            let change_entry = kaspa_consensus_core::tx::UtxoEntry {
                amount: change_value,
                script_public_key: kaspa_txscript::pay_to_address_script(address),
                block_daa_score: current_utxo.1.block_daa_score,
                is_coinbase: false,
            };
            current_utxo = (change_outpoint, change_entry);
        }

        // Small delay between submissions
        sleep(Duration::from_millis(200)).await;
    }

    info!("Created {} splitting transactions, waiting for confirmations...", created);
    sleep(Duration::from_secs(10)).await;

    Ok(())
}

fn init_logging(config: &Config) -> Result<()> {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(&config.logging.level));

    let builder = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false);

    if config.logging.colored {
        builder.with_ansi(true).init();
    } else {
        builder.with_ansi(false).init();
    }

    Ok(())
}