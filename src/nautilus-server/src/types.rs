use serde::{Deserialize, Serialize};

/// PriceFeed type that matches the on-chain Move struct exactly
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PriceFeed {
    pub oracle_id: String,
    pub is_valid: bool,
    pub api_key: Option<String>,
    pub api_key_config: Option<String>,
    pub underlying_url: String,
    pub response_field: String,
    pub live_url: String,
} 