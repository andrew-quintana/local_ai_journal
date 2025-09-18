# Vault Management System Documentation

## Overview

The Vault Management System provides secure, encrypted storage for journal data using APFS sparse images with AES-256 encryption. This system ensures complete privacy and data security through atomic operations, comprehensive error handling, and interactive passphrase management.

## Security Features

### Data Protection
- **AES-256 Encryption**: All vault data encrypted using industry-standard encryption
- **APFS Filesystem**: Modern filesystem with built-in encryption support
- **Interactive Passphrases**: No passphrase storage or logging
- **Atomic Operations**: All operations are atomic with rollback capability

### Privacy Guarantees
- **No External Access**: All operations are local to the system
- **No Data Logging**: Journal content never appears in logs
- **Secure Cleanup**: Temporary files and sensitive data properly cleaned up
- **Read-Only AI Access**: AI systems can only read, never modify journal data

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Vault Management System                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Vault         │    │   Security      │                │
│  │   Operations    │◄──►│   Controls      │                │
│  │                 │    │                 │                │
│  │ • Create        │    │ • Passphrase    │                │
│  │ • Mount         │    │ • Encryption    │                │
│  │ • Unmount       │    │ • Validation    │                │
│  │ • Status        │    │ • Cleanup       │                │
│  │ • Validate      │    │                 │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           ▼                       ▼                        │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   APFS          │    │   Error         │                │
│  │   Sparse        │◄──►│   Handling      │                │
│  │   Image         │    │                 │                │
│  │                 │    │ • Rollback      │                │
│  │ • AES-256       │    │ • Recovery      │                │
│  │ • Atomic Ops    │    │ • Validation    │                │
│  │ • Integrity     │    │ • Cleanup       │                │
│  └─────────────────┘    └─────────────────┘                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Core Functions

### vault_exists()
**Purpose**: Check if a vault file exists at the specified location.

**Signature**: `vault_exists() -> boolean`

**Returns**: 
- `true` if vault file exists
- `false` if vault file does not exist

**Example**:
```bash
if vault_exists; then
    echo "Vault exists"
else
    echo "Vault not found"
fi
```

### vault_create(size, location)
**Purpose**: Create a new encrypted vault with atomic operation and rollback capability.

**Signature**: `vault_create(size, location) -> exit_code`

**Parameters**:
- `size`: Vault size (e.g., "10g", "5g", "1t")
- `location`: Path where vault will be created

**Returns**:
- `0` on success
- `1` on failure

**Security Features**:
- Interactive passphrase entry with confirmation
- Atomic creation in temporary location first
- Integrity verification before final placement
- Automatic cleanup on failure

**Example**:
```bash
vault_create "5g" "${HOME}/MyJournal.sparseimage"
```

### vault_mount()
**Purpose**: Mount an existing vault with interactive passphrase entry.

**Signature**: `vault_mount() -> exit_code`

**Returns**:
- `0` on success
- `1` on failure

**Security Features**:
- Interactive passphrase entry (no storage)
- Mount point creation if needed
- Verification of successful mount
- Idempotent operation (safe to call multiple times)

**Example**:
```bash
vault_mount
```

### vault_unmount()
**Purpose**: Unmount a mounted vault safely.

**Signature**: `vault_unmount() -> exit_code`

**Returns**:
- `0` on success
- `1` on failure

**Security Features**:
- Safe unmount with verification
- Idempotent operation
- Cleanup of mount point if appropriate

**Example**:
```bash
vault_unmount
```

### vault_status()
**Purpose**: Get the current status of the vault.

**Signature**: `vault_status() -> {mounted|unmounted|error}`

**Returns**:
- `"mounted"` if vault is currently mounted
- `"unmounted"` if vault exists but is not mounted
- `"error"` if vault does not exist or error occurred

**Example**:
```bash
status=$(vault_status)
case "$status" in
    "mounted") echo "Vault is ready for use" ;;
    "unmounted") echo "Vault needs to be mounted" ;;
    "error") echo "Vault error occurred" ;;
esac
```

### vault_validate_integrity()
**Purpose**: Validate vault integrity and detect corruption.

**Signature**: `vault_validate_integrity() -> exit_code`

**Returns**:
- `0` on success (vault is intact)
- `1` on failure (corruption detected or other error)

**Security Features**:
- Filesystem integrity checking
- Mount verification
- Read access validation
- Automatic mount/unmount if needed

**Example**:
```bash
if vault_validate_integrity; then
    echo "Vault integrity verified"
else
    echo "Vault integrity check failed"
fi
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VAULT_IMAGE_PATH` | `~/JournalsVault.sparseimage` | Path to vault image file |
| `VAULT_MOUNT_POINT` | `~/Journals` | Mount point for vault |
| `VAULT_SIZE` | `10g` | Default vault size |
| `LOG_LEVEL` | `INFO` | Logging level (ERROR, WARN, INFO, SUCCESS) |
| `LOG_FILE` | `/tmp/vault-manager.log` | Log file path |

### Configuration File

The system can use a configuration file at `config/vault.conf` to set default values. Environment variables always override configuration file values.

## Usage Examples

### Basic Vault Operations

```bash
#!/bin/bash
# Source the vault manager
source ./scripts/vault-manager.sh

# Check if vault exists
if vault_exists; then
    echo "Vault found"
else
    echo "Creating new vault..."
    vault_create "5g" "${HOME}/MyJournal.sparseimage"
fi

# Mount the vault
if vault_mount; then
    echo "Vault mounted successfully"
    # Use the vault...
    vault_unmount
else
    echo "Failed to mount vault"
fi
```

