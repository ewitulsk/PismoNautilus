#!/bin/bash
# Copyright (c), Mysten Labs, Inc.
# SPDX-License-Identifier: Apache-2.0

# Host-side script to enable unrestricted internet access for AWS Nitro Enclaves
# This script sets up VSOCK-to-internet forwarding that complements the enclave's
# internal proxy configuration.
#
# USAGE: Run this script on the HOST (not inside the enclave) after starting the enclave
# ./setup_host_internet_proxy.sh

set -e

echo "🌐 Setting up host-side internet proxy for enclave..."

# Get the enclave CID - expects there to be only one enclave running
ENCLAVE_CID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveCID")

# Check if enclave is running and CID is valid
if [ "$ENCLAVE_CID" = "null" ] || [ -z "$ENCLAVE_CID" ]; then
    echo "❌ Error: No enclave running or invalid CID. Please ensure an enclave is running first."
    echo "Current enclave status:"
    nitro-cli describe-enclaves
    exit 1
fi

echo "✅ Found enclave with CID: $ENCLAVE_CID"

# Kill any existing proxy processes to avoid conflicts
echo "🧹 Cleaning up any existing proxy processes..."
pkill -f "vsock-proxy.*808" 2>/dev/null || true
pkill -f "socat.*VSOCK.*808" 2>/dev/null || true
pkill -f "socat.*VSOCK.*844" 2>/dev/null || true
pkill -f "socat.*VSOCK.*900" 2>/dev/null || true

# Wait a moment for processes to terminate
sleep 2

echo "🔧 Setting up VSOCK-to-Internet forwarding..."

# Set up VSOCK listeners that forward traffic to the actual internet
# These correspond to the VSOCK destinations in the enclave's run.sh script

# HTTP proxy - forwards from enclave's VSOCK:3:8080 to internet HTTP
echo "📡 Starting HTTP proxy (enclave port 80 -> internet)"
socat VSOCK-LISTEN:8080,reuseaddr,fork TCP:0.0.0.0:80 &
HTTP_PID=$!

# HTTPS proxy - forwards from enclave's VSOCK:3:8443 to internet HTTPS  
echo "🔒 Starting HTTPS proxy (enclave port 443 -> internet)"
socat VSOCK-LISTEN:8443,reuseaddr,fork TCP:0.0.0.0:443 &
HTTPS_PID=$!

# Alternative HTTP proxy - forwards from enclave's VSOCK:3:8081 to internet HTTP on port 8080
echo "📡 Starting alternative HTTP proxy (enclave port 8080 -> internet)"
socat VSOCK-LISTEN:8081,reuseaddr,fork TCP:0.0.0.0:8080 &
ALT_HTTP_PID=$!

# Alternative HTTPS proxy - forwards from enclave's VSOCK:3:8444 to internet HTTPS on port 8443
echo "🔒 Starting alternative HTTPS proxy (enclave port 8443 -> internet)"
socat VSOCK-LISTEN:8444,reuseaddr,fork TCP:0.0.0.0:8443 &
ALT_HTTPS_PID=$!

# Custom applications proxy - forwards from enclave's VSOCK:3:9001 to internet on port 9000
echo "🔧 Starting custom applications proxy (enclave port 9000 -> internet)"
socat VSOCK-LISTEN:9001,reuseaddr,fork TCP:0.0.0.0:9000 &
CUSTOM_PID=$!

# Give the processes a moment to start
sleep 2

# Verify the proxy processes are running
echo "🔍 Verifying proxy processes..."
RUNNING_COUNT=0

if kill -0 $HTTP_PID 2>/dev/null; then
    echo "✅ HTTP proxy (PID: $HTTP_PID) - running"
    ((RUNNING_COUNT++))
else
    echo "❌ HTTP proxy failed to start"
fi

if kill -0 $HTTPS_PID 2>/dev/null; then
    echo "✅ HTTPS proxy (PID: $HTTPS_PID) - running"
    ((RUNNING_COUNT++))
else
    echo "❌ HTTPS proxy failed to start"
fi

if kill -0 $ALT_HTTP_PID 2>/dev/null; then
    echo "✅ Alternative HTTP proxy (PID: $ALT_HTTP_PID) - running"
    ((RUNNING_COUNT++))
else
    echo "❌ Alternative HTTP proxy failed to start"
fi

if kill -0 $ALT_HTTPS_PID 2>/dev/null; then
    echo "✅ Alternative HTTPS proxy (PID: $ALT_HTTPS_PID) - running"
    ((RUNNING_COUNT++))
else
    echo "❌ Alternative HTTPS proxy failed to start"
fi

if kill -0 $CUSTOM_PID 2>/dev/null; then
    echo "✅ Custom applications proxy (PID: $CUSTOM_PID) - running"
    ((RUNNING_COUNT++))
else
    echo "❌ Custom applications proxy failed to start"
fi

if [ $RUNNING_COUNT -eq 5 ]; then
    echo ""
    echo "🎉 SUCCESS! All proxy processes are running."
    echo "📱 The enclave now has unrestricted internet access."
    echo ""
    echo "📝 Active proxy processes:"
    echo "   HTTP:           VSOCK:8080 -> Internet:80       (PID: $HTTP_PID)"
    echo "   HTTPS:          VSOCK:8443 -> Internet:443      (PID: $HTTPS_PID)"
    echo "   Alt HTTP:       VSOCK:8081 -> Internet:8080     (PID: $ALT_HTTP_PID)"
    echo "   Alt HTTPS:      VSOCK:8444 -> Internet:8443     (PID: $ALT_HTTPS_PID)"
    echo "   Custom Apps:    VSOCK:9001 -> Internet:9000     (PID: $CUSTOM_PID)"
    echo ""
    echo "🛑 To stop all proxies, run:"
    echo "   kill $HTTP_PID $HTTPS_PID $ALT_HTTP_PID $ALT_HTTPS_PID $CUSTOM_PID"
    echo ""
    echo "🔍 To monitor proxy activity:"
    echo "   netstat -tulpn | grep socat"
    echo ""
else
    echo ""
    echo "⚠️  WARNING: Only $RUNNING_COUNT out of 5 proxy processes started successfully."
    echo "   This may limit internet connectivity from the enclave."
    echo "   Check the error messages above and system logs for more details."
    echo ""
fi

# Save PIDs to a file for easy cleanup later
echo "💾 Saving proxy PIDs to /tmp/enclave_proxy_pids.txt"
cat > /tmp/enclave_proxy_pids.txt << EOF
# Enclave Internet Proxy PIDs - $(date)
# To stop all proxies: kill \$(cat /tmp/enclave_proxy_pids.txt | grep -v '^#' | xargs)
$HTTP_PID
$HTTPS_PID  
$ALT_HTTP_PID
$ALT_HTTPS_PID
$CUSTOM_PID
EOF

echo "📋 Proxy setup complete. The enclave should now have full internet access!"
echo "   Use 'cat /tmp/enclave_proxy_pids.txt' to see saved PIDs"
echo "   Use 'kill \$(cat /tmp/enclave_proxy_pids.txt | grep -v \"^#\" | xargs)' to stop all proxies" 