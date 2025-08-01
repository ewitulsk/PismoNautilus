#!/bin/sh
# Copyright (c), Mysten Labs, Inc.
# SPDX-License-Identifier: Apache-2.0

# - Setup script for nautilus-server that acts as an init script
# - Sets up Python and library paths
# - Configures loopback network and /etc/hosts
# - Waits for secrets.json to be passed from the parent instance. 
# - Forwards VSOCK port 3000 to localhost:3000
# - Optionally pulls secrets and sets in environmen variables.
# - Launches nautilus-server

set -e # Exit immediately if a command exits with a non-zero status
echo "run.sh script is running"
export PYTHONPATH=/lib/python3.11:/usr/local/lib/python3.11/lib-dynload:/usr/local/lib/python3.11/site-packages:/lib
export LD_LIBRARY_PATH=/lib:$LD_LIBRARY_PATH

echo "Script completed."
# Assign an IP address to local loopback
busybox ip addr add 127.0.0.1/32 dev lo
busybox ip link set dev lo up

# Configure /etc/hosts - only localhost, allowing unrestricted external access
echo "127.0.0.1   localhost" > /etc/hosts
echo "# Unrestricted configuration: external domains are resolved normally" >> /etc/hosts

cat /etc/hosts

# Get a json blob with key/value pair for secrets
JSON_RESPONSE=$(socat - VSOCK-LISTEN:7777,reuseaddr)
# Sets all key value pairs as env variables that will be referred by the server
# This is shown as a example below. For production usecases, it's best to set the
# keys explicitly rather than dynamically.
echo "$JSON_RESPONSE" | jq -r 'to_entries[] | "\(.key)=\(.value)"' > /tmp/kvpairs ; while IFS="=" read -r key value; do export "$key"="$value"; done < /tmp/kvpairs ; rm -f /tmp/kvpairs

# Configure unrestricted network access
echo "Setting up unrestricted network access..."

# Create a transparent proxy that forwards all external traffic to the host
# This allows the enclave to access any domain without pre-configuration
# The host will handle DNS resolution and external connectivity

# Set up transparent forwarding for HTTP and HTTPS traffic to any domain
# Traffic is forwarded via VSOCK to the host which handles the actual external requests
socat TCP-LISTEN:80,reuseaddr,fork VSOCK:3:8080 &     # HTTP proxy for any domain
socat TCP-LISTEN:443,reuseaddr,fork VSOCK:3:8443 &    # HTTPS proxy for any domain

# Additional ports for broader application compatibility
socat TCP-LISTEN:8080,reuseaddr,fork VSOCK:3:8081 &   # Alternative HTTP
socat TCP-LISTEN:8443,reuseaddr,fork VSOCK:3:8444 &   # Alternative HTTPS
socat TCP-LISTEN:9000,reuseaddr,fork VSOCK:3:9001 &   # Custom applications

echo "Unrestricted network access configured."
echo "The enclave can now access any external host via transparent proxying."

# Listens on Local VSOCK Port 3000 and forwards to localhost 3000
socat VSOCK-LISTEN:3000,reuseaddr,fork TCP:localhost:3000 &

# Set the config path to use the default config file
export CONFIG_PATH="/config/config.toml"

/nautilus-server
