use thiserror::Error;

#[derive(Error, Debug)]
pub enum TxGenError {
    #[error("Configuration error: {0}")]
    Config(String),

    #[error("Network mismatch: address prefix {address_prefix} does not match network {network}")]
    NetworkMismatch {
        address_prefix: String,
        network: String,
    },

    #[error("Node network mismatch: connected to {actual}, expected {expected}")]
    NodeNetworkMismatch {
        actual: String,
        expected: String,
    },

    #[error("Insufficient funds: need {required} KAS, have {available} KAS")]
    InsufficientFunds {
        required: f64,
        available: f64,
    },

    #[error("Invalid private key: {0}")]
    InvalidPrivateKey(String),

    #[error("RPC error: {0}")]
    Rpc(#[from] kaspa_grpc_client::error::Error),

    #[error("RPC core error: {0}")]
    RpcCore(#[from] kaspa_rpc_core::RpcError),

    #[error("Secp256k1 error: {0}")]
    Secp256k1(#[from] secp256k1::Error),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Parse error: {0}")]
    Parse(String),

    #[error("Transaction submission failed: {0}")]
    TransactionSubmission(String),

    #[error("UTXO management error: {0}")]
    UtxoManagement(String),

    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

pub type Result<T> = std::result::Result<T, TxGenError>;