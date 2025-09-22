use crate::config::{Config, Network};
use crate::error::{Result, TxGenError};
use kaspa_addresses::Address;
use kaspa_grpc_client::GrpcClient;
use kaspa_rpc_core::{
    api::rpc::RpcApi,
    model::{GetServerInfoRequest, GetServerInfoResponse},
};
use std::sync::Arc;
use tracing::{info, warn};

pub async fn create_client_pool(config: &Config) -> Result<Vec<Arc<GrpcClient>>> {
    let rpc_url = config.network.rpc_endpoint.clone()
        .unwrap_or_else(|| config.network.network.grpc_url());

    info!("Connecting to {} at {}", config.network.network.expected_hint(), rpc_url);

    let mut clients = Vec::with_capacity(config.advanced.client_pool_size);
    for i in 0..config.advanced.client_pool_size {
        let client = GrpcClient::connect(rpc_url.clone())
            .await
            .map_err(|e| TxGenError::Config(
                format!("Failed to connect to {}: {}", rpc_url, e)
            ))?;
        clients.push(Arc::new(client));

        if i == 0 {
            info!("Successfully connected to Kaspa node");
        }
    }

    info!("Created {} gRPC client connections", clients.len());
    Ok(clients)
}

pub async fn verify_network(
    client: &GrpcClient,
    network: Network,
    address: &Address,
) -> Result<GetServerInfoResponse> {
    let server_info = client
        .get_server_info_call(None, GetServerInfoRequest {})
        .await?;

    // Check address prefix matches network
    let expected_prefix = network.prefix();
    if address.prefix != expected_prefix {
        return Err(TxGenError::NetworkMismatch {
            address_prefix: format!("{:?}", address.prefix),
            network: format!("{:?}", network),
        });
    }

    // Check node's reported network matches expected
    let network_id = server_info.network_id.to_string().to_lowercase();
    let expected_hint = network.expected_hint();

    if !network_id.contains(expected_hint) {
        warn!(
            "Node reports network '{}', expected to contain '{}'",
            network_id, expected_hint
        );
        return Err(TxGenError::NodeNetworkMismatch {
            actual: network_id,
            expected: expected_hint.to_string(),
        });
    }

    info!(
        "Network verification successful: {} (DAA score: {})",
        network_id, server_info.virtual_daa_score
    );

    Ok(server_info)
}

pub async fn get_network_info(client: &GrpcClient) -> Result<GetServerInfoResponse> {
    client
        .get_server_info_call(None, GetServerInfoRequest {})
        .await
        .map_err(|e| e.into())
}