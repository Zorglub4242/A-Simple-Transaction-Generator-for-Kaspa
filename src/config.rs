use crate::error::{Result, TxGenError};
use clap::{Parser, ValueEnum};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, ValueEnum, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Network {
    Mainnet,
    #[value(alias = "tn10")]
    Testnet10,
}

impl Network {
    pub fn grpc_url(&self) -> String {
        match self {
            Network::Mainnet => "grpc://n-mainnet.kaspa.ws:16110".to_string(),
            Network::Testnet10 => "grpc://n-testnet-10.kaspa.ws:16210".to_string(),
        }
    }

    pub fn prefix(&self) -> kaspa_addresses::Prefix {
        match self {
            Network::Mainnet => kaspa_addresses::Prefix::Mainnet,
            Network::Testnet10 => kaspa_addresses::Prefix::Testnet,
        }
    }

    pub fn expected_hint(&self) -> &'static str {
        match self {
            Network::Mainnet => "mainnet",
            Network::Testnet10 => "testnet-10",
        }
    }
}

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    /// Network to use (mainnet or testnet10/tn10)
    #[arg(short, long, value_enum, default_value = "testnet10")]
    pub network: Network,

    /// Configuration file path
    #[arg(short, long, value_name = "FILE")]
    pub config: Option<PathBuf>,

    /// Private key (overrides environment variable)
    #[arg(short = 'k', long, env = "PRIVATE_KEY_HEX")]
    pub private_key: Option<String>,

    /// RPC endpoint (overrides config file)
    #[arg(short = 'r', long)]
    pub rpc_endpoint: Option<String>,

    /// Target transactions per second
    #[arg(short = 't', long)]
    pub target_tps: Option<u64>,

    /// Duration in seconds (0 = run forever)
    #[arg(short = 'd', long)]
    pub duration: Option<u64>,

    /// Log level (error, warn, info, debug, trace)
    #[arg(short = 'l', long, default_value = "info")]
    pub log_level: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub network: NetworkConfig,

    #[serde(default)]
    pub utxo: UtxoConfig,

    #[serde(default)]
    pub spam: SpamConfig,

    #[serde(default)]
    pub fees: FeeConfig,

    #[serde(default)]
    pub advanced: AdvancedConfig,

    #[serde(default)]
    pub logging: LoggingConfig,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NetworkConfig {
    #[serde(default = "default_network")]
    pub network: Network,
    pub rpc_endpoint: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UtxoConfig {
    #[serde(default = "default_target_utxo_count")]
    pub target_utxo_count: usize,

    #[serde(default = "default_amount_per_utxo")]
    pub amount_per_utxo: u64,

    #[serde(default = "default_outputs_per_transaction")]
    pub outputs_per_transaction: usize,

    #[serde(default = "default_min_change_sompi")]
    pub min_change_sompi: u64,

    #[serde(default = "default_refresh_interval_secs")]
    pub refresh_interval_secs: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SpamConfig {
    #[serde(default = "default_target_tps")]
    pub target_tps: u64,

    #[serde(default = "default_duration_seconds")]
    pub duration_seconds: u64,

    #[serde(default = "default_unleashed")]
    pub unleashed: bool,

    #[serde(default = "default_millis_per_tick")]
    pub millis_per_tick: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FeeConfig {
    #[serde(default = "default_base_fee_rate")]
    pub base_fee_rate: u64,

    #[serde(default = "default_splitting_fee_rate")]
    pub splitting_fee_rate: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AdvancedConfig {
    #[serde(default = "default_client_pool_size")]
    pub client_pool_size: usize,

    #[serde(default = "default_max_pending_age_secs")]
    pub max_pending_age_secs: u64,

    #[serde(default = "default_max_inflight")]
    pub max_inflight: usize,

    #[serde(default = "default_coinbase_maturity")]
    pub coinbase_maturity: u64,

    #[serde(default = "default_confirmation_depth")]
    pub confirmation_depth: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LoggingConfig {
    #[serde(default = "default_log_level")]
    pub level: String,

    pub log_file: Option<String>,

    #[serde(default = "default_colored")]
    pub colored: bool,

    #[serde(default = "default_timestamps")]
    pub timestamps: bool,
}

// Default value functions
fn default_network() -> Network { Network::Testnet10 }
fn default_target_utxo_count() -> usize { 100 }
fn default_amount_per_utxo() -> u64 { 150_000_000 }
fn default_outputs_per_transaction() -> usize { 10 }
fn default_min_change_sompi() -> u64 { 1_000_000 }
fn default_refresh_interval_secs() -> u64 { 1 }
fn default_target_tps() -> u64 { 50 }
fn default_duration_seconds() -> u64 { 86_400 }
fn default_unleashed() -> bool { false }
fn default_millis_per_tick() -> u64 { 10 }
fn default_base_fee_rate() -> u64 { 1 }
fn default_splitting_fee_rate() -> u64 { 10 }
fn default_client_pool_size() -> usize { 8 }
fn default_max_pending_age_secs() -> u64 { 3600 }
fn default_max_inflight() -> usize { 20_000 }
fn default_coinbase_maturity() -> u64 { 100 }
fn default_confirmation_depth() -> u64 { 10 }
fn default_log_level() -> String { "info".to_string() }
fn default_colored() -> bool { true }
fn default_timestamps() -> bool { true }

// Default implementations
impl Default for NetworkConfig {
    fn default() -> Self {
        Self {
            network: default_network(),
            rpc_endpoint: None,
        }
    }
}

impl Default for UtxoConfig {
    fn default() -> Self {
        Self {
            target_utxo_count: default_target_utxo_count(),
            amount_per_utxo: default_amount_per_utxo(),
            outputs_per_transaction: default_outputs_per_transaction(),
            min_change_sompi: default_min_change_sompi(),
            refresh_interval_secs: default_refresh_interval_secs(),
        }
    }
}

impl Default for SpamConfig {
    fn default() -> Self {
        Self {
            target_tps: default_target_tps(),
            duration_seconds: default_duration_seconds(),
            unleashed: default_unleashed(),
            millis_per_tick: default_millis_per_tick(),
        }
    }
}

impl Default for FeeConfig {
    fn default() -> Self {
        Self {
            base_fee_rate: default_base_fee_rate(),
            splitting_fee_rate: default_splitting_fee_rate(),
        }
    }
}

impl Default for AdvancedConfig {
    fn default() -> Self {
        Self {
            client_pool_size: default_client_pool_size(),
            max_pending_age_secs: default_max_pending_age_secs(),
            max_inflight: default_max_inflight(),
            coinbase_maturity: default_coinbase_maturity(),
            confirmation_depth: default_confirmation_depth(),
        }
    }
}

impl Default for LoggingConfig {
    fn default() -> Self {
        Self {
            level: default_log_level(),
            log_file: None,
            colored: default_colored(),
            timestamps: default_timestamps(),
        }
    }
}

impl Default for Config {
    fn default() -> Self {
        Self {
            network: NetworkConfig::default(),
            utxo: UtxoConfig::default(),
            spam: SpamConfig::default(),
            fees: FeeConfig::default(),
            advanced: AdvancedConfig::default(),
            logging: LoggingConfig::default(),
        }
    }
}

pub fn load_config(cli: &Cli) -> Result<(Config, String)> {
    // Load .env file if it exists
    dotenv::dotenv().ok();

    // Load config file
    let mut config = if let Some(config_path) = &cli.config {
        let config_str = std::fs::read_to_string(config_path)
            .map_err(|e| TxGenError::Config(format!("Failed to read config file: {}", e)))?;
        toml::from_str(&config_str)
            .map_err(|e| TxGenError::Config(format!("Failed to parse config file: {}", e)))?
    } else if std::path::Path::new("config.toml").exists() {
        let config_str = std::fs::read_to_string("config.toml")
            .map_err(|e| TxGenError::Config(format!("Failed to read config.toml: {}", e)))?;
        toml::from_str(&config_str)
            .map_err(|e| TxGenError::Config(format!("Failed to parse config.toml: {}", e)))?
    } else {
        Config::default()
    };

    // Apply CLI overrides
    config.network.network = cli.network;

    if let Some(rpc) = &cli.rpc_endpoint {
        config.network.rpc_endpoint = Some(rpc.clone());
    }

    if let Some(tps) = cli.target_tps {
        config.spam.target_tps = tps;
    }

    if let Some(duration) = cli.duration {
        config.spam.duration_seconds = duration;
    }

    config.logging.level = cli.log_level.clone();

    // Get private key from CLI, env, or error
    let private_key = cli.private_key.clone()
        .or_else(|| std::env::var("PRIVATE_KEY_HEX").ok())
        .ok_or_else(|| TxGenError::Config(
            "Private key not provided. Set PRIVATE_KEY_HEX environment variable or use --private-key".to_string()
        ))?;

    // Validate private key format
    if private_key.len() != 64 || hex::decode(&private_key).is_err() {
        return Err(TxGenError::InvalidPrivateKey(
            "Private key must be 64 hexadecimal characters".to_string()
        ));
    }

    Ok((config, private_key))
}