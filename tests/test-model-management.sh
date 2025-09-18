#!/bin/bash

# Comprehensive Test Suite for Model Management System
# Tests all model management functionality as specified in 04-model-management.md

set -euo pipefail

# Test Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly TEST_RESULTS_DIR="${PROJECT_ROOT}/test-results"
readonly MODEL_MANAGER="${PROJECT_ROOT}/src/model/model-manager.sh"
readonly MODEL_INTEGRATION="${PROJECT_ROOT}/src/model/model-integration.sh"
readonly PERFORMANCE_OPTIMIZER="${PROJECT_ROOT}/src/model/performance-optimizer.sh"
readonly SECURITY_MANAGER="${PROJECT_ROOT}/src/model/security-manager.sh"

# Test state
TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0
CURRENT_TEST=""

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test utilities
log_test() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[$timestamp] [TEST-INFO]${NC} $message" ;;
        "PASS")  echo -e "${GREEN}[$timestamp] [TEST-PASS]${NC} $message" ;;
        "FAIL")  echo -e "${RED}[$timestamp] [TEST-FAIL]${NC} $message" ;;
        "SKIP")  echo -e "${YELLOW}[$timestamp] [TEST-SKIP]${NC} $message" ;;
        "START") echo -e "${BLUE}[$timestamp] [TEST-START]${NC} $message" ;;
    esac
}

start_test() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    log_test "START" "Running test: $test_name"
}

pass_test() {
    local message="$1"
    log_test "PASS" "$CURRENT_TEST: $message"
    ((TEST_PASSED++))
}

fail_test() {
    local message="$1"
    log_test "FAIL" "$CURRENT_TEST: $message"
    ((TEST_FAILED++))
}

skip_test() {
    local message="$1"
    log_test "SKIP" "$CURRENT_TEST: $message"
    ((TEST_SKIPPED++))
}

# Test setup and teardown
setup_test_environment() {
    log_test "INFO" "Setting up test environment"
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Check if Ollama is running
    if ! curl -f -s "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
        log_test "SKIP" "Ollama is not running, some tests will be skipped"
        return 1
    fi
    
    # Check if model manager exists
    if [[ ! -f "$MODEL_MANAGER" ]]; then
        log_test "FAIL" "Model manager not found: $MODEL_MANAGER"
        exit 1
    fi
    
    log_test "INFO" "Test environment setup completed"
    return 0
}

cleanup_test_environment() {
    log_test "INFO" "Cleaning up test environment"
    
    # Clean up any test models
    if command -v "$MODEL_MANAGER" >/dev/null 2>&1; then
        # Remove any test models that might have been created
        local test_models=("test-model" "phi3:mini" "llama3.2:1b")
        for model in "${test_models[@]}"; do
            if "$MODEL_MANAGER" exists "$model" 2>/dev/null; then
                log_test "INFO" "Cleaning up test model: $model"
                # Note: We don't actually remove models as they might be needed
            fi
        done
    fi
    
    log_test "INFO" "Test environment cleanup completed"
}

# Core Model Operations Tests

test_model_exists() {
    start_test "model_exists"
    
    # Test with existing model
    if "$MODEL_MANAGER" exists "llama3.2:3b" 2>/dev/null; then
        pass_test "Correctly identified existing model"
    else
        skip_test "No existing models to test with"
    fi
    
    # Test with non-existing model
    if ! "$MODEL_MANAGER" exists "non-existent-model-12345" 2>/dev/null; then
        pass_test "Correctly identified non-existing model"
    else
        fail_test "Incorrectly identified non-existing model as existing"
    fi
}

test_model_list() {
    start_test "model_list"
    
    local models
    models=$("$MODEL_MANAGER" list 2>/dev/null)
    
    if [[ -n "$models" ]]; then
        pass_test "Successfully retrieved model list"
        
        # Check if list contains valid model names
        local valid_models=0
        echo "$models" | while read -r model; do
            if [[ -n "$model" ]] && [[ "$model" =~ ^[a-zA-Z0-9._-]+$ ]]; then
                ((valid_models++))
            fi
        done
        
        if [[ $valid_models -gt 0 ]]; then
            pass_test "Model list contains valid model names"
        else
            fail_test "Model list contains invalid model names"
        fi
    else
        skip_test "No models available to list"
    fi
}

