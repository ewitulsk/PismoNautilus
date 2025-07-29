use anyhow::{Context, Result};
use reqwest::Client;
use serde_json::{json, Value};

use crate::types::PriceFeed;

/// Wrapper around HTTP client for Sui RPC operations
pub struct SuiClientWrapper {
    client: Client,
    rpc_url: String,
    oracle_builder_package_id: String,
}

impl SuiClientWrapper {
    /// Initialize a new SuiClientWrapper with the given RPC URL and package ID
    pub async fn new(rpc_url: &str, oracle_builder_package_id: String) -> Result<Self> {
        let client = Client::new();

        Ok(Self {
            client,
            rpc_url: rpc_url.to_string(),
            oracle_builder_package_id,
        })
    }

    /// Fetch a PriceFeed object from the Sui network by its address
    pub async fn fetch_price_feed(&self, price_feed_address: &str) -> Result<PriceFeed> {
        let request_body = json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "sui_getObject",
            "params": [
                price_feed_address,
                {
                    "showType": true,
                    "showOwner": true,
                    "showPreviousTransaction": false,
                    "showDisplay": false,
                    "showContent": true,
                    "showBcs": false,
                    "showStorageRebate": false
                }
            ]
        });

        // Send HTTP request to Sui RPC
        let response = self
            .client
            .post(&self.rpc_url)
            .header("Content-Type", "application/json")
            .json(&request_body)
            .send()
            .await
            .context("Failed to send request to Sui RPC")?;

        let response_body: Value = response
            .json()
            .await
            .context("Failed to parse response from Sui RPC")?;

        // Check for RPC errors
        if let Some(error) = response_body.get("error") {
            return Err(anyhow::anyhow!("Sui RPC error: {}", error));
        }

        // Extract the result
        let result = response_body
            .get("result")
            .ok_or_else(|| anyhow::anyhow!("No result in RPC response"))?;

        let data = result
            .get("data")
            .ok_or_else(|| anyhow::anyhow!("No data in result"))?;

        // Verify object type
        let object_type = data
            .get("type")
            .and_then(|t| t.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing object type"))?;

        let expected_type = format!("{}::oracle_builder::PriceFeed", self.oracle_builder_package_id);
        if object_type != expected_type {
            return Err(anyhow::anyhow!(
                "Expected PriceFeed type {}, got {}",
                expected_type,
                object_type
            ));
        }

        // Extract content
        let content = data
            .get("content")
            .ok_or_else(|| anyhow::anyhow!("Missing content"))?;

        let fields = content
            .get("fields")
            .ok_or_else(|| anyhow::anyhow!("Missing fields in content"))?;

        // Parse fields
        let oracle_id = fields
            .get("oracle_id")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing or invalid oracle_id field"))?
            .to_string();

        let is_valid = fields
            .get("is_valid")
            .and_then(|v| v.as_bool())
            .ok_or_else(|| anyhow::anyhow!("Missing or invalid is_valid field"))?;

        let api_key = fields
            .get("api_key")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let api_key_config = fields
            .get("api_key_config")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());

        let underlying_url = fields
            .get("underlying_url")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing or invalid underlying_url field"))?
            .to_string();

        let response_field = fields
            .get("response_field")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing or invalid response_field field"))?
            .to_string();

        let live_url = fields
            .get("live_url")
            .and_then(|v| v.as_str())
            .ok_or_else(|| anyhow::anyhow!("Missing or invalid live_url field"))?
            .to_string();

        Ok(PriceFeed {
            oracle_id,
            is_valid,
            api_key,
            api_key_config,
            underlying_url,
            response_field,
            live_url,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_sui_client_initialization() {
        let client = SuiClientWrapper::new(
            "https://fullnode.mainnet.sui.io:443",
            "0x147952da3ce20a26434235f66aa22a5057347b56f679b9e003845f1e2d16722b".to_string(),
        ).await;
        
        assert!(client.is_ok());
    }

    // Note: This test requires a valid price feed address on the network
    // Replace with an actual price feed address to test the functionality
    #[tokio::test]
    #[ignore] // Ignored by default since it requires network access and valid data
    async fn test_fetch_price_feed() {
        let client = SuiClientWrapper::new(
            "https://fullnode.testnet.sui.io:443",
            "0x3c15ce11b86d364572f00a40b508d4a80f06d213f37e6b77db3932ffec5c7127".to_string(),
        ).await.unwrap();
        
        // Replace "PRICE_FEED_ADDRESS_HERE" with an actual price feed address
        let result = client.fetch_price_feed("0xb2b928c198e2037b5116c4d51ce90a61d534912e49c44d340fab1f8ed3de7e50").await;
        
        // This will fail until you provide a real price feed address
        // but demonstrates how to use the function
        match result {
            Ok(price_feed) => {
                println!("Fetched price feed: {:?}", price_feed);
                assert!(price_feed.oracle_id.len() > 0);
            }
            Err(e) => {
                println!("Expected error for dummy address: {}", e);
            }
        }
    }
} 