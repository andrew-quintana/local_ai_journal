#!/bin/bash

# test-webui-security-direct.sh - Direct WebUI Security Testing
# 
# This script tests WebUI security using Docker Compose directly,
# bypassing the Docker daemon communication issues.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
readonly DOCKER_COMPOSE_FILE="src/docker/docker-compose.yml"
readonly TEST_LOG="${PROJECT_ROOT}/webui-security-test.log"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$TEST_LOG"
}

# Test Docker Compose configuration
test_docker_compose_config() {
    log "INFO" "Testing Docker Compose configuration..."
    
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        log "ERROR" "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        return 1
    fi
    
    if docker-compose -f "$DOCKER_COMPOSE_FILE" config >/dev/null 2>&1; then
        log "SUCCESS" "Docker Compose configuration is valid"
        return 0
    else
        log "ERROR" "Docker Compose configuration has issues"
        return 1
    fi
}

# Start Docker stack using Docker Compose
start_docker_stack() {
    log "INFO" "Starting Docker stack using Docker Compose..."
    
    # Load environment variables
    export VAULT_MOUNT_POINT="${HOME}/Journals"
    export WEBUI_PORT="3000"
    export OLLAMA_PORT="11435"  # Use different port to avoid conflict
    
    # Start services
    if docker-compose -f "$DOCKER_COMPOSE_FILE" up -d; then
        log "SUCCESS" "Docker stack started successfully"
        return 0
    else
        log "ERROR" "Failed to start Docker stack"
        return 1
    fi
}

# Wait for services to be ready
wait_for_services() {
    log "INFO" "Waiting for services to be ready..."
    
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        # Check if containers are running using docker-compose
        local running_containers
        running_containers=$(docker-compose -f "$DOCKER_COMPOSE_FILE" ps --services --filter "status=running" 2>/dev/null | wc -l || echo "0")
        
        if [[ $running_containers -ge 2 ]]; then
            log "SUCCESS" "Services are running ($running_containers containers)"
            return 0
        fi
        
        log "INFO" "Waiting for services... (attempt $((attempt + 1))/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    log "ERROR" "Services did not start within expected time"
    return 1
}

# Test WebUI security configuration
test_webui_security() {
    log "INFO" "Testing WebUI security configuration..."
    
    # Test 1: Check if WebUI container is running
    local webui_running
    webui_running=$(docker-compose -f "$DOCKER_COMPOSE_FILE" ps open-webui --filter "status=running" 2>/dev/null | grep -c "Up" || echo "0")
    
    if [[ "$webui_running" -eq 1 ]]; then
        log "SUCCESS" "WebUI container is running"
    else
        log "ERROR" "WebUI container is not running"
        return 1
    fi
    
    # Test 2: Check port binding
    local port_binding
    port_binding=$(netstat -an 2>/dev/null | grep -c "127.0.0.1:3000" || echo "0")
    
    if [[ "$port_binding" -gt 0 ]]; then
        log "SUCCESS" "WebUI is bound to localhost only"
    else
        log "ERROR" "WebUI is not bound to localhost"
        return 1
    fi
    
    # Test 3: Check for external binding (should be 0)
    local external_binding
    external_binding=$(netstat -an 2>/dev/null | grep -c "0.0.0.0:3000" || echo "0")
    
    if [[ "$external_binding" -eq 0 ]]; then
        log "SUCCESS" "WebUI is not bound to external interfaces"
    else
        log "ERROR" "WebUI is bound to external interfaces (security violation)"
        return 1
    fi
    
    return 0
}

# Test WebUI connectivity
test_webui_connectivity() {
    log "INFO" "Testing WebUI connectivity..."
    
    # Test WebUI response
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3000/" 2>/dev/null || echo "000")
    
    if [[ "$response_code" == "200" ]] || [[ "$response_code" == "302" ]]; then
        log "SUCCESS" "WebUI is responding (HTTP $response_code)"
        return 0
    else
        log "WARN" "WebUI response code: $response_code (may still be starting)"
        return 1
    fi
}

# Test Ollama connectivity
test_ollama_connectivity() {
    log "INFO" "Testing Ollama connectivity..."
    
    # Test Ollama response
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:11435/api/tags" 2>/dev/null || echo "000")
    
    if [[ "$response_code" == "200" ]]; then
        log "SUCCESS" "Ollama is responding (HTTP $response_code)"
        return 0
    else
        log "WARN" "Ollama response code: $response_code (may still be starting)"
        return 1
    fi
}

# Test read-only journal mount
test_readonly_mount() {
    log "INFO" "Testing read-only journal mount..."
    
    # Test write access to journal directory (should fail)
    local write_test
    write_test=$(docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T open-webui touch /journals/security-test-write 2>&1 || echo "write_failed")
    
    if [[ "$write_test" == *"write_failed"* ]] || [[ "$write_test" == *"Read-only"* ]] || [[ "$write_test" == *"Permission denied"* ]]; then
        log "SUCCESS" "Read-only mount verification passed"
        
        # Clean up test file if it was created
        docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T open-webui rm -f /journals/security-test-write 2>/dev/null || true
        return 0
    else
        log "ERROR" "Read-only mount verification failed - write access detected"
        return 1
    fi
}

# Stop Docker stack
stop_docker_stack() {
    log "INFO" "Stopping Docker stack..."
    
    if docker-compose -f "$DOCKER_COMPOSE_FILE" down; then
        log "SUCCESS" "Docker stack stopped successfully"
        return 0
    else
        log "ERROR" "Failed to stop Docker stack"
        return 1
    fi
}

# Generate test report
generate_report() {
    log "INFO" "Generating test report..."
    
    echo "=== WebUI Security Test Report ===" >> "$TEST_LOG"
    echo "Generated: $(date)" >> "$TEST_LOG"
    echo "Log file: $TEST_LOG" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    # Show summary
    echo
    log "INFO" "=== TEST SUMMARY ==="
    echo "Log file: $TEST_LOG"
    echo "File size: $(wc -l < "$TEST_LOG" 2>/dev/null || echo "unknown") lines"
    echo
}

# Main test function
main() {
    log "INFO" "Starting WebUI security testing..."
    
    # Initialize log file
    echo "WebUI Security Test - $(date)" > "$TEST_LOG"
    echo "=================================" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    local tests_passed=0
    local tests_failed=0
    
    # Run tests
    if test_docker_compose_config; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if start_docker_stack; then
        ((tests_passed++))
        
        if wait_for_services; then
            ((tests_passed++))
            
            if test_webui_security; then
                ((tests_passed++))
            else
                ((tests_failed++))
            fi
            
            test_webui_connectivity  # This doesn't affect pass/fail count
            test_ollama_connectivity  # This doesn't affect pass/fail count
            
            if test_readonly_mount; then
                ((tests_passed++))
            else
                ((tests_failed++))
            fi
        else
            ((tests_failed++))
        fi
        
        # Always try to stop the stack
        stop_docker_stack || true
    else
        ((tests_failed++))
    fi
    
    # Generate report
    generate_report
    
    # Summary
    echo
    log "INFO" "=== FINAL SUMMARY ==="
    log "INFO" "Tests passed: $tests_passed"
    log "INFO" "Tests failed: $tests_failed"
    
    if [[ $tests_failed -eq 0 ]]; then
        log "SUCCESS" "All WebUI security tests passed!"
        return 0
    else
        log "ERROR" "Some WebUI security tests failed"
        return 1
    fi
}

# Run main function
main "$@"