### Command Line Usage

```bash
# Check if vault exists
./scripts/vault-manager.sh exists

# Create a new vault
./scripts/vault-manager.sh create 5g ~/MyJournal.sparseimage

# Mount vault
./scripts/vault-manager.sh mount

# Check vault status
./scripts/vault-manager.sh status

# Validate vault integrity
./scripts/vault-manager.sh validate

# Unmount vault
./scripts/vault-manager.sh unmount

# Show help
./scripts/vault-manager.sh help
```

### Integration with Journal System

```bash
#!/bin/bash
# journals-up.sh - Start journaling session

source ./scripts/vault-manager.sh

# Ensure vault is mounted
if [[ "$(vault_status)" != "mounted" ]]; then
    echo "Mounting journal vault..."
    if ! vault_mount; then
        echo "Failed to mount vault. Exiting."
        exit 1
    fi
fi

# Start Docker services
docker-compose up -d

echo "Journal system ready at http://localhost:3000"
```

## Security Considerations

### Passphrase Security
- **Never Stored**: Passphrases are never stored in files or memory
- **Interactive Only**: All passphrase entry is interactive with `read -s`
- **No Logging**: Passphrases never appear in logs or error messages
- **Confirmation Required**: Passphrase creation requires confirmation

### File System Security
- **Encrypted Storage**: All data encrypted with AES-256
- **Atomic Operations**: Operations are atomic with rollback on failure
- **Integrity Verification**: Vault integrity checked before operations
- **Secure Cleanup**: Temporary files and sensitive data cleaned up

### Error Handling
- **Fail Safe**: All errors result in secure, recoverable states
- **Rollback**: Failed operations are rolled back completely
- **Cleanup**: Temporary files and mounts cleaned up on error
- **User Feedback**: Clear error messages without exposing sensitive data

## Testing

### Running Tests

```bash
# Run comprehensive test suite
./scripts/test-vault-manager.sh

# Run specific test categories
./scripts/test-vault-manager.sh test_vault_exists
./scripts/test-vault-manager.sh test_security_features
```

### Test Coverage

The test suite covers:
- ✅ All core functions (exists, create, mount, unmount, status, validate)
- ✅ Error handling and edge cases
- ✅ Security features and passphrase handling
- ✅ Atomic operations and rollback
- ✅ Integration scenarios
- ✅ Help functionality

### Test Results

```bash
# Example test output
[TEST INFO] Starting comprehensive vault manager test suite...
[TEST SUCCESS] PASS: vault_exists with non-existent vault
[TEST SUCCESS] PASS: vault_create basic test
[TEST SUCCESS] PASS: vault_mount with correct passphrase
[TEST SUCCESS] PASS: vault_validate_integrity mounted vault
[TEST INFO] Test Summary:
[TEST INFO] =============
[TEST INFO] Tests run: 25
[TEST INFO] Tests passed: 25
[TEST INFO] Tests failed: 0
[TEST SUCCESS] All tests passed! ✅
```

## Troubleshooting

### Common Issues

#### Vault Creation Fails
```bash
# Check prerequisites
./scripts/vault-manager.sh help

# Check disk space
df -h

# Check permissions
ls -la ~/
```

#### Mount Fails
```bash
# Check if vault exists
./scripts/vault-manager.sh exists

# Check vault status
./scripts/vault-manager.sh status

# Validate vault integrity
./scripts/vault-manager.sh validate
```

#### Permission Issues
```bash
# Check script permissions
ls -la ./scripts/vault-manager.sh

# Make executable if needed
chmod +x ./scripts/vault-manager.sh
```

### Debug Mode

Enable debug logging by setting environment variables:

```bash
export LOG_LEVEL=DEBUG
export LOG_FILE=/tmp/vault-debug.log
./scripts/vault-manager.sh mount
```

## Performance Considerations

### Vault Size
- **Small Vaults (1-5GB)**: Fast creation and mounting
- **Medium Vaults (5-20GB)**: Good balance of performance and capacity
- **Large Vaults (20GB+)**: Slower operations but more capacity

### System Resources
- **Memory**: Vault operations use minimal memory
- **CPU**: Encryption/decryption uses CPU during mount/unmount
- **Disk I/O**: Sparse images are efficient for disk usage

### Optimization Tips
- Use appropriate vault size for your needs
- Mount vault only when needed
- Regular integrity validation
- Keep vault file on fast storage (SSD)

## Future Enhancements

### Planned Features
- **Multi-Vault Support**: Manage multiple journal vaults
- **Backup Integration**: Automated vault backup
- **Cloud Sync**: Encrypted cloud synchronization
- **Web Interface**: Browser-based vault management

### Platform Support
- **Linux Support**: LUKS/dm-crypt equivalent
- **Windows Support**: BitLocker integration
- **Cross-Platform**: Unified interface across platforms

## Support and Maintenance

### Log Files
- **Location**: `/tmp/vault-manager.log` (default)
- **Rotation**: Automatic log rotation configured
- **Retention**: 7 days (configurable)

### Updates
- **Version Control**: All changes tracked in git
- **Backward Compatibility**: Maintained across versions
- **Migration**: Automatic migration for configuration changes

### Community
- **GitHub Issues**: Bug reports and feature requests
- **Documentation**: Comprehensive guides and examples
- **Testing**: Continuous integration and testing

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-18  
**Maintainer**: Local Development Team  
**Status**: Production Ready
