#!/bin/bash

# webui-security-manager.sh - WebUI Security Configuration and Validation
# 
# This script provides comprehensive security management for the Open WebUI
# including configuration validation, access control, and security monitoring.
#
# Security Features:
# - WebUI security configuration validation
# - Read-only journal access enforcement
# - Network isolation verification
# - Access monitoring and logging
# - Security constraint enforcement
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly DOCKER_MANAGER="$SCRIPT_DIR/docker-manager.sh"
readonly SECURITY_LOG_FILE="${PROJECT_ROOT}/.webui-security.log"
readonly AUDIT_LOG_FILE="${PROJECT_ROOT}/.webui-audit.log"

# WebUI Configuration
readonly WEBUI_PORT="${WEBUI_PORT:-3000}"
readonly OLLAMA_PORT="${OLLAMA_PORT:-11434}"
readonly VAULT_MOUNT_POINT="${VAULT_MOUNT_POINT:-${HOME}/Journals}"
readonly WEBUI_CONTAINER="journals-webui"
readonly OLLAMA_CONTAINER="journals-ollama"

# Security Configuration
readonly MAX_SESSION_DURATION=3600  # 1 hour
readonly MAX_FILE_ACCESS_ATTEMPTS=100
readonly SECURITY_CHECK_INTERVAL=300  # 5 minutes

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user="${USER:-unknown}"
    local hostname=$(hostname)
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            echo "[$timestamp] [ERROR] [$user@$hostname] $message" >> "$SECURITY_LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            echo "[$timestamp] [WARN] [$user@$hostname] $message" >> "$SECURITY_LOG_FILE"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] [$user@$hostname] $message" >> "$SECURITY_LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "[$timestamp] [SUCCESS] [$user@$hostname] $message" >> "$SECURITY_LOG_FILE"
            ;;
        "SECURITY")
            echo -e "${CYAN}[SECURITY]${NC} $message"
            echo "[$timestamp] [SECURITY] [$user@$hostname] $message" >> "$SECURITY_LOG_FILE"
            ;;
    esac
}

# Audit logging
audit_log() {
    local action="$1"
    local target="$2"
    local result="$3"
    local details="${4:-}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user="${USER:-unknown}"
    local hostname=$(hostname)
    
    echo "[$timestamp] [AUDIT] [$user@$hostname] ACTION=$action TARGET=$target RESULT=$result DETAILS=$details" >> "$AUDIT_LOG_FILE"
}

# WebUI Security Configuration Functions

configure_webui_security() {
    log "SECURITY" "Configuring WebUI security settings..."
    
    # Generate secure keys if not set
    if [[ -z "${WEBUI_SECRET_KEY:-}" ]]; then
        export WEBUI_SECRET_KEY=$(openssl rand -hex 32)
        log "INFO" "Generated new WEBUI_SECRET_KEY"
    fi
    
    if [[ -z "${WEBUI_JWT_SECRET_KEY:-}" ]]; then
        export WEBUI_JWT_SECRET_KEY=$(openssl rand -hex 32)
        log "INFO" "Generated new WEBUI_JWT_SECRET_KEY"
    fi
    
    # Validate environment variables
    if ! validate_webui_environment; then
        log "ERROR" "WebUI environment validation failed"
        return 1
    fi
    
    # Configure Docker environment
    if ! configure_docker_environment; then
        log "ERROR" "Docker environment configuration failed"
        return 1
    fi
    
    log "SUCCESS" "WebUI security configuration completed"
    audit_log "CONFIGURE" "webui_security" "SUCCESS" "Security configuration applied"
    return 0
}

