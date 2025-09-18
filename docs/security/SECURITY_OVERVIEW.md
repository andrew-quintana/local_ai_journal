# Security Overview

## Security Architecture

Local Journal is designed with security as the primary concern, implementing multiple layers of protection to ensure complete privacy and data security.

## Security Principles

### 1. Privacy First
- **No External Data Transmission**: All operations are local to your system
- **No Cloud Dependencies**: Complete offline operation after initial setup
- **No Data Logging**: Journal content never appears in logs or monitoring
- **Ephemeral AI Processing**: AI processes data in memory only, no persistence

### 2. Defense in Depth
- **Encryption at Rest**: AES-256 encryption for all stored data
- **Secure Passphrase Handling**: Interactive-only, no storage or logging
- **Atomic Operations**: All operations are atomic with rollback capability
- **Integrity Verification**: Regular validation of vault integrity

### 3. Fail Safe Design
- **Secure by Default**: All operations fail to secure states
- **Error Recovery**: Graceful handling of all error conditions
- **Cleanup on Failure**: Automatic cleanup of sensitive data
- **Rollback Capability**: Failed operations are completely rolled back

## Encryption Implementation

### AES-256 Encryption
- **Algorithm**: Advanced Encryption Standard with 256-bit keys
- **Implementation**: macOS native APFS encryption
- **Key Derivation**: Passphrase-based key derivation
- **Verification**: Encryption status verified after creation

### Passphrase Security
- **Interactive Entry**: All passphrases entered interactively with `read -s`
- **No Storage**: Passphrases never stored in files or memory
- **No Logging**: Passphrases never appear in logs or error messages
- **Minimum Length**: 8-character minimum enforced by system
- **Confirmation**: Passphrase creation requires confirmation

### Vault Security
- **Sparse Images**: Efficient storage with APFS sparse images
- **Atomic Creation**: Vault created in temporary location, verified, then moved
- **Integrity Checks**: Regular filesystem integrity validation
- **Secure Mounting**: Mount points created with appropriate permissions

## Network Security

### Localhost-Only Binding
- **AI Services**: All AI services bound to 127.0.0.1 only
- **Web Interface**: WebUI accessible only from localhost
- **No External Access**: No services accessible from external networks
- **Firewall Friendly**: Works with restrictive firewall configurations

### Container Security
- **Network Isolation**: Containers isolated from external networks
- **Read-Only Access**: AI containers have read-only access to journals
- **No Privilege Escalation**: Containers run with minimal privileges
- **Resource Limits**: Container resource usage limited to prevent abuse

## Data Protection

### Journal Data
- **Encrypted Storage**: All journal data encrypted with AES-256
- **Read-Only AI Access**: AI can read but never modify journal files
- **No Persistence**: AI processing data not persisted between sessions
- **Secure Cleanup**: All temporary data cleaned up after use

### System Data
- **No Sensitive Logging**: No passphrases or journal content in logs
- **Minimal Logging**: Only operational status and error information
- **Log Rotation**: Automatic log rotation and cleanup
- **Secure Storage**: Logs stored with appropriate permissions

## Access Control

### File System Permissions
- **Vault Files**: Secure permissions on vault image files
- **Mount Points**: Appropriate permissions on mount points
- **Scripts**: Executable permissions only where needed
- **Configuration**: Read-only access to configuration files

### User Authentication
- **Interactive Only**: All sensitive operations require interactive authentication
- **No Password Storage**: No passwords or passphrases stored anywhere
- **Session Management**: Secure session handling with proper cleanup
- **Access Verification**: Regular verification of access permissions

## Security Validation

### Automated Checks
- **Encryption Verification**: Automatic verification of encryption status
- **Integrity Validation**: Regular filesystem integrity checks
- **Permission Validation**: Verification of file and directory permissions
- **Network Isolation**: Validation of localhost-only binding

### Manual Validation
- **Security Review**: Regular security review of all components
- **Penetration Testing**: Security testing of all attack vectors
- **Code Review**: Security-focused code review process
- **Documentation Review**: Regular review of security documentation

## Threat Model

### Assets Protected
- **Journal Content**: Personal thoughts and reflections
- **AI Model Data**: Local AI models and processing data
- **System Configuration**: Vault and service configuration
- **User Credentials**: Passphrases and authentication data

### Threats Mitigated
- **Data Exfiltration**: Complete local operation prevents data leakage
- **Unauthorized Access**: Encryption and access control prevent unauthorized access
- **System Compromise**: Fail-safe design limits impact of compromise
- **Data Corruption**: Integrity checks and atomic operations prevent corruption

### Attack Vectors
- **Local System Compromise**: Mitigated by encryption and access control
- **Network Attacks**: Mitigated by localhost-only binding
- **Physical Access**: Mitigated by encryption and passphrase protection
- **Social Engineering**: Mitigated by no external dependencies

## Security Best Practices

### For Users
- **Strong Passphrases**: Use unique, complex passphrases
- **Regular Backups**: Backup vault files to secure locations
- **System Updates**: Keep system and software updated
- **Secure Environment**: Use secure, trusted systems only

### For Developers
- **Security Review**: All code changes require security review
- **Testing**: Comprehensive security testing required
- **Documentation**: Security implications must be documented
- **Updates**: Security updates must be applied promptly

## Compliance and Standards

### Security Standards
- **AES-256**: Industry-standard encryption algorithm
- **APFS**: Apple's modern, secure filesystem
- **Docker Security**: Container security best practices
- **macOS Security**: Platform security guidelines

### Privacy Compliance
- **No Data Collection**: No user data collected or transmitted
- **Local Processing**: All processing done locally
- **User Control**: Complete user control over data
- **Transparency**: Open source and documented security

## Incident Response

### Security Incidents
- **Detection**: Automated monitoring and alerting
- **Response**: Immediate isolation and investigation
- **Recovery**: Secure recovery procedures
- **Documentation**: Complete incident documentation

### Recovery Procedures
- **Vault Recovery**: Secure vault recovery from backups
- **System Recovery**: Complete system recovery procedures
- **Data Verification**: Verification of data integrity after recovery
- **Security Validation**: Re-validation of security controls

## Security Updates

### Update Process
- **Security Patches**: Regular security updates
- **Vulnerability Management**: Proactive vulnerability management
- **Testing**: Security testing of all updates
- **Documentation**: Updated security documentation

### Monitoring
- **Security Monitoring**: Continuous security monitoring
- **Log Analysis**: Regular analysis of security logs
- **Threat Intelligence**: Monitoring of security threats
- **Response Planning**: Regular update of response procedures
