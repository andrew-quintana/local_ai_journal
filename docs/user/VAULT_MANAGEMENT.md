# Vault Management Guide

## Overview

The vault management system provides secure, encrypted storage for your journal data using APFS sparse images with AES-256 encryption. This guide covers all vault operations and best practices.

## Vault Operations

### Check if Vault Exists
```bash
./src/vault/vault-manager.sh exists
```
Returns `true` if vault exists, `false` if not.

### Create New Vault
```bash
# Create vault with default size (10GB)
./src/vault/vault-manager.sh create

# Create vault with custom size
./src/vault/vault-manager.sh create 5g ~/MyJournal.sparseimage

# Create vault with custom location
./src/vault/vault-manager.sh create 2g ~/Documents/PersonalJournal.sparseimage
```

**Size Options:**
- `1g`, `2g`, `5g`, `10g`, `20g`, `50g`, `100g`
- `1t`, `2t` (for very large vaults)

### Mount Vault
```bash
./src/vault/vault-manager.sh mount
```
- Prompts for passphrase interactively
- Mounts vault at `~/Journals` by default
- Creates mount point if it doesn't exist

### Check Vault Status
```bash
./src/vault/vault-manager.sh status
```
Returns:
- `mounted` - Vault is ready for use
- `unmounted` - Vault exists but not mounted
- `error` - Vault doesn't exist or error occurred

### Validate Vault Integrity
```bash
./src/vault/vault-manager.sh validate
```
- Checks filesystem integrity
- Verifies vault accessibility
- Mounts vault temporarily if needed

### Unmount Vault
```bash
./src/vault/vault-manager.sh unmount
```
- Safely unmounts the vault
- Verifies unmount was successful
- Keeps vault file intact

## Configuration

### Environment Variables
You can customize vault behavior using environment variables:

```bash
# Custom vault location
export VAULT_IMAGE_PATH="~/MyCustomVault.sparseimage"
./src/vault/vault-manager.sh create

# Custom mount point
export VAULT_MOUNT_POINT="~/MyJournals"
./src/vault/vault-manager.sh mount

# Custom vault size
export VAULT_SIZE="5g"
./src/vault/vault-manager.sh create
```

### Configuration File
Default settings are in `src/vault.conf`:
```bash
# View current configuration
cat src/vault.conf
```

## Security Best Practices

### Passphrase Security
- **Minimum 8 characters** (enforced by system)
- **Use unique passphrases** for each vault
- **Never share passphrases** - they're not recoverable
- **Consider using a password manager** for complex passphrases

### Vault Management
- **Always unmount when done** to protect data
- **Regular integrity checks** with `validate` command
- **Backup vault files** to secure locations
- **Test vault recovery** periodically

### File System Security
- **Keep vault files secure** - they contain encrypted data
- **Use secure file permissions** on vault files
- **Consider additional encryption** for vault file storage
- **Regular system security updates**

## Troubleshooting

### Common Issues

#### Vault Creation Fails
```bash
# Check disk space
df -h

# Check permissions
ls -la ~/

# Try with smaller size
./src/vault/vault-manager.sh create 1g
```

#### Vault Won't Mount
```bash
# Check if vault exists
./src/vault/vault-manager.sh exists

# Verify vault integrity
./src/vault/vault-manager.sh validate

# Check mount point permissions
ls -la ~/Journals
```

#### Permission Issues
```bash
# Make scripts executable
chmod +x src/vault/vault-manager.sh

# Check you're not running as root
whoami
```

#### Vault Corruption
```bash
# Run integrity check
./src/vault/vault-manager.sh validate

# If corruption detected, restore from backup
# (Vault files are not easily recoverable)
```

### Getting Help
```bash
# Show help information
./src/vault/vault-manager.sh help

# Run demonstration
./src/vault/demo-vault-manager.sh

# Check system logs
tail -f /tmp/vault-manager.log
```

## Advanced Usage

### Multiple Vaults
```bash
# Create multiple vaults
./src/vault/vault-manager.sh create 5g ~/WorkJournal.sparseimage
./src/vault/vault-manager.sh create 2g ~/PersonalJournal.sparseimage

# Switch between vaults
export VAULT_IMAGE_PATH="~/WorkJournal.sparseimage"
./src/vault/vault-manager.sh mount
```

### Automated Vault Management
```bash
#!/bin/bash
# Example script for automated vault operations

# Check if vault exists
if ./src/vault/vault-manager.sh exists; then
    echo "Vault exists, mounting..."
    ./src/vault/vault-manager.sh mount
else
    echo "Creating new vault..."
    ./src/vault/vault-manager.sh create 5g
fi
```

### Integration with Other Tools
```bash
# Mount vault before using journaling tools
./src/vault/vault-manager.sh mount

# Use your preferred text editor
code ~/Journals/daily-2025-01-18.md

# Unmount when done
./src/vault/vault-manager.sh unmount
```

## Performance Tips

### Vault Size
- **Small vaults (1-5GB)**: Fast operations, limited storage
- **Medium vaults (5-20GB)**: Good balance of performance and capacity
- **Large vaults (20GB+)**: More storage, slower operations

### System Resources
- **SSD storage recommended** for better performance
- **Adequate RAM** for smooth operations
- **Regular system maintenance** for optimal performance

### Backup Strategy
- **Regular backups** of vault files
- **Test restore procedures** periodically
- **Multiple backup locations** for redundancy
- **Encrypted backup storage** for additional security
