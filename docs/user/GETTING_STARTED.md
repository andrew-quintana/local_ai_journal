# Getting Started with Local Journal

## Overview

Local Journal is a secure, privacy-first journaling system that keeps your personal thoughts completely private while providing AI assistance for analysis and insights. All data stays on your computer with military-grade encryption.

## Quick Setup

### 1. Prerequisites
- **macOS 10.15+** (for APFS support)
- **Docker Desktop 4.0+** (for AI services)
- **8GB+ RAM, 10GB+ disk space**
- **Internet connection** (initial setup only)

### 2. Create Your First Vault

```bash
# Create a new encrypted vault (5GB size)
./src/vault/vault-manager.sh create 5g ~/MyJournal.sparseimage
```

This will:
- Prompt you for a secure passphrase (minimum 8 characters)
- Create an AES-256 encrypted vault
- Verify the vault integrity
- Set up the vault for secure journal storage

### 3. Mount Your Vault

```bash
# Mount the vault for use
./src/vault/vault-manager.sh mount
```

The vault will be mounted at `~/Journals` by default.

### 4. Check Vault Status

```bash
# See if your vault is ready
./src/vault/vault-manager.sh status
```

Should return `mounted` when ready.

### 5. Unmount When Done

```bash
# Securely unmount your vault
./src/vault/vault-manager.sh unmount
```

Always unmount your vault when finished to ensure data security.

## Security Features

- **Complete Privacy**: All data stays on your computer
- **AES-256 Encryption**: Military-grade encryption for your journals
- **No Passphrase Storage**: Passphrases are never saved or logged
- **Local AI Only**: AI assistance without data transmission

## Troubleshooting

### Vault Won't Mount
- Check if vault exists: `./src/vault/vault-manager.sh exists`
- Verify passphrase is correct
- Check vault integrity: `./src/vault/vault-manager.sh validate`

### Permission Issues
- Make sure scripts are executable: `chmod +x src/vault/vault-manager.sh`
- Check that you're not running as root

### Need Help?
- Run the demo: `./src/vault/demo-vault-manager.sh`
- Check the security docs: `docs/security/`
- Review developer docs: `docs/dev/`
