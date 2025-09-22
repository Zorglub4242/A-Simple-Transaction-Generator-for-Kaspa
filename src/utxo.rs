use crate::config::Config;
use crate::error::Result;
use kaspa_addresses::Address;
use kaspa_consensus_core::tx::{TransactionOutpoint, UtxoEntry as CoreUtxoEntry};
use kaspa_grpc_client::GrpcClient;
use kaspa_rpc_core::{
    api::rpc::RpcApi,
    model::{GetServerInfoRequest, GetUtxosByAddressesRequest, RpcUtxoEntry},
};
use std::collections::{HashMap, HashSet};
use std::time::Instant;
use tracing::{debug, info};

pub async fn fetch_spendable_utxos(
    client: &GrpcClient,
    address: Address,
    config: &Config,
) -> Result<Vec<(TransactionOutpoint, CoreUtxoEntry)>> {
    let resp = client
        .get_utxos_by_addresses_call(None, GetUtxosByAddressesRequest {
            addresses: vec![address.clone()],
        })
        .await?;

    let server_info = client
        .get_server_info_call(None, GetServerInfoRequest {})
        .await?;

    let virtual_daa_score = server_info.virtual_daa_score;

    let mut utxos = Vec::with_capacity(resp.entries.len());

    for entry in resp.entries {
        if is_utxo_spendable(&entry.utxo_entry, virtual_daa_score, config) {
            assert!(entry.address.is_some());
            assert_eq!(*entry.address.as_ref().unwrap(), address);

            utxos.push((
                TransactionOutpoint::from(entry.outpoint),
                CoreUtxoEntry::from(entry.utxo_entry),
            ));
        }
    }

    // Sort by amount (largest first) for better fee handling
    utxos.sort_by(|a, b| b.1.amount.cmp(&a.1.amount));

    debug!(
        "Fetched {} spendable UTXOs (total: {} sompi)",
        utxos.len(),
        utxos.iter().map(|(_, e)| e.amount).sum::<u64>()
    );

    Ok(utxos)
}

fn is_utxo_spendable(entry: &RpcUtxoEntry, virtual_daa_score: u64, config: &Config) -> bool {
    let needed_confirmations = if !entry.is_coinbase {
        config.advanced.confirmation_depth
    } else {
        config.advanced.coinbase_maturity
    };

    entry.block_daa_score + needed_confirmations <= virtual_daa_score
}

pub struct UtxoManager {
    pub available: Vec<(TransactionOutpoint, CoreUtxoEntry)>,
    pub pending: HashMap<TransactionOutpoint, Instant>,
    pub spent: HashSet<TransactionOutpoint>,
    last_refresh: Instant,
    index: usize,
}

impl UtxoManager {
    pub fn new(utxos: Vec<(TransactionOutpoint, CoreUtxoEntry)>) -> Self {
        info!("Initialized UTXO manager with {} UTXOs", utxos.len());
        Self {
            available: utxos,
            pending: HashMap::new(),
            spent: HashSet::new(),
            last_refresh: Instant::now(),
            index: 0,
        }
    }

    pub fn needs_refresh(&self, config: &Config) -> bool {
        self.last_refresh.elapsed().as_secs() >= config.utxo.refresh_interval_secs
            || self.index >= self.available.len().saturating_sub(8)
    }

    pub async fn refresh(
        &mut self,
        client: &GrpcClient,
        address: Address,
        config: &Config,
    ) -> Result<()> {
        let mut fresh = fetch_spendable_utxos(client, address, config).await?;

        // Exclude already pending or spent UTXOs
        fresh.retain(|(op, _)| !self.pending.contains_key(op) && !self.spent.contains(op));

        let old_count = self.available.len();
        self.available = fresh;
        self.index = 0;
        self.last_refresh = Instant::now();

        info!(
            "Refreshed UTXOs: {} available (was {}), {} pending, {} spent",
            self.available.len(),
            old_count,
            self.pending.len(),
            self.spent.len()
        );

        Ok(())
    }

    pub fn get_batch(&mut self, count: usize) -> Vec<(TransactionOutpoint, CoreUtxoEntry)> {
        let available_count = self.available.len().saturating_sub(self.index);
        let batch_size = count.min(available_count);

        if batch_size == 0 {
            return Vec::new();
        }

        let batch = self.available[self.index..self.index + batch_size].to_vec();
        self.index += batch_size;

        batch
    }

    pub fn reserve(&mut self, outpoints: &[(TransactionOutpoint, CoreUtxoEntry)]) {
        let now = Instant::now();
        for (op, _) in outpoints {
            self.pending.insert(*op, now);
        }
    }

    pub fn mark_spent(&mut self, outpoint: TransactionOutpoint) {
        self.pending.remove(&outpoint);
        self.spent.insert(outpoint);
    }

    pub fn release(&mut self, outpoint: &TransactionOutpoint) {
        self.pending.remove(outpoint);
    }

    pub fn prune_old_pending(&mut self, max_age_secs: u64) {
        let now = Instant::now();
        let max_age = std::time::Duration::from_secs(max_age_secs);

        let old_count = self.pending.len();
        self.pending.retain(|_, timestamp| {
            now.duration_since(*timestamp) <= max_age
        });

        let pruned = old_count - self.pending.len();
        if pruned > 0 {
            debug!("Pruned {} old pending UTXOs", pruned);
        }
    }

    pub fn available_count(&self) -> usize {
        self.available.len().saturating_sub(self.index)
    }

    pub fn total_balance(&self) -> u64 {
        self.available.iter().map(|(_, e)| e.amount).sum()
    }
}