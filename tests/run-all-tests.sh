#!/bin/bash

# run-all-tests.sh - Comprehensive Test Suite Runner
# 
# This script runs all tests for the journals infrastructure including
# Docker orchestration, security validation, and integration tests.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly TEST_LOG_FILE="/tmp/journals-test-suite.log"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Test suite counters
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0
TOTAL_TESTS_SKIPPED=0
TOTAL_VIOLATIONS=0

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

# Test result aggregation
aggregate_test_results() {
    local test_file="$1"
    local test_name="$2"
    
    log "TEST" "Running $test_name..."
    
    if [[ ! -f "$test_file" ]]; then
        log "ERROR" "Test file not found: $test_file"
        ((TOTAL_TESTS_FAILED++))
        return 1
    fi
    
    # Make sure test file is executable
    chmod +x "$test_file"
    
    # Run the test and capture results
    local test_output
    local test_exit_code
    
    if test_output=$("$test_file" run 2>&1); then
        test_exit_code=0
    else
        test_exit_code=$?
    fi
    
    # Parse test results from output
    local tests_passed
    local tests_failed
    local tests_skipped
    local violations
    
    tests_passed=$(echo "$test_output" | grep -o "Tests Passed: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")
    tests_failed=$(echo "$test_output" | grep -o "Tests Failed: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")
    tests_skipped=$(echo "$test_output" | grep -o "Tests Skipped: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")
    violations=$(echo "$test_output" | grep -o "Security Violations: [0-9]*" | grep -o "[0-9]*" | tail -1 || echo "0")
    
    # Add to totals
    TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + tests_passed))
    TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + tests_failed))
    TOTAL_TESTS_SKIPPED=$((TOTAL_TESTS_SKIPPED + tests_skipped))
    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + violations))
    
    # Display results
    if [[ $test_exit_code -eq 0 ]]; then
        log "SUCCESS" "$test_name completed successfully"
    else
        log "ERROR" "$test_name failed with exit code $test_exit_code"
    fi
    
    echo "  Passed: $tests_passed"
    echo "  Failed: $tests_failed"
    echo "  Skipped: $tests_skipped"
    if [[ $violations -gt 0 ]]; then
        echo "  Violations: $violations"
    fi
    echo
    
    return $test_exit_code
}

# Run all test suites
run_all_tests() {
    log "INFO" "Starting Comprehensive Test Suite..."
    echo
    
    # Initialize test log
    echo "Journals Infrastructure Test Suite - $(date)" > "$TEST_LOG_FILE"
    echo "================================================" >> "$TEST_LOG_FILE"
    echo >> "$TEST_LOG_FILE"
    
    # Test suite results
    local suite_results=()
    
    # Run Docker orchestration tests
    log "TEST" "=== Docker Orchestration Tests ==="
    if aggregate_test_results "$SCRIPT_DIR/test-docker-orchestration.sh" "Docker Orchestration Tests"; then
        suite_results+=("Docker Orchestration: PASSED")
    else
        suite_results+=("Docker Orchestration: FAILED")
    fi
    
    # Run security validation tests
    log "TEST" "=== Security Validation Tests ==="
    if aggregate_test_results "$SCRIPT_DIR/test-security-validation.sh" "Security Validation Tests"; then
        suite_results+=("Security Validation: PASSED")
    else
        suite_results+=("Security Validation: FAILED")
    fi
    
    # Run simple integration tests
    log "TEST" "=== Simple Integration Tests ==="
    if aggregate_test_results "$SCRIPT_DIR/simple-test.sh" "Simple Integration Tests"; then
        suite_results+=("Simple Integration: PASSED")
    else
        suite_results+=("Simple Integration: FAILED")
    fi
    
    # Run vault manager tests
    log "TEST" "=== Vault Manager Tests ==="
    if aggregate_test_results "$SCRIPT_DIR/test-vault-manager.sh" "Vault Manager Tests"; then
        suite_results+=("Vault Manager: PASSED")
    else
        suite_results+=("Vault Manager: FAILED")
    fi
    
    # Run model management tests
    log "TEST" "=== Model Management Tests ==="
    if aggregate_test_results "$SCRIPT_DIR/test-model-management.sh" "Model Management Tests"; then
        suite_results+=("Model Management: PASSED")
    else
        suite_results+=("Model Management: FAILED")
    fi
    
    # Display suite results
    echo
    log "INFO" "=== Test Suite Results ==="
    for result in "${suite_results[@]}"; do
        echo "  $result"
    done
    echo
    
    # Generate comprehensive report
    generate_comprehensive_report
}

