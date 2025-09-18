# WebUI Security Configuration Implementation Prompt

**Phase**: AI Integration  
**Component**: Open WebUI Security Configuration  
**Reference**: PRD001.md, RFC001.md  

## 🎯 **Objective**
Configure Open WebUI for secure journal integration with read-only access and localhost-only binding.

## 🛡️ **Security Configuration Requirements**

### Network Security
- Connect to local Ollama only (127.0.0.1:11434)
- Bind WebUI to localhost only (127.0.0.1:3000)
- Disable external connections
- Block all outbound network access

### File System Security
- Mount journal directory read-only
- No modification permissions
- Verify read-only enforcement
- Monitor file access attempts

## 🔧 **Configuration Implementation**

### Docker Compose Security
```yaml
services:
  open-webui:
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}
    volumes:
      - journals-data:/journals:ro
    networks:
      - journals-internal
    read_only: true
    tmpfs:
      - /tmp
      - /var/tmp
```

### Environment Configuration
```bash
# WebUI security environment
export OLLAMA_BASE_URL="http://127.0.0.1:11434"
export WEBUI_SECRET_KEY="$(openssl rand -hex 32)"
export WEBUI_JWT_SECRET_KEY="$(openssl rand -hex 32)"
export WEBUI_DISABLE_SIGNUP="true"
export WEBUI_DISABLE_LOGIN_FORM="false"
```

## 📋 **Journal Integration Features**

### Read-Only Access
- Browse journal files and directories
- Search through journal content
- View file metadata and timestamps
- No write or delete permissions

### Security Validation
- Verify no write access to journals
- Test network isolation effectiveness
- Confirm all external access blocked
- Monitor access attempts

## 🔍 **Access Control Implementation**

### File System Permissions
```bash
# Verify read-only mounting
verify_readonly_access() {
    local journal_path="/journals"
    
    # Test write attempt (should fail)
    if touch "$journal_path/test_write" 2>/dev/null; then
        echo "ERROR: Write access detected!"
        return 1
    else
        echo "SUCCESS: Read-only access confirmed"
        return 0
    fi
}
```

### Network Isolation
```bash
# Verify localhost-only binding
verify_network_isolation() {
    # Check if WebUI is bound to localhost only
    if netstat -an | grep ":3000" | grep -v "127.0.0.1"; then
        echo "ERROR: WebUI not properly isolated!"
        return 1
    else
        echo "SUCCESS: Network isolation confirmed"
        return 0
    fi
}
```

## 🚫 **Security Constraints**

### Absolute Restrictions
- **NEVER** allow write access to journal files
- **NEVER** enable external network access
- **NEVER** store journal content in WebUI logs
- **NEVER** allow file uploads to journal directory

### Validation Requirements
- Verify no write access to journals
- Test network isolation effectiveness
- Confirm all external access blocked
- Monitor and log all access attempts

## 📊 **Monitoring and Logging**

### Access Monitoring
- Log all file access attempts
- Monitor network connections
- Track user sessions
- Alert on security violations

### Audit Trail
- Record all configuration changes
- Log security validation results
- Track access patterns
- Maintain security event log

## 🔧 **Configuration Functions**

```bash
# WebUI security functions
configure_webui_security() -> exit_code
verify_readonly_mount() -> boolean
test_network_isolation() -> boolean
validate_ollama_connection() -> boolean
monitor_access_attempts() -> void
```

## 📚 **Reference Documents**
- **PRD001.md**: Security requirements and user expectations
- **RFC001.md**: WebUI configuration specifications

## 🧪 **Testing Requirements**
1. Test read-only file access enforcement
2. Verify localhost-only network binding
3. Test external access blocking
4. Validate Ollama connection security
5. Test access monitoring and logging

---

**Document Version**: 1.0  
**Created**: 2025-01-18  
**Phase**: AI Integration  
**Priority**: High
