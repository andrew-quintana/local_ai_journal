#!/bin/bash

# test-docker-simple.sh - Simple Docker Test
# 
# This script tests basic Docker functionality without complex operations
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

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
}

# Test Docker version
test_docker_version() {
    log "INFO" "Testing Docker version..."
    if docker --version >/dev/null 2>&1; then
        log "SUCCESS" "Docker version: $(docker --version)"
        return 0
    else
        log "ERROR" "Docker version command failed"
        return 1
    fi
}

# Test Docker info with timeout
test_docker_info() {
    log "INFO" "Testing Docker info (with 10 second timeout)..."
    
    # Run docker info in background
    docker info >/dev/null 2>&1 &
    local pid=$!
    
    # Wait for 10 seconds
    sleep 10
    
    # Check if process is still running
    if kill -0 "$pid" 2>/dev/null; then
        log "ERROR" "Docker info timed out after 10 seconds"
        kill "$pid" 2>/dev/null || true
        return 1
    else
        wait "$pid"
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            log "SUCCESS" "Docker info completed successfully"
            return 0
        else
            log "ERROR" "Docker info failed with exit code: $exit_code"
            return 1
        fi
    fi
}

# Test Docker ps
test_docker_ps() {
    log "INFO" "Testing Docker ps (with 5 second timeout)..."
    
    # Run docker ps in background
    docker ps >/dev/null 2>&1 &
    local pid=$!
    
    # Wait for 5 seconds
    sleep 5
    
    # Check if process is still running
    if kill -0 "$pid" 2>/dev/null; then
        log "ERROR" "Docker ps timed out after 5 seconds"
        kill "$pid" 2>/dev/null || true
        return 1
    else
        wait "$pid"
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            log "SUCCESS" "Docker ps completed successfully"
            return 0
        else
            log "ERROR" "Docker ps failed with exit code: $exit_code"
            return 1
        fi
    fi
}

# Test Docker Compose
test_docker_compose() {
    log "INFO" "Testing Docker Compose..."
    
    # Test docker-compose
    if command -v docker-compose >/dev/null 2>&1; then
        if docker-compose --version >/dev/null 2>&1; then
            log "SUCCESS" "docker-compose version: $(docker-compose --version)"
        else
            log "WARN" "docker-compose version command failed"
        fi
    else
        log "WARN" "docker-compose not found"
    fi
    
    # Test docker compose
    if docker compose version >/dev/null 2>&1; then
        log "SUCCESS" "docker compose version: $(docker compose version)"
    else
        log "WARN" "docker compose version command failed"
    fi
}

# Main test function
main() {
    log "INFO" "Starting simple Docker tests..."
    
    local tests_passed=0
    local tests_failed=0
    
    # Run tests
    if test_docker_version; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if test_docker_info; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    if test_docker_ps; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    test_docker_compose  # This doesn't affect pass/fail count
    
    # Summary
    echo
    log "INFO" "=== Test Summary ==="
    log "INFO" "Tests passed: $tests_passed"
    log "INFO" "Tests failed: $tests_failed"
    
    if [[ $tests_failed -eq 0 ]]; then
        log "SUCCESS" "All Docker tests passed!"
        return 0
    else
        log "ERROR" "Some Docker tests failed"
        return 1
    fi
}

# Run main function
main "$@"

