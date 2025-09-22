use crate::config::Config;
use crate::error::Result;
use crate::transaction::{calculate_fee, create_spam_transaction};
use crate::utxo::UtxoManager;
use futures::stream::{FuturesUnordered, StreamExt};
use kaspa_addresses::Address;
use kaspa_consensus_core::tx::{Transaction, TransactionOutpoint, UtxoEntry as CoreUtxoEntry};
use kaspa_grpc_client::GrpcClient;
use kaspa_rpc_core::{api::rpc::RpcApi, model::SubmitTransactionRequest, RpcTransaction};
use rayon::prelude::*;
use secp256k1::Keypair;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};
use tokio::time::{interval, MissedTickBehavior};
use tracing::{debug, error, info, warn};

pub async fn run_spam_loop(
    clients: &[Arc<GrpcClient>],
    address: Address,
    keypair: Arc<Keypair>,
    config: &Config,
) -> Result<()> {
    let client0 = clients[0].clone();
    let tps_tx = spawn_tps_logger();

    // Initialize UTXO manager
    let initial_utxos = crate::utxo::fetch_spendable_utxos(&client0, address.clone(), config).await?;
    let mut utxo_manager = UtxoManager::new(initial_utxos);

    info!(
        "Starting spam loop: {} TPS target, {} UTXOs available",
        config.spam.target_tps,
        utxo_manager.available_count()
    );

    // Apply safety cap if not unleashed
    let effective_tps = if config.spam.unleashed {
        config.spam.target_tps
    } else {
        config.spam.target_tps.min(100)
    };

    if effective_tps != config.spam.target_tps {
        warn!(
            "Safety cap active: limiting TPS to {} (set unleashed=true to remove)",
            effective_tps
        );
    }

    // Setup tickers
    let mut ticker = interval(Duration::from_millis(config.spam.millis_per_tick));
    ticker.set_missed_tick_behavior(MissedTickBehavior::Delay);

    let mut stats_ticker = interval(Duration::from_secs(1));
    stats_ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);

    // Stats tracking
    let start = Instant::now();
    let mut stats_start = Instant::now();
    let mut sent_since_reset = 0u64;

    // Pacing calculation
    let target_per_tick = (effective_tps as f64) * (config.spam.millis_per_tick as f64) / 1000.0;
    let mut carry = 0.0;

    // Async submit queue
    let mut inflight: FuturesUnordered<_> = FuturesUnordered::new();
    let mut round_robin_idx = 0usize;

    loop {
        tokio::select! {
            _ = ticker.tick() => {
                // Check duration limit
                if config.spam.duration_seconds > 0 {
                    if start.elapsed().as_secs() >= config.spam.duration_seconds {
                        info!("Spam duration completed after {} seconds", config.spam.duration_seconds);
                        break;
                    }
                }

                // Refresh UTXOs if needed
                if utxo_manager.needs_refresh(config) {
                    if let Err(e) = utxo_manager.refresh(&client0, address.clone(), config).await {
                        warn!("Failed to refresh UTXOs: {}", e);
                    }
                }

                // Skip if no UTXOs available or queue is full
                if utxo_manager.available_count() == 0 {
                    debug!("No UTXOs available, waiting for refresh");
                    continue;
                }

                if inflight.len() >= config.advanced.max_inflight {
                    debug!("Inflight queue full ({}/{})", inflight.len(), config.advanced.max_inflight);
                    continue;
                }

                // Calculate how many transactions to send this tick
                let mut to_send = (target_per_tick + carry).floor() as u64;
                carry = (target_per_tick + carry) - (to_send as f64);

                // Limit by available resources
                to_send = to_send
                    .min(utxo_manager.available_count() as u64)
                    .min((config.advanced.max_inflight - inflight.len()) as u64);

                if to_send == 0 {
                    continue;
                }

                // Get batch of UTXOs
                let batch = utxo_manager.get_batch(to_send as usize);

                // Build transactions in parallel
                let transactions = build_spam_transactions(
                    &batch,
                    &address,
                    &keypair,
                    config,
                );

                // Reserve UTXOs
                utxo_manager.reserve(&batch);

                // Submit transactions
                for (tx, outpoint) in transactions {
                    let client = clients[round_robin_idx % clients.len()].clone();
                    round_robin_idx += 1;

                    inflight.push(async move {
                        let result = client
                            .submit_transaction_call(None, SubmitTransactionRequest {
                                transaction: RpcTransaction::from(&tx),
                                allow_orphan: false,
                            })
                            .await;
                        (result, outpoint)
                    });
                }

                // Prune old pending UTXOs
                utxo_manager.prune_old_pending(config.advanced.max_pending_age_secs);
            }

            Some((result, outpoint)) = inflight.next() => {
                match result {
                    Ok(_) => {
                        utxo_manager.mark_spent(outpoint);
                        sent_since_reset += 1;
                        let _ = tps_tx.send(1);
                    }
                    Err(e) => {
                        utxo_manager.release(&outpoint);
                        debug!("Transaction submission failed: {}", e);
                    }
                }
            }

            _ = stats_ticker.tick() => {
                let mempool_size = client0.get_info().await
                    .map(|i| i.mempool_size)
                    .unwrap_or(0);

                let elapsed = stats_start.elapsed().as_secs_f64();
                let current_tps = if elapsed > 0.0 {
                    sent_since_reset as f64 / elapsed
                } else {
                    0.0
                };

                info!(
                    "TPS: {:.1} | sent: {} | mempool: {} | inflight: {} | pending: {} | available: {} | runtime: {}s",
                    current_tps,
                    sent_since_reset,
                    mempool_size,
                    inflight.len(),
                    utxo_manager.pending.len(),
                    utxo_manager.available_count(),
                    start.elapsed().as_secs()
                );

                stats_start = Instant::now();
                sent_since_reset = 0;
            }
        }
    }

    info!("Spam loop completed");
    Ok(())
}

