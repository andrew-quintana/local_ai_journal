#!/bin/bash

# test-docker-orchestration.sh - Docker Orchestration Security Tests
# 
# This script provides comprehensive testing for the Docker orchestration system
# including security validation, functionality testing, and performance verification.
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
readonly TEST_LOG_FILE="/tmp/docker-orchestration-test.log"

# Test configuration
readonly TEST_TIMEOUT=300
readonly HEALTH_CHECK_TIMEOUT=120
readonly GRACEFUL_SHUTDOWN_TIMEOUT=30

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            echo "[$timestamp] [ERROR] $message" >> "$TEST_LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            echo "[$timestamp] [WARN] $message" >> "$TEST_LOG_FILE"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] $message" >> "$TEST_LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "[$timestamp] [SUCCESS] $message" >> "$TEST_LOG_FILE"
            ;;
        "TEST")
            echo -e "${CYAN}[TEST]${NC} $message"
            echo "[$timestamp] [TEST] $message" >> "$TEST_LOG_FILE"
            ;;
    esac
}

# Test result functions
test_pass() {
    local test_name="$1"
    local message="${2:-}"
    ((TESTS_PASSED++))
    log "SUCCESS" "PASS: $test_name${message:+ - $message}"
}

test_fail() {
    local test_name="$1"
    local message="${2:-}"
    ((TESTS_FAILED++))
    log "ERROR" "FAIL: $test_name${message:+ - $message}"
}

test_skip() {
    local test_name="$1"
    local message="${2:-}"
    ((TESTS_SKIPPED++))
    log "WARN" "SKIP: $test_name${message:+ - $message}"
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up test environment..."
    
    # Stop Docker stack if running
    if "$DOCKER_MANAGER" health >/dev/null 2>&1; then
        log "INFO" "Stopping Docker stack..."
        "$DOCKER_MANAGER" down "$GRACEFUL_SHUTDOWN_TIMEOUT" >/dev/null 2>&1 || true
    fi
    
    # Clean up test resources
    "$DOCKER_MANAGER" cleanup >/dev/null 2>&1 || true
    
    log "INFO" "Cleanup completed"
}

# Trap for cleanup on exit
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log "TEST" "Checking test prerequisites..."
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        test_fail "prerequisites" "Docker is not installed"
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        test_fail "prerequisites" "Docker daemon is not running"
        return 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        test_fail "prerequisites" "Docker Compose is not available"
        return 1
    fi
    
    # Check if required scripts exist
    if [[ ! -f "$DOCKER_MANAGER" ]]; then
        test_fail "prerequisites" "Docker manager script not found"
        return 1
    fi
    
    if [[ ! -f "$VAULT_MANAGER" ]]; then
        test_fail "prerequisites" "Vault manager script not found"
        return 1
    fi
    
    # Make scripts executable
    chmod +x "$DOCKER_MANAGER" "$VAULT_MANAGER"
    
    test_pass "prerequisites" "All prerequisites met"
    return 0
}

# Test vault requirements
test_vault_requirements() {
    log "TEST" "Testing vault requirements..."
    
    # Check if vault is mounted
    local vault_status
    vault_status=$("$VAULT_MANAGER" status 2>/dev/null || echo "unmounted")
    
    if [[ "$vault_status" != "mounted" ]]; then
        test_skip "vault_requirements" "Vault is not mounted (status: $vault_status)"
        return 0
    fi
    
    # Check if vault is readable
    if [[ -d "${VAULT_MOUNT_POINT:-${HOME}/Journals}" ]] && ls "${VAULT_MOUNT_POINT:-${HOME}/Journals}" >/dev/null 2>&1; then
        test_pass "vault_requirements" "Vault is mounted and readable"
    else
        test_fail "vault_requirements" "Vault is mounted but not readable"
    fi
}

# Test Docker stack startup
test_docker_startup() {
    log "TEST" "Testing Docker stack startup..."
    
    # Start Docker stack
    if "$DOCKER_MANAGER" up; then
        test_pass "docker_startup" "Docker stack started successfully"
    else
        test_fail "docker_startup" "Failed to start Docker stack"
        return 1
    fi
    
    # Wait for services to be healthy
    local timeout="$HEALTH_CHECK_TIMEOUT"
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $timeout ]]; then
            test_fail "docker_startup" "Services did not become healthy within ${timeout}s"
            return 1
        fi
        
        local health_status
        health_status=$("$DOCKER_MANAGER" health 2>/dev/null || echo "unhealthy")
        
        case "$health_status" in
            "healthy")
                test_pass "docker_startup" "All services are healthy"
                return 0
                ;;
            "partially_healthy")
                log "INFO" "Some services are healthy, waiting for all..."
                ;;
            "unhealthy")
                log "INFO" "Services are starting up, waiting..."
                ;;
        esac
        
        sleep 5
    done
}

