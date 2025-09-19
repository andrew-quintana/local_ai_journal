#!/usr/bin/env bash
# Debug script for vault issues

set -euo pipefail

VAULT_IMAGE_PATH="${HOME}/JournalsVault.sparseimage"
VAULT_MOUNT_POINT="${HOME}/Journals"

echo "=== Vault Debug Information ==="
echo

echo "1. Checking if vault image exists:"
if [[ -f "$VAULT_IMAGE_PATH" ]]; then
    echo "✅ Vault image exists: $VAULT_IMAGE_PATH"
    ls -la "$VAULT_IMAGE_PATH"
else
    echo "❌ Vault image not found: $VAULT_IMAGE_PATH"
    exit 1
fi

echo
echo "2. Checking vault image info:"
if hdiutil imageinfo "$VAULT_IMAGE_PATH" 2>&1; then
    echo "✅ Vault image info retrieved successfully"
else
    echo "❌ Failed to get vault image info"
fi

echo
echo "3. Checking if vault is already mounted:"
if mount | grep -q "$VAULT_MOUNT_POINT"; then
    echo "⚠️  Vault is already mounted at: $VAULT_MOUNT_POINT"
    mount | grep "$VAULT_MOUNT_POINT"
else
    echo "✅ Vault is not currently mounted"
fi

echo
echo "4. Testing manual mount (this will prompt for passphrase):"
echo "Attempting to mount vault manually..."
if echo -n "test" | hdiutil attach -stdinpass -mountpoint "$VAULT_MOUNT_POINT" "$VAULT_IMAGE_PATH" 2>&1; then
    echo "✅ Manual mount test successful"
    hdiutil detach "$VAULT_MOUNT_POINT" 2>/dev/null || true
else
    echo "❌ Manual mount test failed"
fi

echo
echo "=== Debug Complete ==="
