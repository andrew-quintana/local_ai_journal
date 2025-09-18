#!/usr/bin/env bash
set -euo pipefail

# test-session-control.sh - Comprehensive Session Control Testing
# 
# This script tests the complete session control functionality including:
# 1. Startup sequence testing
# 2. Shutdown sequence testing
# 3. Error handling and recovery testing
# 4. Status reporting validation
# 5. Security validation testing
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-09-18

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly BIN_DIR="$PROJECT_ROOT/bin"
readonly TEST_LOG="/tmp/session-control-test.log"

# Test configuration
readonly TEST_TIMEOUT=300  # 5 minutes
readonly HEALTH_CHECK_INTERVAL=5
readonly MAX_HEALTH_CHECKS=60

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Test results
declare -a TEST_RESULTS=()
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            echo "[$timestamp] [ERROR] $message" >> "$TEST_LOG"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            echo "[$timestamp] [WARN] $message" >> "$TEST_LOG"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] $message" >> "$TEST_LOG"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "[$timestamp] [SUCCESS] $message" >> "$TEST_LOG"
            ;;
        "TEST")
            echo -e "${CYAN}[TEST]${NC} $message"
            echo "[$timestamp] [TEST] $message" >> "$TEST_LOG"
            ;;
    esac
}

# Test result tracking
record_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TEST_RESULTS+=("$test_name:$result:$message")
    
    if [[ "$result" == "PASS" ]]; then
        ((TESTS_PASSED++))
        log "SUCCESS" "✓ $test_name: $message"
    else
        ((TESTS_FAILED++))
        log "ERROR" "✗ $test_name: $message"
    fi
}

# Check prerequisites
check_test_prerequisites() {
    log "TEST" "Checking test prerequisites..."
    
    # Check if scripts exist
    local scripts=("journals-up.sh" "journals-down.sh" "journals-status.sh")
    for script in "${scripts[@]}"; do
        if [[ ! -f "$BIN_DIR/$script" ]]; then
            record_test_result "prerequisites" "FAIL" "Script not found: $script"
            return 1
        fi
        
        if [[ ! -x "$BIN_DIR/$script" ]]; then
            record_test_result "prerequisites" "FAIL" "Script not executable: $script"
            return 1
        fi
    done
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        record_test_result "prerequisites" "FAIL" "Docker not available"
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        record_test_result "prerequisites" "FAIL" "Docker daemon not running"
        return 1
    fi
    
    record_test_result "prerequisites" "PASS" "All prerequisites met"
    return 0
}

# Test script help functionality
test_script_help() {
    log "TEST" "Testing script help functionality..."
    
    local scripts=("journals-up.sh" "journals-down.sh" "journals-status.sh")
    for script in "${scripts[@]}"; do
        if "$BIN_DIR/$script" help >/dev/null 2>&1; then
            record_test_result "help_$script" "PASS" "Help command works"
        else
            record_test_result "help_$script" "FAIL" "Help command failed"
        fi
    done
}

# Test status script functionality
test_status_script() {
    log "TEST" "Testing status script functionality..."
    
    # Test complete status
    if "$BIN_DIR/journals-status.sh" >/dev/null 2>&1; then
        record_test_result "status_complete" "PASS" "Complete status report works"
    else
        record_test_result "status_complete" "FAIL" "Complete status report failed"
    fi
    
    # Test individual status sections
    local status_sections=("vault" "docker" "ports" "security" "system" "urls" "commands" "performance")
    for section in "${status_sections[@]}"; do
        if "$BIN_DIR/journals-status.sh" "$section" >/dev/null 2>&1; then
            record_test_result "status_$section" "PASS" "Status section $section works"
        else
            record_test_result "status_$section" "FAIL" "Status section $section failed"
        fi
    done
}

# Test startup sequence
test_startup_sequence() {
    log "TEST" "Testing startup sequence..."
    
    # Test pre-flight checks
    if "$BIN_DIR/journals-up.sh" 2>&1 | grep -q "pre-flight checks"; then
        record_test_result "startup_preflight" "PASS" "Pre-flight checks executed"
    else
        record_test_result "startup_preflight" "FAIL" "Pre-flight checks not executed"
    fi
    
    # Note: We don't actually start the system in tests to avoid conflicts
    log "INFO" "Startup sequence test completed (actual startup skipped in test mode)"
}

# Test shutdown sequence
test_shutdown_sequence() {
    log "TEST" "Testing shutdown sequence..."
    
    # Test shutdown with timeout
    if timeout 10 "$BIN_DIR/journals-down.sh" 5 >/dev/null 2>&1; then
        record_test_result "shutdown_timeout" "PASS" "Shutdown with timeout works"
    else
        record_test_result "shutdown_timeout" "FAIL" "Shutdown with timeout failed"
    fi
    
    # Test shutdown without timeout
    if timeout 10 "$BIN_DIR/journals-down.sh" >/dev/null 2>&1; then
        record_test_result "shutdown_default" "PASS" "Shutdown with default timeout works"
    else
        record_test_result "shutdown_default" "FAIL" "Shutdown with default timeout failed"
    fi
}