# Test port binding security
test_port_binding_security() {
    log "TEST" "Testing port binding security..."
    
    # Check Ollama port binding
    if netstat -an 2>/dev/null | grep -q "127.0.0.1:${OLLAMA_PORT:-11434}"; then
        test_pass "port_binding_ollama" "Ollama bound to localhost only"
    else
        test_fail "port_binding_ollama" "Ollama not bound to localhost"
    fi
    
    # Check WebUI port binding
    if netstat -an 2>/dev/null | grep -q "127.0.0.1:${WEBUI_PORT:-3000}"; then
        test_pass "port_binding_webui" "WebUI bound to localhost only"
    else
        test_fail "port_binding_webui" "WebUI not bound to localhost"
    fi
    
    # Check for external binding (security violation)
    if netstat -an 2>/dev/null | grep -q "0.0.0.0:${OLLAMA_PORT:-11434}\|0.0.0.0:${WEBUI_PORT:-3000}"; then
        test_fail "port_binding_security" "Services bound to external interfaces (security violation)"
    else
        test_pass "port_binding_security" "No external binding detected"
    fi
}

# Test service connectivity
test_service_connectivity() {
    log "TEST" "Testing service connectivity..."
    
    # Test Ollama API
    if curl -f "http://127.0.0.1:${OLLAMA_PORT:-11434}/api/tags" >/dev/null 2>&1; then
        test_pass "ollama_connectivity" "Ollama API is responding"
    else
        test_fail "ollama_connectivity" "Ollama API is not responding"
    fi
    
    # Test WebUI health endpoint
    if curl -f "http://127.0.0.1:${WEBUI_PORT:-3000}/health" >/dev/null 2>&1; then
        test_pass "webui_connectivity" "WebUI health endpoint is responding"
    else
        test_fail "webui_connectivity" "WebUI health endpoint is not responding"
    fi
    
    # Test WebUI main page
    if curl -f "http://127.0.0.1:${WEBUI_PORT:-3000}/" >/dev/null 2>&1; then
        test_pass "webui_main_page" "WebUI main page is accessible"
    else
        test_fail "webui_main_page" "WebUI main page is not accessible"
    fi
}

# Test volume mounting
test_volume_mounting() {
    log "TEST" "Testing volume mounting..."
    
    # Check if journals volume is mounted in containers
    local ollama_mount
    ollama_mount=$(docker exec journals-ollama ls /journals >/dev/null 2>&1 && echo "yes" || echo "no")
    
    if [[ "$ollama_mount" == "yes" ]]; then
        test_pass "ollama_volume_mount" "Journals volume mounted in Ollama container"
    else
        test_fail "ollama_volume_mount" "Journals volume not mounted in Ollama container"
    fi
    
    local webui_mount
    webui_mount=$(docker exec journals-webui ls /journals >/dev/null 2>&1 && echo "yes" || echo "no")
    
    if [[ "$webui_mount" == "yes" ]]; then
        test_pass "webui_volume_mount" "Journals volume mounted in WebUI container"
    else
        test_fail "webui_volume_mount" "Journals volume not mounted in WebUI container"
    fi
    
    # Test read-only access
    if docker exec journals-ollama touch /journals/test-write 2>/dev/null; then
        test_fail "volume_readonly" "Volume is writable (should be read-only)"
        docker exec journals-ollama rm -f /journals/test-write 2>/dev/null || true
    else
        test_pass "volume_readonly" "Volume is read-only as expected"
    fi
}

# Test network isolation
test_network_isolation() {
    log "TEST" "Testing network isolation..."
    
    # Check if containers can access external networks
    if docker exec journals-ollama ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        test_fail "network_isolation_ollama" "Ollama can access external networks (security violation)"
    else
        test_pass "network_isolation_ollama" "Ollama cannot access external networks"
    fi
    
    if docker exec journals-webui ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        test_fail "network_isolation_webui" "WebUI can access external networks (security violation)"
    else
        test_pass "network_isolation_webui" "WebUI cannot access external networks"
    fi
    
    # Check if containers can communicate with each other
    if docker exec journals-webui curl -f "http://ollama:11434/api/tags" >/dev/null 2>&1; then
        test_pass "container_communication" "Containers can communicate internally"
    else
        test_fail "container_communication" "Containers cannot communicate internally"
    fi
}