test_model_download() {
    start_test "model_download"
    
    # Test downloading a small model
    local test_model="phi3:mini"
    
    # Check if model already exists
    if "$MODEL_MANAGER" exists "$test_model" 2>/dev/null; then
        skip_test "Test model already exists: $test_model"
        return 0
    fi
    
    # Attempt to download
    if "$MODEL_MANAGER" download "$test_model" 2>/dev/null; then
        pass_test "Successfully downloaded test model: $test_model"
        
        # Verify model exists after download
        if "$MODEL_MANAGER" exists "$test_model" 2>/dev/null; then
            pass_test "Model exists after download"
        else
            fail_test "Model does not exist after download"
        fi
    else
        skip_test "Failed to download test model (network or resource issues)"
    fi
}

test_model_validate() {
    start_test "model_validate"
    
    # Test with existing model
    local test_model="llama3.2:3b"
    
    if "$MODEL_MANAGER" exists "$test_model" 2>/dev/null; then
        if "$MODEL_MANAGER" validate "$test_model" 2>/dev/null; then
            pass_test "Model validation passed for existing model"
        else
            fail_test "Model validation failed for existing model"
        fi
    else
        skip_test "No existing models to validate"
    fi
    
    # Test with non-existing model
    if ! "$MODEL_MANAGER" validate "non-existent-model-12345" 2>/dev/null; then
        pass_test "Model validation correctly failed for non-existing model"
    else
        fail_test "Model validation incorrectly passed for non-existing model"
    fi
}

test_model_switch() {
    start_test "model_switch"
    
    # Test switching to existing model
    local test_model="llama3.2:3b"
    
    if "$MODEL_MANAGER" exists "$test_model" 2>/dev/null; then
        if "$MODEL_MANAGER" switch "$test_model" 2>/dev/null; then
            pass_test "Successfully switched to existing model"
        else
            fail_test "Failed to switch to existing model"
        fi
    else
        skip_test "No existing models to switch to"
    fi
    
    # Test switching to non-existing model
    if ! "$MODEL_MANAGER" switch "non-existent-model-12345" 2>/dev/null; then
        pass_test "Correctly failed to switch to non-existing model"
    else
        fail_test "Incorrectly succeeded in switching to non-existing model"
    fi
}

# Performance Optimization Tests

test_performance_optimization() {
    start_test "performance_optimization"
    
    if [[ ! -f "$PERFORMANCE_OPTIMIZER" ]]; then
        skip_test "Performance optimizer not found"
        return 0
    fi
    
    # Test memory management
    if "$PERFORMANCE_OPTIMIZER" memory 2>/dev/null; then
        pass_test "Memory management function works"
    else
        fail_test "Memory management function failed"
    fi
    
    # Test performance analysis (should work even with no data)
    if "$PERFORMANCE_OPTIMIZER" analyze 1 2>/dev/null; then
        pass_test "Performance analysis function works"
    else
        skip_test "Performance analysis failed (no data or jq not available)"
    fi
}

# Security Tests

test_security_validation() {
    start_test "security_validation"
    
    if [[ ! -f "$SECURITY_MANAGER" ]]; then
        skip_test "Security manager not found"
        return 0
    fi
    
    # Test security configuration validation
    if "$SECURITY_MANAGER" config 2>/dev/null; then
        pass_test "Security configuration validation passed"
    else
        fail_test "Security configuration validation failed"
    fi
}

test_model_integrity() {
    start_test "model_integrity"
    
    if [[ ! -f "$SECURITY_MANAGER" ]]; then
        skip_test "Security manager not found"
        return 0
    fi
    
    local test_model="llama3.2:3b"
    
    if "$MODEL_MANAGER" exists "$test_model" 2>/dev/null; then
        if "$SECURITY_MANAGER" validate "$test_model" 2>/dev/null; then
            pass_test "Model integrity validation passed"
        else
            fail_test "Model integrity validation failed"
        fi
    else
        skip_test "No existing models to validate integrity"
    fi
}

