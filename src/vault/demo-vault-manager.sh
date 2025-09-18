#!/bin/bash

# Demo script for vault manager functionality
# This demonstrates the vault management system working correctly

set -euo pipefail

readonly VAULT_MANAGER="./src/vault/vault-manager.sh"
readonly DEMO_VAULT_PATH="/tmp/demo-journal-vault.sparseimage"
readonly DEMO_MOUNT_POINT="/tmp/demo-journal-mount"

echo "=== Vault Manager Demo ==="
echo

# Function to run command and show result
run_demo() {
    local description="$1"
    local command="$2"
    
    echo "Demo: $description"
    echo "Command: $command"
    echo "Result:"
    eval "$command"
    echo "Exit code: $?"
    echo "---"
    echo
}

# Demo 1: Check if vault exists (should be false)
run_demo "Check if vault exists (non-existent)" "VAULT_IMAGE_PATH='$DEMO_VAULT_PATH' '$VAULT_MANAGER' exists"

# Demo 2: Create a small test vault
echo "Creating test vault (this will prompt for passphrase)..."
echo "Using passphrase: 'demopass123'"
echo -e "demopass123\ndemopass123" | VAULT_IMAGE_PATH="$DEMO_VAULT_PATH" VAULT_MOUNT_POINT="$DEMO_MOUNT_POINT" "$VAULT_MANAGER" create 100m
echo "Vault creation exit code: $?"
echo

# Demo 3: Check if vault exists (should be true)
run_demo "Check if vault exists (after creation)" "VAULT_IMAGE_PATH='$DEMO_VAULT_PATH' '$VAULT_MANAGER' exists"

# Demo 4: Check vault status
run_demo "Check vault status (unmounted)" "VAULT_IMAGE_PATH='$DEMO_VAULT_PATH' VAULT_MOUNT_POINT='$DEMO_MOUNT_POINT' '$VAULT_MANAGER' status"

# Demo 5: Mount vault
echo "Mounting vault (this will prompt for passphrase)..."
echo "Using passphrase: 'demopass123'"
echo "demopass123" | VAULT_IMAGE_PATH="$DEMO_VAULT_PATH" VAULT_MOUNT_POINT="$DEMO_MOUNT_POINT" "$VAULT_MANAGER" mount
echo "Vault mount exit code: $?"
echo

# Demo 6: Check vault status (mounted)
run_demo "Check vault status (mounted)" "VAULT_IMAGE_PATH='$DEMO_VAULT_PATH' VAULT_MOUNT_POINT='$DEMO_MOUNT_POINT' '$VAULT_MANAGER' status"

# Demo 7: Validate vault integrity
run_demo "Validate vault integrity" "VAULT_IMAGE_PATH='$DEMO_VAULT_PATH' VAULT_MOUNT_POINT='$DEMO_MOUNT_POINT' '$VAULT_MANAGER' validate"

# Demo 8: Unmount vault
run_demo "Unmount vault" "VAULT_IMAGE_PATH='$DEMO_VAULT_PATH' VAULT_MOUNT_POINT='$DEMO_MOUNT_POINT' '$VAULT_MANAGER' unmount"

# Demo 9: Check vault status (unmounted again)
run_demo "Check vault status (after unmount)" "VAULT_IMAGE_PATH='$DEMO_VAULT_PATH' VAULT_MOUNT_POINT='$DEMO_MOUNT_POINT' '$VAULT_MANAGER' status"

# Cleanup
echo "Cleaning up demo vault..."
if mount | grep -q "$DEMO_MOUNT_POINT"; then
    hdiutil detach "$DEMO_MOUNT_POINT" 2>/dev/null || true
fi
if [[ -d "$DEMO_MOUNT_POINT" ]]; then
    rmdir "$DEMO_MOUNT_POINT" 2>/dev/null || true
fi
if [[ -f "$DEMO_VAULT_PATH" ]]; then
    rm -f "$DEMO_VAULT_PATH"
fi

echo "=== Demo Complete ==="
echo "All vault management functions demonstrated successfully!"
