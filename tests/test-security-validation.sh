#!/bin/bash

# Security Validation Test Suite
# Tests the security validation system components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test modules
SECURITY_VALIDATION="$PROJECT_ROOT/src/docker/security-validation.sh"
FILESYSTEM_AUDIT="$PROJECT_ROOT/src/docker/filesystem-security-audit.sh"
CONTAINER_VERIFICATION="$PROJECT_ROOT/src/docker/container-security-verification.sh"
SECURITY_MONITOR="$PROJECT_ROOT/src/docker/security-monitor.sh"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test logging
test_log() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}

# Run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    test_log "INFO" "Running test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        test_log "PASS" "$test_name"
        ((PASSED_TESTS++))
    else
        test_log "FAIL" "$test_name"
        ((FAILED_TESTS++))
    fi
}

# Test script existence
test_script_existence() {
    test_log "INFO" "Testing script existence..."
    
    run_test "Security validation script exists" "[[ -f '$SECURITY_VALIDATION' ]]"
    run_test "Filesystem audit script exists" "[[ -f '$FILESYSTEM_AUDIT' ]]"
    run_test "Container verification script exists" "[[ -f '$CONTAINER_VERIFICATION' ]]"
    run_test "Security monitor script exists" "[[ -f '$SECURITY_MONITOR' ]]"
}

# Test script executability
test_script_executability() {
    test_log "INFO" "Testing script executability..."
    
    run_test "Security validation script executable" "[[ -x '$SECURITY_VALIDATION' ]]"
    run_test "Filesystem audit script executable" "[[ -x '$FILESYSTEM_AUDIT' ]]"
    run_test "Container verification script executable" "[[ -x '$CONTAINER_VERIFICATION' ]]"
    run_test "Security monitor script executable" "[[ -x '$SECURITY_MONITOR' ]]"
}

# Test help functionality
test_help_functionality() {
    test_log "INFO" "Testing help functionality..."
    
    run_test "Security validation help" "'$SECURITY_VALIDATION' help"
    run_test "Filesystem audit help" "'$FILESYSTEM_AUDIT' help"
    run_test "Container verification help" "'$CONTAINER_VERIFICATION' help"
    run_test "Security monitor help" "'$SECURITY_MONITOR' help"
}

# Test individual modules
test_individual_modules() {
    test_log "INFO" "Testing individual modules..."
    
    run_test "Network validation" "'$SECURITY_VALIDATION' network"
    run_test "Filesystem validation" "'$SECURITY_VALIDATION' filesystem"
    run_test "Container validation" "'$SECURITY_VALIDATION' container"
    run_test "Encryption validation" "'$SECURITY_VALIDATION' encryption"
}

# Test configuration files
test_configuration_files() {
    test_log "INFO" "Testing configuration files..."
    
    run_test "Security validation config exists" "[[ -f '$PROJECT_ROOT/src/docker/security-validation.conf' ]]"
    run_test "WebUI security config exists" "[[ -f '$PROJECT_ROOT/src/docker/webui-security.conf' ]]"
    run_test "Docker compose exists" "[[ -f '$PROJECT_ROOT/src/docker/docker-compose.yml' ]]"
}

# Test error handling
test_error_handling() {
    test_log "INFO" "Testing error handling..."
    
    run_test "Invalid command handling" "! '$SECURITY_VALIDATION' invalid_command"
    run_test "Invalid command handling" "! '$FILESYSTEM_AUDIT' invalid_command"
    run_test "Invalid command handling" "! '$CONTAINER_VERIFICATION' invalid_command"
    run_test "Invalid command handling" "! '$SECURITY_MONITOR' invalid_command"
}

# Generate test report
generate_report() {
    local report_file="$PROJECT_ROOT/test-results/security-validation-test-report.txt"
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "=== SECURITY VALIDATION TEST REPORT ==="
        echo "Generated: $(date)"
        echo "System: $(uname -a)"
        echo ""
        echo "Total Tests: $TOTAL_TESTS"
        echo "Passed: $PASSED_TESTS"
        echo "Failed: $FAILED_TESTS"
        echo ""
        
        if [[ $FAILED_TESTS -eq 0 ]]; then
            echo "STATUS: ✅ ALL TESTS PASSED"
        else
            echo "STATUS: ❌ SOME TESTS FAILED"
        fi
    } > "$report_file"
    
    test_log "INFO" "Test report generated: $report_file"
}

# Main test execution
main() {
    test_log "INFO" "Starting security validation test suite..."
    
    test_script_existence
    test_script_executability
    test_help_functionality
    test_individual_modules
    test_configuration_files
    test_error_handling
    
    generate_report
    
    test_log "INFO" "Test suite complete"
    test_log "INFO" "Total: $TOTAL_TESTS, Passed: $PASSED_TESTS, Failed: $FAILED_TESTS"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        test_log "SUCCESS" "All tests passed!"
        exit 0
    else
        test_log "ERROR" "Some tests failed: $FAILED_TESTS"
        exit 1
    fi
}

# Run main function
main "$@"
