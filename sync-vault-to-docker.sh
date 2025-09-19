#!/bin/bash
# Sync vault files to Docker volume

set -e

VAULT_PATH="/Users/aq_home/Journals"
VOLUME_NAME="journals-data"

echo "Syncing vault files to Docker volume..."

# Create a temporary container to access the volume
docker run --rm -v "$VOLUME_NAME":/data -v "$VAULT_PATH":/vault alpine sh -c "
    echo 'Clearing existing volume data...'
    rm -rf /data/*
    
    echo 'Copying vault files to volume...'
    cp -r /vault/* /data/ 2>/dev/null || true
    
    echo 'Setting proper permissions...'
    chown -R 1000:1000 /data
    
    echo 'Sync completed!'
    ls -la /data
"

echo "Vault files synced to Docker volume: $VOLUME_NAME"