# Test Docker stack shutdown
test_docker_shutdown() {
    log "TEST" "Testing Docker stack shutdown..."
    
    # Stop Docker stack
    if "$DOCKER_MANAGER" down "$GRACEFUL_SHUTDOWN_TIMEOUT"; then
        test_pass "docker_shutdown" "Docker stack stopped successfully"
    else
        test_fail "docker_shutdown" "Failed to stop Docker stack"
        return 1
    fi
    
    # Verify services are stopped
    local health_status
    health_status=$("$DOCKER_MANAGER" health 2>/dev/null || echo "unhealthy")
    
    if [[ "$health_status" == "unhealthy" ]]; then
        test_pass "docker_shutdown" "All services stopped successfully"
    else
        test_fail "docker_shutdown" "Some services may still be running"
    fi
}

# Test error handling
test_error_handling() {
    log "TEST" "Testing error handling..."
    
    # Test invalid service name for logs
    if "$DOCKER_MANAGER" logs "nonexistent-service" 2>/dev/null; then
        test_fail "error_handling" "Should fail for invalid service name"
    else
        test_pass "error_handling" "Properly handles invalid service name"
    fi
    
    # Test health check when services are down
    local health_status
    health_status=$("$DOCKER_MANAGER" health 2>/dev/null || echo "unhealthy")
    
    if [[ "$health_status" == "unhealthy" ]]; then
        test_pass "error_handling" "Health check correctly reports unhealthy when down"
    else
        test_fail "error_handling" "Health check should report unhealthy when down"
    fi
}

# Test performance
test_performance() {
    log "TEST" "Testing performance..."
    
    # Start services for performance testing
    if ! "$DOCKER_MANAGER" up >/dev/null 2>&1; then
        test_skip "performance" "Cannot start services for performance testing"
        return 0
    fi
    
    # Wait for services to be ready
    local timeout=60
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $timeout ]]; then
            test_skip "performance" "Services did not become ready for performance testing"
            return 0
        fi
        
        if curl -f "http://127.0.0.1:${OLLAMA_PORT:-11434}/api/tags" >/dev/null 2>&1; then
            break
        fi
        
        sleep 2
    done
    
    # Test startup time
    local startup_time=$((current_time - start_time))
    
    if [[ $startup_time -le 60 ]]; then
        test_pass "performance_startup" "Startup time acceptable: ${startup_time}s"
    else
        test_fail "performance_startup" "Startup time too slow: ${startup_time}s"
    fi
    
    # Test API response time
    local api_start=$(date +%s%3N)
    if curl -f "http://127.0.0.1:${OLLAMA_PORT:-11434}/api/tags" >/dev/null 2>&1; then
        local api_end=$(date +%s%3N)
        local api_time=$((api_end - api_start))
        
        if [[ $api_time -le 1000 ]]; then
            test_pass "performance_api" "API response time acceptable: ${api_time}ms"
        else
            test_fail "performance_api" "API response time too slow: ${api_time}ms"
        fi
    else
        test_fail "performance_api" "API not responding for performance test"
    fi
}

# Generate test report
generate_test_report() {
    echo
    log "INFO" "=== Test Report ==="
    echo -e "${CYAN}Tests Passed:${NC} $TESTS_PASSED"
    echo -e "${CYAN}Tests Failed:${NC} $TESTS_FAILED"
    echo -e "${CYAN}Tests Skipped:${NC} $TESTS_SKIPPED"
    echo -e "${CYAN}Total Tests:${NC} $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log "SUCCESS" "All tests passed!"
        return 0
    else
        log "ERROR" "Some tests failed. Check the log for details: $TEST_LOG_FILE"
        return 1
    fi
}

# Main test function
run_tests() {
    log "INFO" "Starting Docker Orchestration Tests..."
    echo
    
    # Initialize test log
    echo "Docker Orchestration Test Log - $(date)" > "$TEST_LOG_FILE"
    echo "================================================" >> "$TEST_LOG_FILE"
    echo >> "$TEST_LOG_FILE"
    
    # Run test suites
    check_prerequisites || return 1
    test_vault_requirements
    test_docker_startup || return 1
    test_port_binding_security
    test_service_connectivity
    test_volume_mounting
    test_network_isolation
    test_performance
    test_docker_shutdown || return 1
    test_error_handling
    
    # Generate report
    generate_test_report
}

# Main function
main() {
    local command="${1:-}"
    
    case "$command" in
        "run")
            run_tests
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"--help"|"-h")
            cat << EOF
Docker Orchestration Test Suite

Usage: $0 <command>

Commands:
  run            Run all tests
  cleanup        Clean up test environment
  help           Show this help message

Test Categories:
  - Prerequisites validation
  - Docker stack startup/shutdown
  - Port binding security
  - Service connectivity
  - Volume mounting
  - Network isolation
  - Performance testing
  - Error handling

Examples:
  $0 run         # Run all tests
  $0 cleanup     # Clean up test environment

EOF
            ;;
        "")
            run_tests
            ;;
        *)
            log "ERROR" "Unknown command: $command. Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
