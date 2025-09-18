# Docker Orchestration Implementation Prompt

**Phase**: Core Infrastructure  
**Component**: Secure Docker Orchestration for AI Services  
**Reference**: RFC001.md, PRD001.md  

## 🎯 **Objective**
Create secure Docker orchestration for AI services with localhost-only binding and read-only journal access.

## 📋 **Services Required**

### Core Services
- **Ollama**: AI model serving (port 127.0.0.1:11434)
- **Open WebUI**: AI interface (port 127.0.0.1:3000)

### Security Requirements
- All ports bound to localhost only (127.0.0.1)
- Journal directory mounted read-only
- Isolated Docker network
- No external network access

## 🔧 **Functions to Implement**

```bash
# Docker orchestration functions
docker_stack_up() -> exit_code
docker_stack_down(timeout) -> exit_code
docker_health_check() -> status
docker_logs(service, lines) -> output
```

## 🛡️ **Security Implementation Guidelines**

### Network Security
- Bind all services to 127.0.0.1 only
- Create isolated Docker network
- Disable external network access
- Verify port binding after startup

### File System Security
- Mount journal directory as read-only volume
- Verify read-only permissions
- Prevent any write access to journals
- Monitor file system access

### Container Security
- Run containers with minimal privileges
- Disable privileged mode
- Use non-root users where possible
- Implement resource limits

## 🔗 **Integration Points**

### Vault Integration
- Mount vault directory as read-only volume
- Verify vault is mounted before starting services
- Handle vault unmount during shutdown

### Health Monitoring
- Implement health checks for all services
- Automatic restart on failure
- Graceful shutdown with cleanup verification
- Service dependency management

## 📋 **Docker Compose Configuration**

```yaml
# Key security configurations
networks:
  journals-internal:
    driver: bridge
    internal: true

volumes:
  journals-data:
    driver: local
    driver_opts:
      type: none
      o: bind,ro
      device: /path/to/vault

services:
  ollama:
    ports:
      - "127.0.0.1:11434:11434"
    networks:
      - journals-internal
    volumes:
      - journals-data:/journals:ro
```

## 📚 **Reference Documents**
- **RFC001.md**: Compose configuration and security constraints
- **PRD001.md**: Security requirements and service specifications

## 🧪 **Testing Requirements**
1. Verify all ports are localhost-only
2. Test read-only volume mounting
3. Validate network isolation
4. Test health check functionality
5. Verify graceful shutdown behavior

---

**Document Version**: 1.0  
**Created**: 2025-01-18  
**Phase**: Core Infrastructure  
**Priority**: High