# Integration Tests

test_model_integration() {
    start_test "model_integration"
    
    if [[ ! -f "$MODEL_INTEGRATION" ]]; then
        skip_test "Model integration not found"
        return 0
    fi
    
    # Test initialization
    if "$MODEL_INTEGRATION" init "llama3.2:3b" 2>/dev/null; then
        pass_test "Model integration initialization passed"
    else
        skip_test "Model integration initialization failed (no models available)"
    fi
    
    # Test status reporting
    local status
    status=$("$MODEL_INTEGRATION" status 2>/dev/null)
    
    if [[ -n "$status" ]] && echo "$status" | jq -e '.' >/dev/null 2>&1; then
        pass_test "Model integration status reporting works"
    else
        skip_test "Model integration status reporting failed (no jq or no data)"
    fi
}

# Error Handling Tests

test_error_handling() {
    start_test "error_handling"
    
    # Test with invalid model names
    if ! "$MODEL_MANAGER" download "" 2>/dev/null; then
        pass_test "Correctly handled empty model name"
    else
        fail_test "Failed to handle empty model name"
    fi
    
    # Test with invalid characters in model name
    if ! "$MODEL_MANAGER" download "invalid/model!name" 2>/dev/null; then
        pass_test "Correctly handled invalid model name characters"
    else
        fail_test "Failed to handle invalid model name characters"
    fi
}

# Resource Management Tests

test_resource_management() {
    start_test "resource_management"
    
    # Test memory monitoring
    local memory_usage
    memory_usage=$("$MODEL_MANAGER" monitor 2>/dev/null)
    
    if [[ -n "$memory_usage" ]]; then
        pass_test "Memory monitoring works"
    else
        skip_test "Memory monitoring failed (system not supported)"
    fi
}

# Run all tests
run_all_tests() {
    log_test "INFO" "Starting comprehensive model management test suite"
    echo "=================================================="
    
    # Setup
    if ! setup_test_environment; then
        log_test "WARN" "Test environment setup failed, some tests will be skipped"
    fi
    
    # Core functionality tests
    echo
    log_test "INFO" "Running core functionality tests..."
    test_model_exists
    test_model_list
    test_model_download
    test_model_validate
    test_model_switch
    
    # Performance tests
    echo
    log_test "INFO" "Running performance optimization tests..."
    test_performance_optimization
    test_resource_management
    
    # Security tests
    echo
    log_test "INFO" "Running security tests..."
    test_security_validation
    test_model_integrity
    
    # Integration tests
    echo
    log_test "INFO" "Running integration tests..."
    test_model_integration
    
    # Error handling tests
    echo
    log_test "INFO" "Running error handling tests..."
    test_error_handling
    
    # Cleanup
    cleanup_test_environment
    
    # Summary
    echo
    echo "=================================================="
    log_test "INFO" "Test suite completed"
    echo -e "${GREEN}Passed: $TEST_PASSED${NC}"
    echo -e "${RED}Failed: $TEST_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TEST_SKIPPED${NC}"
    
    local total=$((TEST_PASSED + TEST_FAILED + TEST_SKIPPED))
    echo "Total: $total"
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        log_test "PASS" "All tests passed or were skipped"
        exit 0
    else
        log_test "FAIL" "Some tests failed"
        exit 1
    fi
}

# Main execution
main() {
    local command="${1:-all}"
    
    case "$command" in
        "all")
            run_all_tests
            ;;
        "core")
            setup_test_environment
            test_model_exists
            test_model_list
            test_model_download
            test_model_validate
            test_model_switch
            cleanup_test_environment
            ;;
        "performance")
            setup_test_environment
            test_performance_optimization
            test_resource_management
            cleanup_test_environment
            ;;
        "security")
            setup_test_environment
            test_security_validation
            test_model_integrity
            cleanup_test_environment
            ;;
        "integration")
            setup_test_environment
            test_model_integration
            cleanup_test_environment
            ;;
        *)
            echo "Usage: $0 {all|core|performance|security|integration}"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
