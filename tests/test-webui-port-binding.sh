#!/bin/bash

# WebUI Port Binding Validation Test
# 
# This script validates the WebUI port binding functionality
# and tests the complete WebUI integration.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/src/docker/docker-compose.yml"
LOG_FILE="$PROJECT_ROOT/webui-port-binding-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Test functions
test_docker_compose_config() {
    log_info "Testing Docker Compose configuration..."
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_error "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        return 1
    fi
    
    # Check for required services
    if ! grep -q "open-webui:" "$DOCKER_COMPOSE_FILE"; then
        log_error "WebUI service not found in Docker Compose file"
        return 1
    fi
    
    if ! grep -q "ollama:" "$DOCKER_COMPOSE_FILE"; then
        log_error "Ollama service not found in Docker Compose file"
        return 1
    fi
    
    # Check for port mapping
    if ! grep -q "3000:8080" "$DOCKER_COMPOSE_FILE"; then
        log_error "Port mapping not found in Docker Compose file"
        return 1
    fi
    
    log_success "Docker Compose configuration is valid"
    return 0
}

test_container_status() {
    log_info "Testing container status..."
    
    # Check if containers are running
    local webui_running=$(docker ps | grep -c "journals-webui" || echo "0")
    if [ "$webui_running" -eq 0 ]; then
        log_error "WebUI container is not running"
        return 1
    fi
    
    local ollama_running=$(docker ps | grep -c "journals-ollama" || echo "0")
    if [ "$ollama_running" -eq 0 ]; then
        log_error "Ollama container is not running"
        return 1
    fi
    
    # Check container health
    if ! docker ps | grep "journals-webui" | grep -q "healthy"; then
        log_warning "WebUI container is not healthy"
    fi
    
    if ! docker ps | grep "journals-ollama" | grep -q "healthy"; then
        log_warning "Ollama container is not healthy"
    fi
    
    log_success "All containers are running"
    return 0
}

test_internal_connectivity() {
    log_info "Testing internal connectivity..."
    
    # Test WebUI internal port
    if ! docker exec journals-webui curl -f http://localhost:8080/health >/dev/null 2>&1; then
        log_error "WebUI internal port 8080 not responding"
        return 1
    fi
    
    # Test WebUI main page
    if ! docker exec journals-webui curl -f http://localhost:8080/ >/dev/null 2>&1; then
        log_error "WebUI main page not accessible internally"
        return 1
    fi
    
    # Test Ollama connectivity
    if ! docker exec journals-webui curl -f http://ollama:11434/api/tags >/dev/null 2>&1; then
        log_error "Ollama not accessible from WebUI container"
        return 1
    fi
    
    log_success "Internal connectivity is working"
    return 0
}

test_external_port_binding() {
    log_info "Testing external port binding..."
    
    # Check if port is bound
    if ! netstat -an | grep -q ":3000"; then
        log_warning "Port 3000 not found in netstat output"
    fi
    
    # Test external connectivity
    if curl -f http://127.0.0.1:3000/ >/dev/null 2>&1; then
        log_success "External port 3000 is accessible"
        return 0
    else
        log_warning "External port 3000 is not accessible"
        return 1
    fi
}

test_environment_variables() {
    log_info "Testing environment variables..."
    
    # Check WebUI environment variables
    if ! docker exec journals-webui env | grep -q "WEBUI_SECRET_KEY="; then
        log_error "WEBUI_SECRET_KEY not set"
        return 1
    fi
    
    if ! docker exec journals-webui env | grep -q "WEBUI_JWT_SECRET_KEY="; then
        log_error "WEBUI_JWT_SECRET_KEY not set"
        return 1
    fi
    
    # Check if secret keys are properly generated (not literal strings)
    if docker exec journals-webui env | grep "WEBUI_SECRET_KEY=" | grep -q "\$("; then
        log_error "WEBUI_SECRET_KEY contains literal command string"
        return 1
    fi
    
    if docker exec journals-webui env | grep "WEBUI_JWT_SECRET_KEY=" | grep -q "\$("; then
        log_error "WEBUI_JWT_SECRET_KEY contains literal command string"
        return 1
    fi
    
    log_success "Environment variables are properly configured"
    return 0
}

test_network_isolation() {
    log_info "Testing network isolation..."
    
    # Check if WebUI is bound to localhost only
    if netstat -an | grep ":3000" | grep -v "127.0.0.1" | grep -v "::1"; then
        log_warning "WebUI may not be properly isolated to localhost"
    else
        log_success "WebUI appears to be properly isolated"
    fi
    
    return 0
}

test_application_logs() {
    log_info "Testing application logs..."
    
    # Check for errors in WebUI logs
    if docker logs journals-webui 2>&1 | grep -i "error\|exception\|traceback" | head -5; then
        log_warning "Errors found in WebUI logs"
    else
        log_success "No critical errors in WebUI logs"
    fi
    
    # Check for startup completion
    if docker logs journals-webui 2>&1 | grep -q "Waiting for application startup"; then
        log_warning "WebUI still in startup phase"
    else
        log_success "WebUI startup appears complete"
    fi
    
    return 0
}

# Main test execution
run_tests() {
    log_info "Starting WebUI Port Binding Validation Tests"
    log_info "Test started at: $(date)"
    
    local test_results=()
    local test_names=(
        "Docker Compose Configuration"
        "Container Status"
        "Internal Connectivity"
        "External Port Binding"
        "Environment Variables"
        "Network Isolation"
        "Application Logs"
    )
    
    # Run tests
    test_docker_compose_config && test_results+=("PASS") || test_results+=("FAIL")
    test_container_status && test_results+=("PASS") || test_results+=("FAIL")
    test_internal_connectivity && test_results+=("PASS") || test_results+=("FAIL")
    test_external_port_binding && test_results+=("PASS") || test_results+=("FAIL")
    test_environment_variables && test_results+=("PASS") || test_results+=("FAIL")
    test_network_isolation && test_results+=("PASS") || test_results+=("FAIL")
    test_application_logs && test_results+=("PASS") || test_results+=("FAIL")
    
    # Print results
    log_info "Test Results Summary:"
    echo "----------------------------------------"
    for i in "${!test_names[@]}"; do
        local status="${test_results[$i]}"
        if [ "$status" = "PASS" ]; then
            log_success "${test_names[$i]}: $status"
        else
            log_error "${test_names[$i]}: $status"
        fi
    done
    echo "----------------------------------------"
    
    # Count results
    local pass_count=$(printf '%s\n' "${test_results[@]}" | grep -c "PASS" || true)
    local total_count=${#test_results[@]}
    
    log_info "Tests passed: $pass_count/$total_count"
    
    if [ "$pass_count" -eq "$total_count" ]; then
        log_success "All tests passed!"
        return 0
    else
        log_warning "Some tests failed. Check the log for details."
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    # Add any cleanup tasks here if needed
}

# Signal handlers
trap cleanup EXIT

# Main execution
main() {
    echo "WebUI Port Binding Validation Test"
    echo "=================================="
    echo
    
    # Initialize log file
    echo "WebUI Port Binding Test - $(date)" > "$LOG_FILE"
    echo "=================================" >> "$LOG_FILE"
    echo >> "$LOG_FILE"
    
    # Run tests
    if run_tests; then
        echo
        log_success "Test suite completed successfully"
        exit 0
    else
        echo
        log_error "Test suite completed with failures"
        exit 1
    fi
}

# Run main function
main "$@"
