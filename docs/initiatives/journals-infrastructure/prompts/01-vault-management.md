# Vault Management Implementation Prompt

**Phase**: Core Infrastructure  
**Component**: APFS Vault Management System  
**Reference**: PRD001.md, RFC001.md  

## 🎯 **Objective**
Create a robust APFS vault management system for secure journal storage with AES-256 encryption and atomic operations.

## 📋 **Requirements**

### Security Requirements
- APFS sparse image with AES-256 encryption
- Interactive passphrase entry (no storage)
- Atomic mount/unmount operations with rollback
- Comprehensive error handling and user feedback
- Integrity verification and corruption detection

### Security Constraints
- Never log or store passphrases
- Fail safely on any error condition
- Verify all operations completed successfully
- Clean up on interruption or failure

## 🔧 **Functions to Implement**

```bash
# Core vault operations
vault_exists() -> boolean
vault_create(size, location) -> exit_code
vault_mount() -> exit_code (interactive passphrase)
vault_unmount() -> exit_code
vault_status() -> {mounted|unmounted|error}
vault_validate_integrity() -> exit_code
```

## 🛡️ **Security Implementation Guidelines**

### Data Protection
- Use `hdiutil` with AES-256 encryption
- Implement secure passphrase handling with `read -s`
- Verify encryption status after creation
- Validate mount point security

### Error Handling
- Rollback on any failure during creation
- Clean unmount on interruption
- Verify vault integrity before operations
- Clear error messages without exposing sensitive data

### Atomic Operations
- Create vault in temporary location first
- Move to final location only after verification
- Implement transaction-like behavior
- Maintain consistent state

## 📚 **Reference Documents**
- **PRD001.md**: Security requirements and user expectations
- **RFC001.md**: Interface contracts and technical specifications

## 🧪 **Testing Requirements**
1. Test vault creation with various sizes
2. Verify encryption is properly applied
3. Test mount/unmount with invalid passphrases
4. Validate integrity checking functionality
5. Test rollback scenarios on failures

---

**Document Version**: 1.0  
**Created**: 2025-01-18  
**Phase**: Core Infrastructure  
**Priority**: High
