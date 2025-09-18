#!/bin/bash

# test-security-validation.sh - Security Validation Test Suite
# 
# This script provides comprehensive security validation for the Docker orchestration system
# including network isolation, access control, data protection, and security constraints.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DOCKER_MANAGER="$PROJECT_ROOT/src/docker/docker-manager.sh"
readonly VAULT_MANAGER="$PROJECT_ROOT/src/vault/vault-manager.sh"
readonly SECURITY_LOG_FILE="/tmp/security-validation.log"

# Test configuration
readonly SECURITY_TIMEOUT=180
readonly NETWORK_TEST_TIMEOUT=30
readonly FILE_ACCESS_TEST_TIMEOUT=60

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Security test counters
SECURITY_TESTS_PASSED=0
SECURITY_TESTS_FAILED=0
SECURITY_TESTS_SKIPPED=0
SECURITY_VIOLATIONS=0

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            echo "[$timestamp] [ERROR] $message" >> "$SECURITY_LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            echo "[$timestamp] [WARN] $message" >> "$SECURITY_LOG_FILE"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] $message" >> "$SECURITY_LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "[$timestamp] [SUCCESS] $message" >> "$SECURITY_LOG_FILE"
            ;;
        "SECURITY")
            echo -e "${CYAN}[SECURITY]${NC} $message"
            echo "[$timestamp] [SECURITY] $message" >> "$SECURITY_LOG_FILE"
            ;;
        "VIOLATION")
            echo -e "${RED}[VIOLATION]${NC} $message" >&2
            echo "[$timestamp] [VIOLATION] $message" >> "$SECURITY_LOG_FILE"
            ((SECURITY_VIOLATIONS++))
            ;;
    esac
}

# Security test result functions
security_pass() {
    local test_name="$1"
    local message="${2:-}"
    ((SECURITY_TESTS_PASSED++))
    log "SUCCESS" "PASS: $test_name${message:+ - $message}"
}

security_fail() {
    local test_name="$1"
    local message="${2:-}"
    ((SECURITY_TESTS_FAILED++))
    log "ERROR" "FAIL: $test_name${message:+ - $message}"
}

security_skip() {
    local test_name="$1"
    local message="${2:-}"
    ((SECURITY_TESTS_SKIPPED++))
    log "WARN" "SKIP: $test_name${message:+ - $message}"
}

security_violation() {
    local test_name="$1"
    local message="${2:-}"
    ((SECURITY_TESTS_FAILED++))
    log "VIOLATION" "VIOLATION: $test_name${message:+ - $message}"
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up security test environment..."
    
    # Stop Docker stack if running
    if "$DOCKER_MANAGER" health >/dev/null 2>&1; then
        log "INFO" "Stopping Docker stack..."
        "$DOCKER_MANAGER" down 30 >/dev/null 2>&1 || true
    fi
    
    # Clean up test resources
    "$DOCKER_MANAGER" cleanup >/dev/null 2>&1 || true
    
    log "INFO" "Security test cleanup completed"
}

# Trap for cleanup on exit
trap cleanup EXIT

# Check security prerequisites
check_security_prerequisites() {
    log "SECURITY" "Checking security test prerequisites..."
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        security_fail "prerequisites" "Docker is not installed"
        return 1
    fi
    
    # Check if required scripts exist
    if [[ ! -f "$DOCKER_MANAGER" ]]; then
        security_fail "prerequisites" "Docker manager script not found"
        return 1
    fi
    
    # Check if netstat is available for network testing
    if ! command -v netstat >/dev/null 2>&1; then
        security_skip "prerequisites" "netstat not available for network testing"
    fi
    
    # Check if curl is available for connectivity testing
    if ! command -v curl >/dev/null 2>&1; then
        security_fail "prerequisites" "curl is required for connectivity testing"
        return 1
    fi
    
    security_pass "prerequisites" "Security test prerequisites met"
    return 0
}

