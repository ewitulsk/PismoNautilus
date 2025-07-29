#!/bin/bash
# Simplified expose script for debugging

set -e

echo "🔍 Simple enclave exposure (API only)..."

# Get enclave CID
ENCLAVE_CID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveCID")

if [ "$ENCLAVE_CID" = "null" ] || [ -z "$ENCLAVE_CID" ]; then
    echo "❌ No enclave running"
    exit 1
fi

echo "✅ Enclave CID: $ENCLAVE_CID"

# Kill existing connections
pkill -f "socat.*TCP4-LISTEN:3000" 2>/dev/null || true
sleep 1

# Simple API forwarding only
echo "🚀 Starting simple API forwarding..."
socat TCP4-LISTEN:3000,reuseaddr,fork VSOCK-CONNECT:$ENCLAVE_CID:3000 &
API_PID=$!

echo "✅ API forwarding started (PID: $API_PID)"
echo "🌐 Test: curl http://localhost:3000/health_check"
echo "🛑 Stop: kill $API_PID" 