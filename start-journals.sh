#!/bin/bash

# Simple startup script for Journals Infrastructure
# Usage: ./start-journals.sh [passphrase]

set -e

# Get passphrase from command line argument or prompt
if [[ -n "$1" ]]; then
    export VAULT_PASSPHRASE="$1"
    echo "Using passphrase from command line argument"
else
    echo "Please enter your vault passphrase:"
    read -s passphrase
    export VAULT_PASSPHRASE="$passphrase"
    echo ""
fi

# Validate passphrase
if [[ -z "$VAULT_PASSPHRASE" ]]; then
    echo "ERROR: Passphrase cannot be empty"
    exit 1
fi

echo "Starting Journals Infrastructure with provided passphrase..."
echo ""

# Run the startup script
cd "$(dirname "$0")"
export LOG_LEVEL="DEBUG"
./bin/journals-up.sh
