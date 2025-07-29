use anyhow::Result;
use fastcrypto::{ed25519::Ed25519KeyPair, traits::KeyPair};
use std::sync::Arc;

use crate::config::{load_config, Config};
use crate::sui::SuiClientWrapper;

/// App state, at minimum needs to maintain the ephemeral keypair.  
pub struct AppState {
    /// Ephemeral keypair on boot
    pub eph_kp: Ed25519KeyPair,
    /// Configuration loaded from file
    pub config: Config,
    /// Sui client wrapper for oracle builder operations
    pub sui_client: SuiClientWrapper,
}

impl AppState {
    /// Initialize AppState with generated keypair, loaded configuration and Sui client
    pub async fn new() -> Result<Arc<AppState>> {
        let eph_kp = Ed25519KeyPair::generate(&mut rand::thread_rng());
        let config = load_config()?;
        
        // Initialize Sui client with config values
        let sui_client = SuiClientWrapper::new(
            &config.sui.rpc_url,
            config.sui.oracle_builder_package_id.clone(),
        ).await?;
        
        Ok(Arc::new(AppState { 
            eph_kp, 
            config,
            sui_client,
        }))
    }
} 