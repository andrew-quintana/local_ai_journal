# Security-Focused Development Guidelines

**Type**: Specialized Implementation Guidance  
**Focus**: Security-First Development Practices  
**Reference**: PRD001.md, RFC001.md  

## 🎯 **Objective**
Provide comprehensive security-focused development guidelines for implementing any component of the journals infrastructure.

## 🛡️ **Core Security Principles**

### Security-First Mindset
- **Every line of code must be reviewed through a security lens**
- Security considerations are not an afterthought
- Fail to secure state by default
- Assume all inputs are potentially malicious

### Defense in Depth
- Multiple layers of security controls
- Redundant security measures
- Fail-safe defaults
- Comprehensive monitoring

## 🔐 **Data Protection Guidelines**

### Encryption Requirements
```bash
# Encrypt all persistent data
encrypt_sensitive_data() {
    local data=$1
    local key_file=$2
    
    # Use AES-256 encryption
    echo "$data" | openssl enc -aes-256-cbc -base64 -pass file:"$key_file"
}

# Decrypt with proper error handling
decrypt_sensitive_data() {
    local encrypted_data=$1
    local key_file=$2
    
    if [[ ! -f "$key_file" ]]; then
        echo "ERROR: Key file not found" >&2
        return 1
    fi
    
    echo "$encrypted_data" | openssl enc -aes-256-cbc -d -base64 -pass file:"$key_file" 2>/dev/null
}
```

### Secure Passphrase Handling
```bash
# Secure passphrase input
get_secure_input() {
    local prompt=$1
    local var_name=$2
    
    read -s -p "$prompt: " "$var_name"
    echo  # New line after hidden input
    
    # Clear the variable after use
    trap "unset $var_name" EXIT
}
```

### Data Integrity Verification
```bash
# Verify data integrity
verify_data_integrity() {
    local file_path=$1
    local expected_hash=$2
    
    if [[ -f "$file_path" ]]; then
        local actual_hash=$(sha256sum "$file_path" | cut -d' ' -f1)
        if [[ "$actual_hash" == "$expected_hash" ]]; then
            return 0
        else
            echo "ERROR: Data integrity check failed" >&2
            return 1
        fi
    else
        echo "ERROR: File not found" >&2
        return 1
    fi
}
```

## 🔒 **Access Control Implementation**

### Minimal Necessary Permissions
```bash
# Implement principle of least privilege
set_minimal_permissions() {
    local file_path=$1
    local user=$2
    
    # Set restrictive permissions
    chmod 600 "$file_path"
    chown "$user:$user" "$file_path"
    
    # Verify permissions
    local perms=$(stat -c "%a" "$file_path")
    if [[ "$perms" != "600" ]]; then
        echo "ERROR: Failed to set secure permissions" >&2
        return 1
    fi
}
```

### Read-Only Access Enforcement
```bash
# Enforce read-only access
enforce_readonly() {
    local path=$1
    
    # Mount as read-only
    if ! mount | grep "$path" | grep -q "ro"; then
        echo "ERROR: Path not mounted read-only" >&2
        return 1
    fi
    
    # Test write access (should fail)
    if touch "$path/test_write" 2>/dev/null; then
        echo "ERROR: Write access detected on read-only path" >&2
        rm -f "$path/test_write"
        return 1
    fi
}
```

### Container Privilege Restrictions
```yaml
# Docker security configuration
security_opt:
  - no-new-privileges:true
  - seccomp:unconfined
user: "1000:1000"
read_only: true
tmpfs:
  - /tmp
  - /var/tmp
```

## 🚨 **Failure Handling Security**

### Fail to Secure State
```bash
# Always fail to secure state
secure_failure() {
    local error_message=$1
    
    # Log error without sensitive data
    echo "ERROR: $error_message" >&2
    
    # Clean up sensitive data
    cleanup_sensitive_data
    
    # Unmount vault if mounted
    if vault_is_mounted; then
        vault_unmount
    fi
    
    # Stop all services
    docker_stack_down 30
    
    # Exit with error
    exit 1
}
```

### Clean Up Sensitive Data
```bash
# Secure cleanup function
cleanup_sensitive_data() {
    # Clear environment variables
    unset VAULT_PASSPHRASE
    unset WEBUI_SECRET_KEY
    unset JWT_SECRET_KEY
    
    # Clear temporary files
    find /tmp -name "*journal*" -delete 2>/dev/null
    
    # Clear bash history if sensitive commands were used
    history -c
}
```

### Prevent Information Leakage
```bash
# Secure error reporting
report_error_securely() {
    local error_type=$1
    local context=$2
    
    # Log generic error without sensitive details
    echo "ERROR: Operation failed in $context" >&2
    
    # Don't log sensitive information
    # Don't expose internal paths
    # Don't reveal system details
    
    # Provide generic guidance
    echo "Check logs for more details" >&2
}
```

## 🔍 **Security Monitoring**

### Audit Trail Maintenance
```bash
# Secure audit logging
log_security_event() {
    local event_type=$1
    local user=$2
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Log to secure audit file
    echo "$timestamp|$event_type|$user" >> /var/log/journals-security.log
    
    # Set secure permissions on log file
    chmod 600 /var/log/journals-security.log
    chown root:root /var/log/journals-security.log
}
```

### Security Event Detection
```bash
# Monitor for security violations
monitor_security_events() {
    # Monitor file access
    inotifywait -m /journals -e access,open 2>/dev/null | while read line; do
        log_security_event "file_access" "$(whoami)"
    done &
    
    # Monitor network connections
    netstat -an | grep -E ":(3000|11434)" | while read line; do
        if echo "$line" | grep -v "127.0.0.1"; then
            log_security_event "network_violation" "$(whoami)"
        fi
    done
}
```

## 📋 **Security Checklist**

### Pre-Implementation
- [ ] Identify all sensitive data
- [ ] Plan encryption strategy
- [ ] Design access controls
- [ ] Plan error handling
- [ ] Design audit logging

### During Implementation
- [ ] Encrypt all sensitive data
- [ ] Implement least privilege access
- [ ] Add comprehensive error handling
- [ ] Include security monitoring
- [ ] Test security controls

### Post-Implementation
- [ ] Verify security controls work
- [ ] Test failure scenarios
- [ ] Validate audit logging
- [ ] Review for information leakage
- [ ] Document security features

## 📚 **Reference Documents**
- **PRD001.md**: Security requirements and constraints
- **RFC001.md**: Security architecture and interfaces

## 🧪 **Security Testing**
1. Test encryption/decryption functions
2. Verify access control enforcement
3. Test failure handling security
4. Validate audit logging
5. Test information leakage prevention

---

**Document Version**: 1.0  
**Created**: 2025-01-18  
**Type**: Specialized Implementation Guidance  
**Priority**: Critical
