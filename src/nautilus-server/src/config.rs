use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use tracing::{error, info};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Config {
    pub sui: Sui,
    pub response: Response,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Sui {
    pub rpc_url: String,
    pub oracle_builder_package_id: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Response {
    pub price_decimals: u32,
}

pub fn load_config() -> Result<Config> {
    let config_path = std::env::var("CONFIG_PATH").map_err(|_| {
        let error_msg = "CONFIG_PATH environment variable is not set";
        error!("{}", error_msg);
        anyhow::anyhow!(error_msg)
    })?;

    info!("Loading config from: {}", config_path);

    let config_content = fs::read_to_string(&config_path)
        .with_context(|| format!("Failed to read config file at: {}", config_path))?;

    let config: Config = toml::from_str(&config_content)
        .with_context(|| format!("Failed to parse config file at: {}", config_path))?;

    info!("Config loaded successfully");
    Ok(config)
}