# Test network isolation
test_network_isolation() {
    log "SECURITY" "Testing network isolation..."
    
    # Start Docker stack for testing
    if ! "$DOCKER_MANAGER" up >/dev/null 2>&1; then
        security_skip "network_isolation" "Cannot start Docker stack for testing"
        return 0
    fi
    
    # Wait for services to be ready
    local timeout=60
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $timeout ]]; then
            security_skip "network_isolation" "Services did not become ready for testing"
            return 0
        fi
        
        if curl -f "http://127.0.0.1:${OLLAMA_PORT:-11434}/api/tags" >/dev/null 2>&1; then
            break
        fi
        
        sleep 2
    done
    
    # Test external network access from Ollama
    log "SECURITY" "Testing Ollama external network access..."
    if docker exec journals-ollama ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        security_violation "network_isolation_ollama" "Ollama can access external networks"
    else
        security_pass "network_isolation_ollama" "Ollama cannot access external networks"
    fi
    
    # Test external network access from WebUI
    log "SECURITY" "Testing WebUI external network access..."
    if docker exec journals-webui ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        security_violation "network_isolation_webui" "WebUI can access external networks"
    else
        security_pass "network_isolation_webui" "WebUI cannot access external networks"
    fi
    
    # Test DNS resolution
    log "SECURITY" "Testing DNS resolution..."
    if docker exec journals-ollama nslookup google.com >/dev/null 2>&1; then
        security_violation "dns_resolution" "Containers can resolve external DNS"
    else
        security_pass "dns_resolution" "Containers cannot resolve external DNS"
    fi
    
    # Test HTTP external access
    log "SECURITY" "Testing HTTP external access..."
    if docker exec journals-ollama curl -f "http://httpbin.org/ip" >/dev/null 2>&1; then
        security_violation "http_external_access" "Containers can make external HTTP requests"
    else
        security_pass "http_external_access" "Containers cannot make external HTTP requests"
    fi
}

# Test port binding security
test_port_binding_security() {
    log "SECURITY" "Testing port binding security..."
    
    # Check for localhost-only binding
    local ollama_localhost
    ollama_localhost=$(netstat -an 2>/dev/null | grep -c "127.0.0.1:${OLLAMA_PORT:-11434}" || echo "0")
    
    if [[ "$ollama_localhost" -gt 0 ]]; then
        security_pass "port_binding_ollama_localhost" "Ollama bound to localhost only"
    else
        security_violation "port_binding_ollama_localhost" "Ollama not bound to localhost"
    fi
    
    local webui_localhost
    webui_localhost=$(netstat -an 2>/dev/null | grep -c "127.0.0.1:${WEBUI_PORT:-3000}" || echo "0")
    
    if [[ "$webui_localhost" -gt 0 ]]; then
        security_pass "port_binding_webui_localhost" "WebUI bound to localhost only"
    else
        security_violation "port_binding_webui_localhost" "WebUI not bound to localhost"
    fi
    
    # Check for external binding (security violation)
    local ollama_external
    ollama_external=$(netstat -an 2>/dev/null | grep -c "0.0.0.0:${OLLAMA_PORT:-11434}" || echo "0")
    
    if [[ "$ollama_external" -gt 0 ]]; then
        security_violation "port_binding_ollama_external" "Ollama bound to external interfaces"
    else
        security_pass "port_binding_ollama_external" "Ollama not bound to external interfaces"
    fi
    
    local webui_external
    webui_external=$(netstat -an 2>/dev/null | grep -c "0.0.0.0:${WEBUI_PORT:-3000}" || echo "0")
    
    if [[ "$webui_external" -gt 0 ]]; then
        security_violation "port_binding_webui_external" "WebUI bound to external interfaces"
    else
        security_pass "port_binding_webui_external" "WebUI not bound to external interfaces"
    fi
    
    # Check for any other external bindings
    local any_external
    any_external=$(netstat -an 2>/dev/null | grep -c "0.0.0.0:" || echo "0")
    
    if [[ "$any_external" -gt 0 ]]; then
        log "WARN" "Found $any_external external port bindings (may be system services)"
    fi
}

