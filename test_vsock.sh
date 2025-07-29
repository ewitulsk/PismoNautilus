#!/bin/bash
# Test script to debug VSOCK connection to enclave

set -e

echo "🔍 Testing VSOCK connection to enclave..."

# Get the enclave CID
ENCLAVE_CID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveCID")

if [ "$ENCLAVE_CID" = "null" ] || [ -z "$ENCLAVE_CID" ]; then
    echo "❌ Error: No enclave running"
    exit 1
fi

echo "✅ Found enclave CID: $ENCLAVE_CID"

# Test if we can connect to VSOCK port 3000
echo "🧪 Testing VSOCK connection to port 3000..."
timeout 5 socat - VSOCK-CONNECT:$ENCLAVE_CID:3000 <<< "GET /health_check HTTP/1.1\r\nHost: localhost\r\n\r\n" || echo "❌ VSOCK connection failed"

echo "🧪 Testing with curl through socat proxy..."
# Start a temporary socat proxy
socat TCP4-LISTEN:8888,reuseaddr,fork VSOCK-CONNECT:$ENCLAVE_CID:3000 &
PROXY_PID=$!

sleep 2

# Test the connection
curl -v --max-time 5 http://localhost:8888/health_check || echo "❌ HTTP connection through proxy failed"

# Clean up
kill $PROXY_PID 2>/dev/null || true

echo "🔍 Test complete" 