validate_webui_environment() {
    log "SECURITY" "Validating WebUI environment configuration..."
    
    local issues=0
    
    # Check required environment variables
    local required_vars=("WEBUI_SECRET_KEY" "WEBUI_JWT_SECRET_KEY" "VAULT_MOUNT_POINT")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log "ERROR" "Required environment variable not set: $var"
            ((issues++))
        fi
    done
    
    # Validate port configuration
    if ! [[ "$WEBUI_PORT" =~ ^[0-9]+$ ]] || [[ $WEBUI_PORT -lt 1024 ]] || [[ $WEBUI_PORT -gt 65535 ]]; then
        log "ERROR" "Invalid WebUI port: $WEBUI_PORT"
        ((issues++))
    fi
    
    # Validate vault mount point
    if [[ ! -d "$VAULT_MOUNT_POINT" ]]; then
        log "ERROR" "Vault mount point does not exist: $VAULT_MOUNT_POINT"
        ((issues++))
    fi
    
    # Check for external network access in environment
    if [[ "${OLLAMA_BASE_URL:-}" == *"0.0.0.0"* ]] || [[ "${OLLAMA_BASE_URL:-}" == *"external"* ]]; then
        log "ERROR" "Ollama base URL configured for external access: ${OLLAMA_BASE_URL:-}"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log "SUCCESS" "WebUI environment validation passed"
        return 0
    else
        log "ERROR" "WebUI environment validation failed ($issues issues)"
        return 1
    fi
}

configure_docker_environment() {
    log "SECURITY" "Configuring Docker environment for WebUI security..."
    
    # Set secure environment variables
    export OLLAMA_BASE_URL="http://ollama:11434"
    export WEBUI_DISABLE_SIGNUP="true"
    export WEBUI_DISABLE_LOGIN_FORM="false"
    export ENABLE_FILE_UPLOAD="false"
    export MAX_FILE_SIZE="0"
    export LOG_LEVEL="WARNING"
    export ENABLE_DEBUG="false"
    
    # Disable all external API integrations
    local disable_apis=(
        "ENABLE_OPENAI_API"
        "ENABLE_ANTHROPIC_API"
        "ENABLE_GOOGLE_API"
        "ENABLE_COHERE_API"
        "ENABLE_AZURE_OPENAI_API"
        "ENABLE_OPENROUTER_API"
        "ENABLE_TABBY_API"
        "ENABLE_LOCAL_WEB_SEARCH"
        "ENABLE_COMMUNITY_SHARING"
        "ENABLE_MESSAGE_RATING"
    )
    
    for api in "${disable_apis[@]}"; do
        export "$api=false"
    done
    
    log "SUCCESS" "Docker environment configured for security"
    return 0
}

# WebUI Security Validation Functions

verify_readonly_mount() {
    log "SECURITY" "Verifying read-only journal mount..."
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^${WEBUI_CONTAINER}$"; then
        log "WARN" "WebUI container not running, cannot verify mount"
        return 1
    fi
    
    # Test write access to journal directory (should fail)
    local write_test
    write_test=$(docker exec "$WEBUI_CONTAINER" touch /journals/security-test-write 2>&1 || echo "write_failed")
    
    if [[ "$write_test" == *"write_failed"* ]] || [[ "$write_test" == *"Read-only"* ]] || [[ "$write_test" == *"Permission denied"* ]]; then
        log "SUCCESS" "Read-only mount verification passed"
        audit_log "VERIFY" "readonly_mount" "SUCCESS" "Write access properly blocked"
        
        # Clean up test file if it was created
        docker exec "$WEBUI_CONTAINER" rm -f /journals/security-test-write 2>/dev/null || true
        return 0
    else
        log "ERROR" "Read-only mount verification failed - write access detected"
        audit_log "VERIFY" "readonly_mount" "FAILED" "Write access not properly blocked"
        return 1
    fi
}

