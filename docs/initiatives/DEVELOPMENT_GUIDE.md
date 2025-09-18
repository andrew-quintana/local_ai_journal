# Development Guide

## Project Structure

```
local_journal/
├── bin/                    # User-facing executables
├── src/                    # Core system components
│   ├── vault/             # Vault management system
│   ├── docker/            # Docker orchestration (Phase 2)
│   └── session/           # Session control (Phase 2)
├── tests/                  # Test suites
├── docs/                   # Documentation
│   ├── user/              # User guides
│   ├── security/          # Security documentation
│   └── dev/               # Developer documentation
└── archive/                # Legacy scripts
```

## Development Workflow

### Phase 1: Core Infrastructure ✅
- **Vault Management**: Complete and tested
- **Security Features**: AES-256 encryption, secure passphrase handling
- **Error Handling**: Comprehensive error handling and rollback
- **Documentation**: Complete user and developer documentation

### Phase 2: AI Integration (Next)
- **Docker Orchestration**: Container management for AI services
- **Model Management**: Ollama model download and management
- **WebUI Integration**: Open WebUI configuration and setup
- **Journal Access**: Read-only journal mounting for AI

### Phase 3: Production Polish (Future)
- **Security Hardening**: Additional security validation
- **Cross-Platform**: Linux support with dm-crypt
- **Distribution**: GitHub-ready packaging
- **Community**: Documentation and contribution guidelines

## Development Standards

### Code Quality
- **Bash Best Practices**: Use `set -euo pipefail`
- **Error Handling**: Comprehensive error handling with rollback
- **Security First**: All operations designed with security in mind
- **Documentation**: All functions documented with examples

### Testing Requirements
- **Unit Tests**: All core functions tested
- **Integration Tests**: End-to-end workflow testing
- **Security Tests**: Passphrase handling and encryption validation
- **Manual Testing**: User workflow validation

### Security Guidelines
- **No Sensitive Data Logging**: Never log passphrases or journal content
- **Atomic Operations**: All operations must be atomic with rollback
- **Input Validation**: Validate all inputs and handle edge cases
- **Error Recovery**: Graceful handling of all error conditions

## Vault Management System

### Core Functions
```bash
# All functions in src/vault/vault-manager.sh
vault_exists() -> boolean
vault_create(size, location) -> exit_code
vault_mount() -> exit_code
vault_unmount() -> exit_code
vault_status() -> {mounted|unmounted|error}
vault_validate_integrity() -> exit_code
```

### Security Implementation
- **Interactive Passphrases**: Using `read -s` for secure input
- **Atomic Operations**: Create in temp location, verify, then move
- **Integrity Verification**: Filesystem checks and mount verification
- **Cleanup**: Automatic cleanup of temporary files and sensitive data

### Testing
```bash
# Run comprehensive tests
./tests/test-vault-manager.sh

# Run simple tests
./tests/simple-test.sh

# Run demonstration
./src/vault/demo-vault-manager.sh
```

## Adding New Features

### 1. Planning
- Create feature request in `docs/dev/`
- Define security requirements
- Plan testing approach
- Document user interface

### 2. Implementation
- Follow existing code patterns
- Implement comprehensive error handling
- Add security validation
- Create test cases

### 3. Testing
- Unit tests for all functions
- Integration tests for workflows
- Security validation
- User acceptance testing

### 4. Documentation
- Update user documentation
- Add developer documentation
- Update README if needed
- Create examples and tutorials

## Environment Setup

### Prerequisites
- **macOS 10.15+** (for APFS support)
- **Docker Desktop 4.0+** (for AI services)
- **Git** (for version control)
- **Text Editor** (VS Code, Vim, etc.)

### Development Environment
```bash
# Clone repository
git clone <repository-url>
cd local_journal

# Make scripts executable
chmod +x src/vault/vault-manager.sh
chmod +x tests/test-vault-manager.sh

# Test vault management
./src/vault/vault-manager.sh help
```

### Testing Environment
```bash
# Run all tests
./tests/test-vault-manager.sh

# Test specific functionality
./src/vault/demo-vault-manager.sh

# Check vault status
./src/vault/vault-manager.sh status
```

## Contributing

### Code Style
- **Bash**: Use `set -euo pipefail` at script start
- **Functions**: Document all functions with purpose and parameters
- **Variables**: Use `readonly` for constants, `local` for function variables
- **Error Handling**: Use `error_exit()` function for consistent error handling

### Commit Messages
- **Format**: `type: description`
- **Types**: `feat`, `fix`, `docs`, `refactor`, `test`
- **Description**: Clear, concise description of changes
- **Examples**:
  - `feat: Add vault validation function`
  - `fix: Correct passphrase handling in mount`
  - `docs: Update user getting started guide`

### Pull Request Process
1. **Create Feature Branch**: `git checkout -b feature/new-feature`
2. **Implement Changes**: Follow development standards
3. **Test Thoroughly**: Run all tests and manual validation
4. **Update Documentation**: Update relevant documentation
5. **Create Pull Request**: Clear description of changes and testing

## Security Review

### Security Checklist
- [ ] No sensitive data in logs
- [ ] All operations are atomic
- [ ] Input validation implemented
- [ ] Error handling comprehensive
- [ ] Passphrase handling secure
- [ ] File permissions correct
- [ ] Cleanup on failure

### Security Testing
- [ ] Passphrase not logged
- [ ] Vault operations atomic
- [ ] Error recovery works
- [ ] File permissions secure
- [ ] No data leakage

## Performance Considerations

### Vault Operations
- **Creation**: Larger vaults take longer to create
- **Mounting**: Fast operation, minimal resource usage
- **Validation**: Can be slow for large vaults
- **Unmounting**: Fast operation with verification

### System Resources
- **Memory**: Minimal memory usage for vault operations
- **CPU**: Encryption/decryption uses CPU during mount/unmount
- **Disk I/O**: Sparse images are efficient for disk usage
- **Network**: No network usage for vault operations

## Troubleshooting Development Issues

### Common Problems
- **Permission Issues**: Check file permissions and ownership
- **Script Errors**: Verify bash syntax and error handling
- **Test Failures**: Check test environment and dependencies
- **Vault Issues**: Verify vault integrity and permissions

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=DEBUG
export LOG_FILE=/tmp/vault-debug.log
./src/vault/vault-manager.sh mount
```

### Getting Help
- **Check Logs**: Review log files for error details
- **Run Tests**: Use test suite to identify issues
- **Review Code**: Check implementation against requirements
- **Ask Questions**: Use issue tracker for development questions
