# Local Journal - Secure AI-Assisted Journaling

A privacy-first, local AI-assisted journaling system with encrypted storage and localhost-only AI services.

## 🎯 **Quick Start**

### Prerequisites
- **macOS 10.15+** (APFS support required)
- **Docker Desktop 4.0+**
- **8GB+ RAM, 10GB+ disk space**

### Phase 1: Vault Management ✅
```bash
# Check if vault exists
./src/vault/vault-manager.sh exists

# Create new vault (interactive passphrase)
./src/vault/vault-manager.sh create 5g ~/MyJournal.sparseimage

# Mount vault (interactive passphrase)
./src/vault/vault-manager.sh mount

# Check vault status
./src/vault/vault-manager.sh status

# Unmount vault
./src/vault/vault-manager.sh unmount
```

### Phase 2: Complete System (Coming Soon)
```bash
# Start journaling session
./bin/journals-up.sh

# Access AI interface
open http://localhost:3000

# Stop session
./bin/journals-down.sh
```

## 🔒 **Security Features**

- **AES-256 Encryption**: All journal data encrypted at rest
- **Interactive Passphrases**: No passphrase storage or logging
- **Localhost-Only Services**: All AI services bound to 127.0.0.1
- **Read-Only AI Access**: AI can read but never modify journals
- **Complete Privacy**: No external data transmission

## 📁 **Project Structure**

```
local_journal/
├── bin/                    # User-facing executables
│   ├── journals-up.sh     # Start journaling session
│   ├── journals-down.sh   # Stop journaling session
│   ├── journals-start.sh  # Legacy start script
│   └── journals-stop.sh   # Legacy stop script
├── src/                    # Core system components
│   ├── vault/             # Vault management system
│   │   ├── vault-manager.sh      # Core vault operations
│   │   ├── demo-vault-manager.sh # Demonstration script
│   │   └── vault.conf            # Configuration defaults
│   ├── docker/            # Docker orchestration (Phase 2)
│   └── session/           # Session control (Phase 2)
├── tests/                  # Test suites
│   ├── test-vault-manager.sh    # Vault management tests
│   └── simple-test.sh           # Simple test script
├── docs/                   # Documentation
│   ├── security/          # Security documentation
│   ├── user/              # User guides
│   └── dev/               # Developer documentation
├── archive/                # Legacy scripts
└── requirements.txt        # Python dependencies
```

## 🧪 **Testing**

```bash
# Test vault operations
./src/vault/demo-vault-manager.sh

# Run comprehensive tests
./tests/test-vault-manager.sh
```

## 📊 **Implementation Status**

### ✅ Phase 1: Core Infrastructure (COMPLETE)
- [x] Vault management system with AES-256 encryption
- [x] Atomic operations with rollback capability
- [x] Comprehensive error handling
- [x] Security validation and integrity checks

### ⏳ Phase 2: AI Integration (PLANNED)
- [ ] Docker orchestration for AI services
- [ ] Ollama model management
- [ ] Open WebUI configuration
- [ ] Journal mounting and access control

### ⏳ Phase 3: Production Polish (PLANNED)
- [ ] Security hardening and validation
- [ ] Cross-platform compatibility
- [ ] Distribution preparation

## 📚 **Documentation**

### User Documentation
- **[Getting Started](docs/user/GETTING_STARTED.md)** - Quick setup and basic usage
- **[Vault Management](docs/user/VAULT_MANAGEMENT.md)** - Complete vault operations guide

### Security Documentation
- **[Security Overview](docs/security/SECURITY_OVERVIEW.md)** - Security architecture and principles
- **[Vault Security](docs/security/VAULT_MANAGEMENT.md)** - Detailed vault security implementation

### Developer Documentation
- **[Development Guide](docs/dev/DEVELOPMENT_GUIDE.md)** - Development workflow and standards
- **[Architecture](docs/dev/RFC001.md)** - Technical system architecture
- **[Requirements](docs/dev/PRD001.md)** - Product requirements and specifications

---

**Project Status**: Phase 1 Complete ✅  
**Last Updated**: 2025-01-18