test_network_isolation() {
    log "SECURITY" "Testing WebUI network isolation..."
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^${WEBUI_CONTAINER}$"; then
        log "WARN" "WebUI container not running, cannot test network isolation"
        return 1
    fi
    
    # Test external network access (should fail)
    local external_test
    external_test=$(docker exec "$WEBUI_CONTAINER" ping -c 1 8.8.8.8 2>&1 || echo "ping_failed")
    
    if [[ "$external_test" == *"ping_failed"* ]] || [[ "$external_test" == *"Network unreachable"* ]]; then
        log "SUCCESS" "External network access properly blocked"
        audit_log "VERIFY" "network_isolation" "SUCCESS" "External access blocked"
    else
        log "ERROR" "External network access not properly blocked"
        audit_log "VERIFY" "network_isolation" "FAILED" "External access allowed"
        return 1
    fi
    
    # Test DNS resolution (should fail)
    local dns_test
    dns_test=$(docker exec "$WEBUI_CONTAINER" nslookup google.com 2>&1 || echo "dns_failed")
    
    if [[ "$dns_test" == *"dns_failed"* ]] || [[ "$dns_test" == *"Name or service not known"* ]]; then
        log "SUCCESS" "DNS resolution properly blocked"
        audit_log "VERIFY" "dns_isolation" "SUCCESS" "DNS resolution blocked"
    else
        log "ERROR" "DNS resolution not properly blocked"
        audit_log "VERIFY" "dns_isolation" "FAILED" "DNS resolution allowed"
        return 1
    fi
    
    return 0
}

validate_ollama_connection() {
    log "SECURITY" "Validating Ollama connection security..."
    
    # Check if Ollama is accessible from WebUI
    local ollama_test
    ollama_test=$(docker exec "$WEBUI_CONTAINER" curl -f "http://ollama:11434/api/tags" 2>&1 || echo "connection_failed")
    
    if [[ "$ollama_test" == *"connection_failed"* ]]; then
        log "ERROR" "WebUI cannot connect to Ollama"
        audit_log "VERIFY" "ollama_connection" "FAILED" "Connection failed"
        return 1
    fi
    
    # Verify Ollama is bound to localhost only
    local ollama_binding
    ollama_binding=$(netstat -an 2>/dev/null | grep -c "127.0.0.1:$OLLAMA_PORT" || echo "0")
    
    if [[ "$ollama_binding" -gt 0 ]]; then
        log "SUCCESS" "Ollama properly bound to localhost"
        audit_log "VERIFY" "ollama_binding" "SUCCESS" "Localhost binding confirmed"
    else
        log "ERROR" "Ollama not bound to localhost"
        audit_log "VERIFY" "ollama_binding" "FAILED" "Not bound to localhost"
        return 1
    fi
    
    # Check for external Ollama binding (security violation)
    local ollama_external
    ollama_external=$(netstat -an 2>/dev/null | grep -c "0.0.0.0:$OLLAMA_PORT" || echo "0")
    
    if [[ "$ollama_external" -gt 0 ]]; then
        log "ERROR" "Ollama bound to external interfaces (security violation)"
        audit_log "VERIFY" "ollama_external" "VIOLATION" "External binding detected"
        return 1
    else
        log "SUCCESS" "Ollama not bound to external interfaces"
        audit_log "VERIFY" "ollama_external" "SUCCESS" "No external binding"
    fi
    
    return 0
}

# WebUI Access Monitoring Functions

monitor_access_attempts() {
    log "SECURITY" "Starting WebUI access monitoring..."
    
    local check_interval="${1:-$SECURITY_CHECK_INTERVAL}"
    local max_attempts="${2:-$MAX_FILE_ACCESS_ATTEMPTS}"
    
    while true; do
        # Monitor file access attempts
        monitor_file_access "$max_attempts"
        
        # Monitor network connections
        monitor_network_connections
        
        # Monitor container security
        monitor_container_security
        
        # Check for security violations
        check_security_violations
        
        sleep "$check_interval"
    done
}

