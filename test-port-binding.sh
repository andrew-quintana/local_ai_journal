#!/bin/bash

# Test port binding verification
cd /Users/aq_home/1Projects/local_journal

# Source the docker manager
source src/docker/docker-manager.sh

echo "=== Testing Port Binding Verification ==="
echo ""

# Start containers
echo "Starting Docker containers..."
docker-compose -f src/docker/docker-compose.yml up -d

echo "Waiting for containers to start..."
sleep 15

echo "Checking port binding..."
if verify_port_binding; then
    echo "SUCCESS: Port binding verification passed"
else
    echo "FAILED: Port binding verification failed"
fi

echo ""
echo "Cleaning up..."
docker-compose -f src/docker/docker-compose.yml down
