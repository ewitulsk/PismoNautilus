# Copyright (c), Mysten Labs, Inc.
# SPDX-License-Identifier: Apache-2.0
#!/bin/bash

# Gets the enclave id and CID
# expects there to be only one enclave running
ENCLAVE_ID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveID")
ENCLAVE_CID=$(nitro-cli describe-enclaves | jq -r ".[0].EnclaveCID")

# Check if enclave is running and CID is valid
if [ "$ENCLAVE_CID" = "null" ] || [ -z "$ENCLAVE_CID" ]; then
    echo "Error: No enclave running or invalid CID. Please ensure an enclave is running first."
    echo "Current enclave status:"
    nitro-cli describe-enclaves
    exit 1
fi

echo "Enclave ID: $ENCLAVE_ID"
echo "Enclave CID: $ENCLAVE_CID"

sleep 5

# Forward traffic from host port 3000 to enclave port 3000
echo "Setting up port forwarding: localhost:3000 -> enclave:3000"
socat TCP4-LISTEN:3000,reuseaddr,fork VSOCK-CONNECT:$ENCLAVE_CID:3000 &

echo "Port forwarding established. Enclave is now exposed on localhost:3000"