monitor_file_access() {
    local max_attempts="$1"
    
    # Count file access attempts in the last hour
    local access_count
    access_count=$(grep -c "file.*access" "$SECURITY_LOG_FILE" 2>/dev/null || echo "0")
    
    if [[ $access_count -gt $max_attempts ]]; then
        log "WARN" "Excessive file access attempts detected: $access_count"
        audit_log "MONITOR" "file_access" "WARN" "Excessive attempts: $access_count"
    fi
}

monitor_network_connections() {
    # Check for external connections
    local external_connections
    external_connections=$(netstat -an 2>/dev/null | grep -c "ESTABLISHED.*[^127.0.0.1]" || echo "0")
    
    if [[ $external_connections -gt 0 ]]; then
        log "WARN" "External network connections detected: $external_connections"
        audit_log "MONITOR" "network" "WARN" "External connections: $external_connections"
    fi
}

monitor_container_security() {
    # Check if containers are running as expected
    if ! docker ps --format "table {{.Names}}" | grep -q "^${WEBUI_CONTAINER}$"; then
        log "ERROR" "WebUI container not running"
        audit_log "MONITOR" "container" "ERROR" "WebUI container down"
        return 1
    fi
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^${OLLAMA_CONTAINER}$"; then
        log "ERROR" "Ollama container not running"
        audit_log "MONITOR" "container" "ERROR" "Ollama container down"
        return 1
    fi
    
    # Check container security settings
    local webui_readonly
    webui_readonly=$(docker inspect "$WEBUI_CONTAINER" --format='{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null || echo "unknown")
    
    if [[ "$webui_readonly" != "true" ]]; then
        log "WARN" "WebUI container not running with read-only filesystem"
        audit_log "MONITOR" "container" "WARN" "WebUI not read-only"
    fi
}

check_security_violations() {
    # Check for security violations in logs
    local violations
    violations=$(grep -c "VIOLATION\|violation" "$SECURITY_LOG_FILE" 2>/dev/null || echo "0")
    
    if [[ $violations -gt 0 ]]; then
        log "ERROR" "Security violations detected: $violations"
        audit_log "MONITOR" "violations" "ERROR" "Count: $violations"
    fi
}

# WebUI Security Testing Functions

run_webui_security_tests() {
    log "SECURITY" "Running comprehensive WebUI security tests..."
    
    local test_results=0
    
    # Test 1: Read-only mount verification
    if verify_readonly_mount; then
        log "SUCCESS" "✓ Read-only mount test passed"
    else
        log "ERROR" "✗ Read-only mount test failed"
        ((test_results++))
    fi
    
    # Test 2: Network isolation verification
    if test_network_isolation; then
        log "SUCCESS" "✓ Network isolation test passed"
    else
        log "ERROR" "✗ Network isolation test failed"
        ((test_results++))
    fi
    
    # Test 3: Ollama connection security
    if validate_ollama_connection; then
        log "SUCCESS" "✓ Ollama connection security test passed"
    else
        log "ERROR" "✗ Ollama connection security test failed"
        ((test_results++))
    fi
    
    # Test 4: Port binding security
    if test_port_binding_security; then
        log "SUCCESS" "✓ Port binding security test passed"
    else
        log "ERROR" "✗ Port binding security test failed"
        ((test_results++))
    fi
    
    # Test 5: Container security
    if test_container_security; then
        log "SUCCESS" "✓ Container security test passed"
    else
        log "ERROR" "✗ Container security test failed"
        ((test_results++))
    fi
    
    if [[ $test_results -eq 0 ]]; then
        log "SUCCESS" "All WebUI security tests passed!"
        audit_log "TEST" "webui_security" "SUCCESS" "All tests passed"
        return 0
    else
        log "ERROR" "$test_results WebUI security tests failed"
        audit_log "TEST" "webui_security" "FAILED" "Tests failed: $test_results"
        return 1
    fi
}

test_port_binding_security() {
    log "SECURITY" "Testing port binding security..."
    
    # Check WebUI port binding
    local webui_localhost
    webui_localhost=$(netstat -an 2>/dev/null | grep -c "127.0.0.1:$WEBUI_PORT" || echo "0")
    
    if [[ "$webui_localhost" -gt 0 ]]; then
        log "SUCCESS" "WebUI bound to localhost only"
        audit_log "VERIFY" "port_binding" "SUCCESS" "WebUI localhost binding"
    else
        log "ERROR" "WebUI not bound to localhost"
        audit_log "VERIFY" "port_binding" "FAILED" "WebUI not localhost"
        return 1
    fi
    
    # Check for external WebUI binding (security violation)
    local webui_external
    webui_external=$(netstat -an 2>/dev/null | grep -c "0.0.0.0:$WEBUI_PORT" || echo "0")
    
    if [[ "$webui_external" -gt 0 ]]; then
        log "ERROR" "WebUI bound to external interfaces (security violation)"
        audit_log "VERIFY" "port_binding" "VIOLATION" "WebUI external binding"
        return 1
    else
        log "SUCCESS" "WebUI not bound to external interfaces"
        audit_log "VERIFY" "port_binding" "SUCCESS" "No WebUI external binding"
    fi
    
    return 0
}

test_container_security() {
    log "SECURITY" "Testing container security..."
    
    # Check WebUI container user
    local webui_user
    webui_user=$(docker exec "$WEBUI_CONTAINER" id -u 2>/dev/null || echo "unknown")
    
    if [[ "$webui_user" == "1000" ]]; then
        log "SUCCESS" "WebUI running as non-root user (UID: $webui_user)"
        audit_log "VERIFY" "container_user" "SUCCESS" "WebUI non-root: $webui_user"
    else
        log "ERROR" "WebUI running as root or unknown user (UID: $webui_user)"
        audit_log "VERIFY" "container_user" "FAILED" "WebUI user: $webui_user"
        return 1
    fi
    
    # Check WebUI container privileges
    local webui_privileged
    webui_privileged=$(docker inspect "$WEBUI_CONTAINER" --format='{{.HostConfig.Privileged}}' 2>/dev/null || echo "unknown")
    
    if [[ "$webui_privileged" == "false" ]]; then
        log "SUCCESS" "WebUI not running in privileged mode"
        audit_log "VERIFY" "container_privileged" "SUCCESS" "WebUI not privileged"
    else
        log "ERROR" "WebUI running in privileged mode"
        audit_log "VERIFY" "container_privileged" "FAILED" "WebUI privileged"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    local command="${1:-}"
    
    case "$command" in
        "configure")
            configure_webui_security
            ;;
        "verify")
            verify_readonly_mount
            ;;
        "test")
            test_network_isolation
            ;;
        "validate")
            validate_ollama_connection
            ;;
        "monitor")
            local interval="${2:-$SECURITY_CHECK_INTERVAL}"
            monitor_access_attempts "$interval"
            ;;
        "run-tests")
            run_webui_security_tests
            ;;
        "help"|"--help"|"-h")
            cat << EOF
WebUI Security Manager

Usage: $0 <command> [options]

Commands:
  configure              Configure WebUI security settings
  verify                 Verify read-only journal mount
  test                   Test network isolation
  validate               Validate Ollama connection security
  monitor [interval]     Start access monitoring (default: 300s)
  run-tests              Run comprehensive security tests
  help                   Show this help message

Security Features:
  - Read-only journal access enforcement
  - Network isolation verification
  - Access monitoring and logging
  - Security constraint enforcement
  - Container security validation

Examples:
  $0 configure           # Configure WebUI security
  $0 run-tests           # Run all security tests
  $0 monitor 600         # Monitor with 10-minute intervals
  $0 verify              # Verify read-only mount

EOF
            ;;
        "")
            log "ERROR" "No command specified. Use '$0 help' for usage information."
            exit 1
            ;;
        *)
            log "ERROR" "Unknown command: $command. Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

