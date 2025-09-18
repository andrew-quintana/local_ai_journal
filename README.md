# Local Journal - Secure AI-Assisted Journaling

A privacy-first, local AI-assisted journaling system with encrypted storage and localhost-only AI services.

## 🎯 **Project Overview**

This project provides a complete local journaling infrastructure that ensures your personal thoughts and reflections remain completely private while leveraging AI assistance for analysis and insights.

### **Core Features**
- **🔒 Encrypted Storage**: AES-256 encrypted APFS vaults for journal data
- **🤖 Local AI**: Ollama-powered AI assistance without data transmission
- **🌐 Web Interface**: Open WebUI for intuitive journal interaction
- **🔐 Privacy First**: All operations local, no external data transmission
- **⚡ Production Ready**: Clean architecture suitable for distribution

## 📁 **Project Structure**

```
local_journal/
├── bin/                          # Executable scripts (future)
├── config/                       # Configuration files
│   └── vault.conf               # Vault management defaults
├── docs/                        # Documentation
│   ├── architecture/            # Technical architecture docs
│   │   └── RFC001.md           # System architecture RFC
│   ├── implementation/          # Implementation guides
│   │   ├── VAULT_MANAGEMENT.md # Vault system documentation
│   │   ├── implementation_prompts.md
│   │   └── prompts/            # Phase-specific prompts
│   ├── planning/               # Project planning docs
│   │   ├── PRD001.md          # Product requirements
│   │   ├── TODO001.md         # Implementation plan
│   │   └── fracas.md          # Failure tracking
│   └── README.md               # Project documentation
├── scripts/                     # Operational scripts
│   ├── vault/                  # Vault management scripts
│   │   ├── vault-manager.sh   # Core vault operations
│   │   └── demo-vault-manager.sh
│   ├── docker/                 # Docker orchestration (future)
│   └── session/                # Session control (future)
├── tests/                      # Test suites
│   ├── vault/                  # Vault management tests
│   │   ├── test-vault-manager.sh
│   │   └── simple-test.sh
│   └── integration/            # Integration tests (future)
├── archive/                    # Legacy scripts
└── requirements.txt            # Python dependencies
```

## 🚀 **Quick Start**

### Prerequisites
- **macOS 10.15+** (APFS support required)
- **Docker Desktop 4.0+**
- **8GB+ RAM, 10GB+ disk space**
- **Internet connection** (initial setup only)

### Phase 1: Vault Management ✅
```bash
# Check if vault exists
./scripts/vault/vault-manager.sh exists

# Create new vault (interactive passphrase)
./scripts/vault/vault-manager.sh create 5g ~/MyJournal.sparseimage

# Mount vault (interactive passphrase)
./scripts/vault/vault-manager.sh mount

# Check vault status
./scripts/vault/vault-manager.sh status

# Unmount vault
./scripts/vault/vault-manager.sh unmount
```

### Phase 2: Docker Orchestration (Coming Soon)
```bash
# Start journaling session
./bin/journals-up.sh

# Access AI interface
open http://localhost:3000

# Stop session
./bin/journals-down.sh
```

## 🔒 **Security Architecture**

### Data Protection
- **AES-256 Encryption**: All journal data encrypted at rest
- **Interactive Passphrases**: No passphrase storage or logging
- **Localhost-Only Services**: All AI services bound to 127.0.0.1
- **Read-Only AI Access**: AI can read but never modify journals

### Privacy Guarantees
- **No External Access**: Complete local operation
- **No Data Logging**: Journal content never appears in logs
- **Ephemeral AI Processing**: No persistent AI data storage
- **Secure Cleanup**: Automatic cleanup of sensitive data

## 📊 **Implementation Status**

### ✅ Phase 1: Core Infrastructure (COMPLETE)
- [x] Vault management system with AES-256 encryption
- [x] Atomic operations with rollback capability
- [x] Comprehensive error handling
- [x] Security validation and integrity checks
- [x] Complete documentation and testing

### ⏳ Phase 2: AI Integration (PLANNED)
- [ ] Docker orchestration for AI services
- [ ] Ollama model management
- [ ] Open WebUI configuration
- [ ] Journal mounting and access control

### ⏳ Phase 3: Production Polish (PLANNED)
- [ ] Security hardening and validation
- [ ] Cross-platform compatibility
- [ ] Distribution preparation
- [ ] Community documentation

## 🧪 **Testing**

### Manual Testing
```bash
# Test vault operations
./scripts/vault/demo-vault-manager.sh

# Run comprehensive tests
./tests/vault/test-vault-manager.sh
```

### Test Coverage
- ✅ Vault operations (create, mount, unmount, status, validate)
- ✅ Security features (passphrase handling, encryption)
- ✅ Error handling and edge cases
- ✅ Atomic operations and rollback

## 📚 **Documentation**

- **[Architecture](docs/architecture/)** - Technical system design
- **[Implementation](docs/implementation/)** - Implementation guides and prompts
- **[Planning](docs/planning/)** - Project requirements and planning
- **[Vault Management](docs/implementation/VAULT_MANAGEMENT.md)** - Complete vault system docs

## 🤝 **Contributing**

This project follows a structured development approach:
1. **Documentation First**: PRD → RFC → Implementation
2. **Security First**: Every component designed with security as primary concern
3. **Testing Driven**: Comprehensive testing at all levels
4. **Failure Tracked**: FRACAS methodology for systematic analysis

## 📄 **License**

This project is designed for personal use and community sharing. See individual files for specific licensing information.

---

**Project Status**: Phase 1 Complete ✅  
**Last Updated**: 2025-01-18  
**Maintainer**: Local Development Team