# Generate comprehensive test report
generate_comprehensive_report() {
    echo
    log "INFO" "=== Comprehensive Test Report ==="
    echo -e "${CYAN}Total Tests Passed:${NC} $TOTAL_TESTS_PASSED"
    echo -e "${CYAN}Total Tests Failed:${NC} $TOTAL_TESTS_FAILED"
    echo -e "${CYAN}Total Tests Skipped:${NC} $TOTAL_TESTS_SKIPPED"
    echo -e "${CYAN}Total Security Violations:${NC} $TOTAL_VIOLATIONS"
    echo -e "${CYAN}Total Tests Run:${NC} $((TOTAL_TESTS_PASSED + TOTAL_TESTS_FAILED + TOTAL_TESTS_SKIPPED))"
    echo
    
    # Calculate success rate
    local total_tests=$((TOTAL_TESTS_PASSED + TOTAL_TESTS_FAILED + TOTAL_TESTS_SKIPPED))
    local success_rate=0
    
    if [[ $total_tests -gt 0 ]]; then
        success_rate=$((TOTAL_TESTS_PASSED * 100 / total_tests))
    fi
    
    echo -e "${CYAN}Success Rate:${NC} $success_rate%"
    echo
    
    # Determine overall result
    if [[ $TOTAL_VIOLATIONS -eq 0 && $TOTAL_TESTS_FAILED -eq 0 ]]; then
        log "SUCCESS" "All tests passed! No violations detected."
        echo -e "${GREEN}Overall Result: PASSED${NC}"
        return 0
    elif [[ $TOTAL_VIOLATIONS -gt 0 ]]; then
        log "ERROR" "Security violations detected! Check the log for details: $TEST_LOG_FILE"
        echo -e "${RED}Overall Result: FAILED (Security Violations)${NC}"
        return 1
    else
        log "ERROR" "Some tests failed. Check the log for details: $TEST_LOG_FILE"
        echo -e "${RED}Overall Result: FAILED${NC}"
        return 1
    fi
}

# Clean up test environment
cleanup_test_environment() {
    log "INFO" "Cleaning up test environment..."
    
    # Clean up Docker resources
    if command -v docker >/dev/null 2>&1; then
        docker system prune -f >/dev/null 2>&1 || true
    fi
    
    # Clean up test logs
    rm -f /tmp/docker-orchestration-test.log
    rm -f /tmp/security-validation.log
    rm -f /tmp/vault-manager.log
    
    log "SUCCESS" "Test environment cleanup completed"
}

# Main function
main() {
    local command="${1:-}"
    
    case "$command" in
        "run")
            run_all_tests
            ;;
        "cleanup")
            cleanup_test_environment
            ;;
        "help"|"--help"|"-h")
            cat << EOF
Comprehensive Test Suite Runner

Usage: $0 <command>

Commands:
  run            Run all test suites
  cleanup        Clean up test environment
  help           Show this help message

Test Suites:
  - Docker Orchestration Tests
  - Security Validation Tests
  - Simple Integration Tests
  - Vault Manager Tests
  - Model Management Tests

Examples:
  $0 run         # Run all test suites
  $0 cleanup     # Clean up test environment

EOF
            ;;
        "")
            run_all_tests
            ;;
        *)
            log "ERROR" "Unknown command: $command. Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
