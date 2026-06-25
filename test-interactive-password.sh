#!/bin/bash

# Interactive password capture and reuse test
VAULT_IMAGE_PATH="/Users/aq_home/JournalsVault.sparseimage"
VAULT_MOUNT_POINT="/Users/aq_home/Journals"

echo "=== Interactive Password Capture Test ==="
echo ""

# Unmount if already mounted
if mount | grep -q "$VAULT_MOUNT_POINT" 2>/dev/null; then
    echo "Unmounting existing vault..."
    hdiutil detach "$VAULT_MOUNT_POINT" 2>/dev/null || true
fi

echo "Step 1: Please enter the correct vault passphrase once:"
echo -n "Enter vault passphrase: "
stty -echo
read passphrase
stty echo
echo ""

# Validate passphrase
if [[ -z "$passphrase" ]]; then
    echo "ERROR: Passphrase cannot be empty"
    exit 1
fi

echo "Passphrase captured successfully!"
echo "Passphrase length: ${#passphrase}"
echo "Passphrase (hex): $(echo -n "$passphrase" | xxd -p)"
echo ""

# Test 1: Direct hdiutil command
echo "=== Test 1: Direct hdiutil command ==="
echo "Testing with direct hdiutil (this should work)..."
if hdiutil attach -mountpoint "$VAULT_MOUNT_POINT" "$VAULT_IMAGE_PATH" <<< "$passphrase"; then
    echo "SUCCESS: Direct hdiutil command worked"
    echo "Mount status:"
    mount | grep "$VAULT_MOUNT_POINT"
    echo ""
    echo "Unmounting for next test..."
    hdiutil detach "$VAULT_MOUNT_POINT" 2>/dev/null || true
else
    echo "FAILED: Direct hdiutil command failed"
fi

echo ""
echo "=== Test 2: Using echo -n method ==="
echo "Testing with echo -n and piped input..."
if echo -n "$passphrase" | hdiutil attach -stdinpass -mountpoint "$VAULT_MOUNT_POINT" "$VAULT_IMAGE_PATH" 2>&1; then
    echo "SUCCESS: echo -n method worked"
    echo "Mount status:"
    mount | grep "$VAULT_MOUNT_POINT"
    echo ""
    echo "Unmounting for next test..."
    hdiutil detach "$VAULT_MOUNT_POINT" 2>/dev/null || true
else
    echo "FAILED: echo -n method failed"
fi

echo ""
echo "=== Test 3: Using printf method ==="
echo "Testing with printf and piped input..."
if printf "%s" "$passphrase" | hdiutil attach -stdinpass -mountpoint "$VAULT_MOUNT_POINT" "$VAULT_IMAGE_PATH" 2>&1; then
    echo "SUCCESS: printf method worked"
    echo "Mount status:"
    mount | grep "$VAULT_MOUNT_POINT"
    echo ""
    echo "Unmounting for next test..."
    hdiutil detach "$VAULT_MOUNT_POINT" 2>/dev/null || true
else
    echo "FAILED: printf method failed"
fi

echo ""
echo "=== Test 4: Using expect method ==="
echo "Testing with expect..."
if command -v expect >/dev/null 2>&1; then
    if expect -c "
        spawn hdiutil attach -mountpoint $VAULT_MOUNT_POINT $VAULT_IMAGE_PATH
        expect \"Enter password to access\"
        send \"$passphrase\r\"
        expect eof
    " 2>/dev/null; then
        echo "SUCCESS: expect method worked"
        echo "Mount status:"
        mount | grep "$VAULT_MOUNT_POINT"
        echo ""
        echo "Unmounting for next test..."
        hdiutil detach "$VAULT_MOUNT_POINT" 2>/dev/null || true
    else
        echo "FAILED: expect method failed"
    fi
else
    echo "SKIPPED: expect command not available"
fi

echo ""
echo "=== Test 5: Using here document ==="
echo "Testing with here document..."
if hdiutil attach -mountpoint "$VAULT_MOUNT_POINT" "$VAULT_IMAGE_PATH" << EOF
$passphrase
EOF
then
    echo "SUCCESS: here document method worked"
    echo "Mount status:"
    mount | grep "$VAULT_MOUNT_POINT"
    echo ""
    echo "Unmounting..."
    hdiutil detach "$VAULT_MOUNT_POINT" 2>/dev/null || true
else
    echo "FAILED: here document method failed"
fi

echo ""
echo "=== All tests completed ==="
echo "The working method(s) will be used in the vault manager."