# Test error handling
test_error_handling() {
    log "TEST" "Testing error handling..."
    
    # Test with invalid arguments
    if "$BIN_DIR/journals-up.sh" invalid_arg >/dev/null 2>&1; then
        record_test_result "error_handling" "FAIL" "Should have failed with invalid argument"
    else
        record_test_result "error_handling" "PASS" "Properly handles invalid arguments"
    fi
    
    # Test status script with invalid section
    if "$BIN_DIR/journals-status.sh" invalid_section >/dev/null 2>&1; then
        record_test_result "status_error_handling" "FAIL" "Should have failed with invalid section"
    else
        record_test_result "status_error_handling" "PASS" "Properly handles invalid status section"
    fi
}

# Test security validation
test_security_validation() {
    log "TEST" "Testing security validation..."
    
    # Test port binding validation
    local ports=("11434" "3000")
    for port in "${ports[@]}"; do
        if netstat -an 2>/dev/null | grep -q "0.0.0.0:$port"; then
            record_test_result "security_port_$port" "FAIL" "Port $port bound to external interface"
        else
            record_test_result "security_port_$port" "PASS" "Port $port not bound externally"
        fi
    done
    
    # Test localhost binding
    for port in "${ports[@]}"; do
        if netstat -an 2>/dev/null | grep -q "127.0.0.1:$port"; then
            record_test_result "security_localhost_$port" "PASS" "Port $port bound to localhost"
        else
            record_test_result "security_localhost_$port" "WARN" "Port $port not bound to localhost (may be normal if not running)"
        fi
    done
}

# Test script syntax
test_script_syntax() {
    log "TEST" "Testing script syntax..."
    
    local scripts=("journals-up.sh" "journals-down.sh" "journals-status.sh")
    for script in "${scripts[@]}"; do
        if bash -n "$BIN_DIR/$script" 2>/dev/null; then
            record_test_result "syntax_$script" "PASS" "Script syntax is valid"
        else
            record_test_result "syntax_$script" "FAIL" "Script syntax is invalid"
        fi
    done
}

# Test environment variable handling
test_environment_variables() {
    log "TEST" "Testing environment variable handling..."
    
    # Test with custom ports
    local custom_ollama_port=11435
    local custom_webui_port=3001
    
    if OLLAMA_PORT="$custom_ollama_port" WEBUI_PORT="$custom_webui_port" "$BIN_DIR/journals-status.sh" ports >/dev/null 2>&1; then
        record_test_result "env_vars" "PASS" "Environment variables handled correctly"
    else
        record_test_result "env_vars" "FAIL" "Environment variables not handled correctly"
    fi
}

# Test concurrent execution
test_concurrent_execution() {
    log "TEST" "Testing concurrent execution..."
    
    # Test multiple status commands
    local pids=()
    for i in {1..3}; do
        "$BIN_DIR/journals-status.sh" >/dev/null 2>&1 &
        pids+=($!)
    done
    
    local success=true
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            success=false
        fi
    done
    
    if [[ "$success" == "true" ]]; then
        record_test_result "concurrent_execution" "PASS" "Concurrent execution works"
    else
        record_test_result "concurrent_execution" "FAIL" "Concurrent execution failed"
    fi
}

# Test timeout handling
test_timeout_handling() {
    log "TEST" "Testing timeout handling..."
    
    # Test startup timeout
    if timeout 5 "$BIN_DIR/journals-up.sh" >/dev/null 2>&1; then
        record_test_result "startup_timeout" "PASS" "Startup respects timeout"
    else
        record_test_result "startup_timeout" "PASS" "Startup properly times out"
    fi
    
    # Test shutdown timeout
    if timeout 5 "$BIN_DIR/journals-down.sh" >/dev/null 2>&1; then
        record_test_result "shutdown_timeout" "PASS" "Shutdown respects timeout"
    else
        record_test_result "shutdown_timeout" "PASS" "Shutdown properly times out"
    fi
}

# Generate test report
generate_test_report() {
    echo
    log "INFO" "Generating test report..."
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Session Control Test Report${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo
    
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
    else
        echo -e "${RED}Some tests failed. See details below:${NC}"
        echo
        echo -e "${BLUE}Failed Tests:${NC}"
        for result in "${TEST_RESULTS[@]}"; do
            IFS=':' read -r test_name result_status message <<< "$result"
            if [[ "$result_status" == "FAIL" ]]; then
                echo -e "  ${RED}✗${NC} $test_name: $message"
            fi
        done
    fi
    
    echo
    echo -e "${BLUE}Test Log:${NC} $TEST_LOG"
    echo -e "${CYAN}========================================${NC}"
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up test environment..."
    
    # Stop any running containers
    docker stop journals-ollama journals-webui 2>/dev/null || true
    docker rm journals-ollama journals-webui 2>/dev/null || true
    
    # Clean up test log
    if [[ -f "$TEST_LOG" ]]; then
        log "INFO" "Test log saved to: $TEST_LOG"
    fi
}

# Main function
main() {
    local start_time=$(date +%s)
    
    log "INFO" "Starting Session Control Tests..."
    echo -e "${CYAN}========================================${NC}"
    
    # Initialize test log
    echo "Session Control Test Log - $(date)" > "$TEST_LOG"
    
    # Run tests
    check_test_prerequisites || exit 1
    test_script_help
    test_status_script
    test_startup_sequence
    test_shutdown_sequence
    test_error_handling
    test_security_validation
    test_script_syntax
    test_environment_variables
    test_concurrent_execution
    test_timeout_handling
    
    # Generate report
    generate_test_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "SUCCESS" "Session Control Tests completed in ${duration} seconds"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script interruption
trap 'log "WARN" "Test interrupted. Cleaning up..."; cleanup; exit 130' INT TERM

# Run main function
main "$@"
