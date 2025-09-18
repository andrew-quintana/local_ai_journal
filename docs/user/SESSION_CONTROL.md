# Session Control Scripts Documentation

## Overview

The session control scripts provide complete management of the Journals Infrastructure, including secure startup, graceful shutdown, and comprehensive status reporting. These scripts implement the core user-facing functionality for the journaling system.

## Scripts

### `journals-up.sh` - System Startup

**Purpose**: Complete system startup with comprehensive pre-flight checks and error handling.

**Features**:
- Pre-flight system checks (Docker, vault, ports, resources)
- Interactive vault mounting with secure passphrase entry
- Docker stack startup with health verification
- AI model management and service readiness validation
- Comprehensive error handling and rollback mechanisms

**Usage**:
```bash
./bin/journals-up.sh
```

**Environment Variables**:
- `HEALTH_CHECK_TIMEOUT`: Health check timeout in seconds (default: 120)
- `GRACEFUL_SHUTDOWN_TIMEOUT`: Graceful shutdown timeout in seconds (default: 30)
- `OLLAMA_MODEL`: Default AI model to use (default: llama3.2:3b)
- `VAULT_MOUNT_POINT`: Vault mount point (default: ~/Journals)

### `journals-down.sh` - System Shutdown

**Purpose**: Graceful system shutdown with secure cleanup and verification.

**Features**:
- Graceful Docker container shutdown with timeout handling
- Secure vault unmounting with verification
- Resource cleanup and status reporting
- Comprehensive error handling and recovery
- Force stop capability if graceful shutdown fails

**Usage**:
```bash
./bin/journals-down.sh [timeout]
```

**Parameters**:
- `timeout`: Graceful shutdown timeout in seconds (default: 30)

**Environment Variables**:
- `GRACEFUL_SHUTDOWN_TIMEOUT`: Default graceful shutdown timeout (default: 30)
- `FORCE_SHUTDOWN_TIMEOUT`: Force shutdown timeout (default: 10)
- `CLEANUP_TIMEOUT`: Cleanup operation timeout (default: 15)

### `journals-status.sh` - Status Reporting

**Purpose**: Comprehensive system status reporting and health monitoring.

**Features**:
- Complete system status overview
- Individual component status (vault, Docker, ports, security)
- Performance metrics and resource usage
- Service URLs and management commands
- Security validation and compliance checking

**Usage**:
```bash
./bin/journals-status.sh [command]
```

**Commands**:
- `(no command)`: Show complete status report
- `vault`: Show vault status only
- `docker`: Show Docker services status only
- `ports`: Show port binding status only
- `security`: Show security status only
- `system`: Show system information only
- `urls`: Show service URLs only
- `commands`: Show management commands only
- `performance`: Show performance metrics only
- `help`: Show help message

**Environment Variables**:
- `OLLAMA_PORT`: Ollama service port (default: 11434)
- `WEBUI_PORT`: WebUI service port (default: 3000)
- `VAULT_MOUNT_POINT`: Vault mount point (default: ~/Journals)

## Security Features

### Passphrase Handling
- Interactive passphrase entry using `read -s` for secure input
- Passphrases are never logged or stored
- Passphrase variables are cleared after use
- Graceful handling of interruption during passphrase entry

### Network Security
- All services bound to localhost only (127.0.0.1)
- No external network access enabled
- Port binding validation and security checks
- Network isolation verification

### Data Protection
- Journal files mounted read-only to AI services
- Vault encryption with AES-256
- No sensitive data in logs or temporary files
- Secure cleanup on shutdown

## Error Handling

### Startup Errors
- Comprehensive pre-flight checks before starting services
- Atomic operations with rollback capability
- Clear error messages with actionable guidance
- Automatic recovery where possible

### Shutdown Errors
- Graceful shutdown with timeout handling
- Force stop if graceful shutdown fails
- Resource cleanup even on failure
- Status verification and reporting

### Recovery Mechanisms
- Automatic rollback on startup failure
- Force stop capability for stuck services
- Resource cleanup on interruption
- Status verification after operations

## System Requirements

### Minimum Requirements
- **Memory**: 8GB RAM minimum
- **Disk Space**: 10GB available space
- **OS**: macOS 10.15+ (for APFS support)
- **Docker**: Docker Desktop 4.0+ or Docker Engine with Compose

### Prerequisites
- Docker daemon running
- Docker Compose available
- Required ports available (11434, 3000)
- Sufficient system resources

## Usage Examples

### Basic Usage
```bash
# Start the system
./bin/journals-up.sh

# Check status
./bin/journals-status.sh

# Stop the system
./bin/journals-down.sh
```

### Advanced Usage
```bash
# Start with custom timeout
HEALTH_CHECK_TIMEOUT=180 ./bin/journals-up.sh

# Stop with custom timeout
./bin/journals-down.sh 60

# Check specific status
./bin/journals-status.sh security
./bin/journals-status.sh performance
```

### Troubleshooting
```bash
# Check vault status
./bin/journals-status.sh vault

# Check Docker services
./bin/journals-status.sh docker

# Check port binding
./bin/journals-status.sh ports

# View management commands
./bin/journals-status.sh commands
```

## Testing

### Test Script
A comprehensive test script is available to validate all functionality:

```bash
./tests/test-session-control.sh
```

### Test Coverage
- Script syntax validation
- Help functionality testing
- Status reporting validation
- Error handling testing
- Security validation testing
- Concurrent execution testing
- Timeout handling testing

### Running Tests
```bash
# Run all tests
./tests/test-session-control.sh

# Test log is saved to /tmp/session-control-test.log
```

## Troubleshooting

### Common Issues

#### Startup Issues
- **Docker not running**: Start Docker Desktop or Docker service
- **Port conflicts**: Stop services using required ports
- **Insufficient resources**: Check memory and disk space
- **Vault issues**: Verify vault exists and is accessible

#### Shutdown Issues
- **Containers not stopping**: Use force stop with shorter timeout
- **Vault unmount issues**: Check for processes using vault files
- **Resource cleanup**: Manual cleanup may be required

#### Status Issues
- **Services not responding**: Check Docker container status
- **Port binding issues**: Verify localhost-only binding
- **Security warnings**: Review network configuration

### Debug Information
- Check script logs in `/tmp/` directory
- Use `docker logs` for container-specific issues
- Verify vault status with vault manager
- Check system resources and port availability

## Security Considerations

### Best Practices
- Always use the provided scripts for system management
- Never run services as root user
- Keep Docker and system updated
- Regularly verify security status
- Monitor resource usage

### Security Validation
- All services bound to localhost only
- Journal files mounted read-only
- No external network access
- Encrypted vault storage
- Secure passphrase handling

## Support

### Getting Help
- Use `./bin/journals-status.sh help` for command help
- Check test results for validation
- Review logs for error details
- Consult system requirements

### Reporting Issues
- Include test results and logs
- Specify system configuration
- Describe steps to reproduce
- Provide error messages

---

**Document Version**: 2.0  
**Last Updated**: 2025-09-18  
**Author**: Local Development Team