fn build_spam_transactions(
    batch: &[(TransactionOutpoint, CoreUtxoEntry)],
    address: &Address,
    keypair: &Arc<Keypair>,
    config: &Config,
) -> Vec<(Transaction, TransactionOutpoint)> {
    batch
        .par_iter()
        .filter_map(|(outpoint, entry)| {
            let fee = calculate_fee(config, 1, 1, false);
            let output_amount = entry.amount.saturating_sub(fee);

            if output_amount < config.utxo.min_change_sompi {
                debug!("Skipping UTXO with insufficient value after fee");
                return None;
            }

            match create_spam_transaction(
                keypair,
                *outpoint,
                entry.clone(),
                output_amount,
                address,
            ) {
                Ok(tx) => Some((tx, *outpoint)),
                Err(e) => {
                    error!("Failed to create transaction: {}", e);
                    None
                }
            }
        })
        .collect()
}

fn spawn_tps_logger() -> UnboundedSender<u32> {
    let (tx, mut rx) = unbounded_channel::<u32>();

    tokio::spawn(async move {
        let mut per_second = 0u64;
        let mut total = 0u64;
        let mut last_10: std::collections::VecDeque<u64> =
            std::collections::VecDeque::with_capacity(10);
        let mut ticker = interval(Duration::from_secs(1));

        loop {
            tokio::select! {
                Some(n) = rx.recv() => {
                    per_second += n as u64;
                    total += n as u64;
                }
                _ = ticker.tick() => {
                    if last_10.len() == 10 {
                        last_10.pop_front();
                    }
                    last_10.push_back(per_second);

                    let avg_10 = if last_10.is_empty() {
                        0.0
                    } else {
                        last_10.iter().sum::<u64>() as f64 / last_10.len() as f64
                    };

                    debug!(
                        "TPS Stats - Current: {} | 10s avg: {:.1} | Total sent: {}",
                        per_second, avg_10, total
                    );

                    per_second = 0;
                }
            }
        }
    });

    tx
}