# Test container security
test_container_security() {
    log "SECURITY" "Testing container security..."
    
    # Check if containers are running as non-root
    local ollama_user
    ollama_user=$(docker exec journals-ollama id -u 2>/dev/null || echo "unknown")
    
    if [[ "$ollama_user" == "1000" ]]; then
        security_pass "container_user_ollama" "Ollama running as non-root user (UID: $ollama_user)"
    else
        security_violation "container_user_ollama" "Ollama running as root or unknown user (UID: $ollama_user)"
    fi
    
    local webui_user
    webui_user=$(docker exec journals-webui id -u 2>/dev/null || echo "unknown")
    
    if [[ "$webui_user" == "1000" ]]; then
        security_pass "container_user_webui" "WebUI running as non-root user (UID: $webui_user)"
    else
        security_violation "container_user_webui" "WebUI running as root or unknown user (UID: $webui_user)"
    fi
    
    # Check for privileged mode
    local ollama_privileged
    ollama_privileged=$(docker inspect journals-ollama --format='{{.HostConfig.Privileged}}' 2>/dev/null || echo "unknown")
    
    if [[ "$ollama_privileged" == "false" ]]; then
        security_pass "container_privileged_ollama" "Ollama not running in privileged mode"
    else
        security_violation "container_privileged_ollama" "Ollama running in privileged mode"
    fi
    
    local webui_privileged
    webui_privileged=$(docker inspect journals-webui --format='{{.HostConfig.Privileged}}' 2>/dev/null || echo "unknown")
    
    if [[ "$webui_privileged" == "false" ]]; then
        security_pass "container_privileged_webui" "WebUI not running in privileged mode"
    else
        security_violation "container_privileged_webui" "WebUI running in privileged mode"
    fi
    
    # Check for read-only filesystem
    local webui_readonly
    webui_readonly=$(docker inspect journals-webui --format='{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null || echo "unknown")
    
    if [[ "$webui_readonly" == "true" ]]; then
        security_pass "container_readonly_webui" "WebUI running with read-only filesystem"
    else
        security_fail "container_readonly_webui" "WebUI not running with read-only filesystem"
    fi
}

# Test volume security
test_volume_security() {
    log "SECURITY" "Testing volume security..."
    
    # Check if journals volume is mounted read-only
    local ollama_write_test
    ollama_write_test=$(docker exec journals-ollama touch /journals/security-test-write 2>&1 || echo "write_failed")
    
    if [[ "$ollama_write_test" == *"write_failed"* ]] || [[ "$ollama_write_test" == *"Read-only"* ]]; then
        security_pass "volume_readonly_ollama" "Journals volume is read-only in Ollama container"
    else
        security_violation "volume_readonly_ollama" "Journals volume is writable in Ollama container"
    fi
    
    # Clean up test file if it was created
    docker exec journals-ollama rm -f /journals/security-test-write 2>/dev/null || true
    
    local webui_write_test
    webui_write_test=$(docker exec journals-webui touch /journals/security-test-write 2>&1 || echo "write_failed")
    
    if [[ "$webui_write_test" == *"write_failed"* ]] || [[ "$webui_write_test" == *"Read-only"* ]]; then
        security_pass "volume_readonly_webui" "Journals volume is read-only in WebUI container"
    else
        security_violation "volume_readonly_webui" "Journals volume is writable in WebUI container"
    fi
    
    # Clean up test file if it was created
    docker exec journals-webui rm -f /journals/security-test-write 2>/dev/null || true
    
    # Check if journals volume is accessible
    local ollama_read_test
    ollama_read_test=$(docker exec journals-ollama ls /journals >/dev/null 2>&1 && echo "readable" || echo "not_readable")
    
    if [[ "$ollama_read_test" == "readable" ]]; then
        security_pass "volume_access_ollama" "Journals volume is accessible in Ollama container"
    else
        security_fail "volume_access_ollama" "Journals volume is not accessible in Ollama container"
    fi
    
    local webui_read_test
    webui_read_test=$(docker exec journals-webui ls /journals >/dev/null 2>&1 && echo "readable" || echo "not_readable")
    
    if [[ "$webui_read_test" == "readable" ]]; then
        security_pass "volume_access_webui" "Journals volume is accessible in WebUI container"
    else
        security_fail "volume_access_webui" "Journals volume is not accessible in WebUI container"
    fi
}

# Test data protection
test_data_protection() {
    log "SECURITY" "Testing data protection..."
    
    # Check if sensitive data is in logs
    local log_contains_passwords
    log_contains_passwords=$(grep -i "password\|passphrase\|secret" "$SECURITY_LOG_FILE" 2>/dev/null | wc -l || echo "0")
    
    if [[ "$log_contains_passwords" -eq 0 ]]; then
        security_pass "log_data_protection" "No sensitive data found in logs"
    else
        security_violation "log_data_protection" "Sensitive data found in logs ($log_contains_passwords occurrences)"
    fi
    
    # Check if environment variables contain sensitive data
    local env_sensitive
    env_sensitive=$(docker exec journals-ollama env 2>/dev/null | grep -i "password\|passphrase\|secret\|key" | wc -l || echo "0")
    
    if [[ "$env_sensitive" -eq 0 ]]; then
        security_pass "env_data_protection" "No sensitive data in environment variables"
    else
        security_violation "env_data_protection" "Sensitive data found in environment variables ($env_sensitive occurrences)"
    fi
    
    # Check if containers can access host filesystem
    local host_fs_access
    host_fs_access=$(docker exec journals-ollama ls /host 2>/dev/null && echo "accessible" || echo "not_accessible")
    
    if [[ "$host_fs_access" == "not_accessible" ]]; then
        security_pass "host_fs_protection" "Containers cannot access host filesystem"
    else
        security_violation "host_fs_protection" "Containers can access host filesystem"
    fi
}

# Test access control
test_access_control() {
    log "SECURITY" "Testing access control..."
    
    # Check if services are accessible from external interfaces
    local ollama_external_access
    ollama_external_access=$(curl -f "http://0.0.0.0:${OLLAMA_PORT:-11434}/api/tags" >/dev/null 2>&1 && echo "accessible" || echo "not_accessible")
    
    if [[ "$ollama_external_access" == "not_accessible" ]]; then
        security_pass "access_control_ollama" "Ollama not accessible from external interfaces"
    else
        security_violation "access_control_ollama" "Ollama accessible from external interfaces"
    fi
    
    local webui_external_access
    webui_external_access=$(curl -f "http://0.0.0.0:${WEBUI_PORT:-3000}/" >/dev/null 2>&1 && echo "accessible" || echo "not_accessible")
    
    if [[ "$webui_external_access" == "not_accessible" ]]; then
        security_pass "access_control_webui" "WebUI not accessible from external interfaces"
    else
        security_violation "access_control_webui" "WebUI accessible from external interfaces"
    fi
    
    # Check if services are accessible from localhost
    local ollama_localhost_access
    ollama_localhost_access=$(curl -f "http://127.0.0.1:${OLLAMA_PORT:-11434}/api/tags" >/dev/null 2>&1 && echo "accessible" || echo "not_accessible")
    
    if [[ "$ollama_localhost_access" == "accessible" ]]; then
        security_pass "access_control_ollama_localhost" "Ollama accessible from localhost"
    else
        security_fail "access_control_ollama_localhost" "Ollama not accessible from localhost"
    fi
    
    local webui_localhost_access
    webui_localhost_access=$(curl -f "http://127.0.0.1:${WEBUI_PORT:-3000}/" >/dev/null 2>&1 && echo "accessible" || echo "not_accessible")
    
    if [[ "$webui_localhost_access" == "accessible" ]]; then
        security_pass "access_control_webui_localhost" "WebUI accessible from localhost"
    else
        security_fail "access_control_webui_localhost" "WebUI not accessible from localhost"
    fi
}

# Test encryption and data integrity
test_encryption_integrity() {
    log "SECURITY" "Testing encryption and data integrity..."
    
    # Check if vault is encrypted
    local vault_status
    vault_status=$("$VAULT_MANAGER" status 2>/dev/null || echo "unmounted")
    
    if [[ "$vault_status" == "mounted" ]]; then
        security_pass "vault_encryption" "Vault is mounted (encrypted)"
        
        # Check if vault files are accessible
        if [[ -d "${VAULT_MOUNT_POINT:-${HOME}/Journals}" ]] && ls "${VAULT_MOUNT_POINT:-${HOME}/Journals}" >/dev/null 2>&1; then
            security_pass "vault_access" "Vault files are accessible"
        else
            security_fail "vault_access" "Vault files are not accessible"
        fi
    else
        security_skip "vault_encryption" "Vault is not mounted for testing"
    fi
    
    # Check if containers use encrypted communication
    # This is a basic check - in a real scenario, you'd want to verify TLS/SSL
    local ollama_https
    ollama_https=$(curl -k -f "https://127.0.0.1:${OLLAMA_PORT:-11434}/api/tags" >/dev/null 2>&1 && echo "https_supported" || echo "http_only")
    
    if [[ "$ollama_https" == "http_only" ]]; then
        security_fail "encryption_ollama" "Ollama not using HTTPS (local only, but should be configurable)"
    else
        security_pass "encryption_ollama" "Ollama supports HTTPS"
    fi
}

# Generate security report
generate_security_report() {
    echo
    log "SECURITY" "=== Security Validation Report ==="
    echo -e "${CYAN}Security Tests Passed:${NC} $SECURITY_TESTS_PASSED"
    echo -e "${CYAN}Security Tests Failed:${NC} $SECURITY_TESTS_FAILED"
    echo -e "${CYAN}Security Tests Skipped:${NC} $SECURITY_TESTS_SKIPPED"
    echo -e "${CYAN}Security Violations:${NC} $SECURITY_VIOLATIONS"
    echo -e "${CYAN}Total Security Tests:${NC} $((SECURITY_TESTS_PASSED + SECURITY_TESTS_FAILED + SECURITY_TESTS_SKIPPED))"
    echo
    
    if [[ $SECURITY_VIOLATIONS -eq 0 && $SECURITY_TESTS_FAILED -eq 0 ]]; then
        log "SUCCESS" "All security tests passed! No violations detected."
        return 0
    elif [[ $SECURITY_VIOLATIONS -gt 0 ]]; then
        log "VIOLATION" "Security violations detected! Check the log for details: $SECURITY_LOG_FILE"
        return 1
    else
        log "ERROR" "Some security tests failed. Check the log for details: $SECURITY_LOG_FILE"
        return 1
    fi
}

# Main security test function
run_security_tests() {
    log "SECURITY" "Starting Security Validation Tests..."
    echo
    
    # Initialize security log
    echo "Security Validation Test Log - $(date)" > "$SECURITY_LOG_FILE"
    echo "================================================" >> "$SECURITY_LOG_FILE"
    echo >> "$SECURITY_LOG_FILE"
    
    # Run security test suites
    check_security_prerequisites || return 1
    test_network_isolation
    test_port_binding_security
    test_container_security
    test_volume_security
    test_data_protection
    test_access_control
    test_encryption_integrity
    
    # Generate report
    generate_security_report
}

# Main function
main() {
    local command="${1:-}"
    
    case "$command" in
        "run")
            run_security_tests
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"--help"|"-h")
            cat << EOF
Security Validation Test Suite

Usage: $0 <command>

Commands:
  run            Run all security tests
  cleanup        Clean up test environment
  help           Show this help message

Security Test Categories:
  - Network isolation validation
  - Port binding security
  - Container security (user, privileges, filesystem)
  - Volume security (read-only, access control)
  - Data protection (logs, environment, filesystem)
  - Access control (external vs localhost)
  - Encryption and data integrity

Examples:
  $0 run         # Run all security tests
  $0 cleanup     # Clean up test environment

EOF
            ;;
        "")
            run_security_tests
            ;;
        *)
            log "ERROR" "Unknown command: $command. Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
