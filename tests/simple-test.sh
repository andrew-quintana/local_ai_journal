#!/bin/bash

# Simple test for vault manager
set -euo pipefail

readonly VAULT_MANAGER="./src/vault/vault-manager.sh"
readonly TEST_VAULT_PATH="/tmp/simple-test-vault.sparseimage"
readonly TEST_MOUNT_POINT="/tmp/simple-test-mount"

echo "Testing vault manager..."

# Test 1: Check if vault exists (should be false)
echo "Test 1: vault_exists with non-existent vault"
VAULT_IMAGE_PATH="$TEST_VAULT_PATH" "$VAULT_MANAGER" exists
echo "Exit code: $?"

# Test 2: Create vault
echo "Test 2: Creating vault"
echo -e "testpass123\ntestpass123" | VAULT_IMAGE_PATH="$TEST_VAULT_PATH" VAULT_MOUNT_POINT="$TEST_MOUNT_POINT" "$VAULT_MANAGER" create 1g
echo "Exit code: $?"

# Test 3: Check if vault exists (should be true)
echo "Test 3: vault_exists with existing vault"
VAULT_IMAGE_PATH="$TEST_VAULT_PATH" "$VAULT_MANAGER" exists
echo "Exit code: $?"

# Test 4: Check vault status
echo "Test 4: vault_status"
VAULT_IMAGE_PATH="$TEST_VAULT_PATH" VAULT_MOUNT_POINT="$TEST_MOUNT_POINT" "$VAULT_MANAGER" status

# Cleanup
echo "Cleaning up..."
if mount | grep -q "$TEST_MOUNT_POINT"; then
    hdiutil detach "$TEST_MOUNT_POINT" 2>/dev/null || true
fi
if [[ -d "$TEST_MOUNT_POINT" ]]; then
    rmdir "$TEST_MOUNT_POINT" 2>/dev/null || true
fi
if [[ -f "$TEST_VAULT_PATH" ]]; then
    rm -f "$TEST_VAULT_PATH"
fi

echo "Test completed successfully!"
