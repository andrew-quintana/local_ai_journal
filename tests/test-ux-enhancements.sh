#!/usr/bin/env bash
# Test script for UX enhancements
# 
# This script tests the UX enhancement library functions including
# colorized output, progress indicators, error handling, and help system.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly UX_LIB="$PROJECT_ROOT/lib/ux-enhancements.sh"

# Test configuration
readonly TEST_OUTPUT_DIR="/tmp/ux-test-output"
readonly TEST_LOG_FILE="/tmp/ux-test.log"

# Color codes for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test logging
test_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[TEST-INFO]${NC} $message"
            ;;
        "PASS")
            echo -e "${GREEN}[TEST-PASS]${NC} $message"
            ;;
        "FAIL")
            echo -e "${RED}[TEST-FAIL]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[TEST-WARN]${NC} $message"
            ;;
    esac
    
    echo "[$timestamp][$level] $message" >> "$TEST_LOG_FILE"
}

# Test assertion
assert_test() {
    local test_name="$1"
    local condition="$2"
    local message="${3:-Test failed}"
    
    ((TESTS_RUN++))
    
    if eval "$condition"; then
        ((TESTS_PASSED++))
        test_log "PASS" "$test_name"
        return 0
    else
        ((TESTS_FAILED++))
        test_log "FAIL" "$test_name: $message"
        return 1
    fi
}

# Test colorized output functions
test_colorized_output() {
    test_log "INFO" "Testing colorized output functions..."
    
    # Test show_success
    local success_output
    success_output=$(show_success "Test success message" 2>&1)
    assert_test "show_success" "echo '$success_output' | grep -q '✓'" "Success indicator not found"
    
    # Test show_error
    local error_output
    error_output=$(show_error "Test error message" 2>&1)
    assert_test "show_error" "echo '$error_output' | grep -q '✗'" "Error indicator not found"
    
    # Test show_warning
    local warning_output
    warning_output=$(show_warning "Test warning message" 2>&1)
    assert_test "show_warning" "echo '$warning_output' | grep -q '⚠'" "Warning indicator not found"
    
    # Test show_info
    local info_output
    info_output=$(show_info "Test info message" 2>&1)
    assert_test "show_info" "echo '$info_output' | grep -q 'ℹ'" "Info indicator not found"
    
    # Test show_progress_indicator
    local progress_output
    progress_output=$(show_progress_indicator "Test progress message" 2>&1)
    assert_test "show_progress_indicator" "echo '$progress_output' | grep -q '⟳'" "Progress indicator not found"
    
    # Test show_question
    local question_output
    question_output=$(show_question "Test question message" 2>&1)
    assert_test "show_question" "echo '$question_output' | grep -q '?'" "Question indicator not found"
}

# Test progress bar functionality
test_progress_bar() {
    test_log "INFO" "Testing progress bar functionality..."
    
    # Test progress bar with different values
    local progress_output
    progress_output=$(show_progress 5 10 "Test operation" 2>&1)
    assert_test "progress_bar_50_percent" "echo '$progress_output' | grep -q '50%'" "50% progress not displayed correctly"
    
    # Test progress bar completion
    local complete_output
    complete_output=$(show_progress 10 10 "Test operation" 2>&1)
    assert_test "progress_bar_complete" "echo '$complete_output' | grep -q '100%'" "100% progress not displayed correctly"
    
    # Test progress bar with zero total
    local zero_output
    zero_output=$(show_progress 1 0 "Test operation" 2>&1)
    assert_test "progress_bar_zero_total" "echo '$zero_output' | grep -q '100%'" "Zero total handling failed"
}

# Test help system
test_help_system() {
    test_log "INFO" "Testing help system..."
    
    # Test startup help
    local startup_help
    startup_help=$(show_help "startup" 2>&1)
    assert_test "startup_help" "echo '$startup_help' | grep -q 'Startup Help'" "Startup help not generated"
    
    # Test shutdown help
    local shutdown_help
    shutdown_help=$(show_help "shutdown" 2>&1)
    assert_test "shutdown_help" "echo '$shutdown_help' | grep -q 'Shutdown Help'" "Shutdown help not generated"
    
    # Test error help
    local error_help
    error_help=$(show_help "error" 2>&1)
    assert_test "error_help" "echo '$error_help' | grep -q 'Error Help'" "Error help not generated"
    
    # Test vault help
    local vault_help
    vault_help=$(show_help "vault" 2>&1)
    assert_test "vault_help" "echo '$vault_help' | grep -q 'Vault Help'" "Vault help not generated"
    
    # Test docker help
    local docker_help
    docker_help=$(show_help "docker" 2>&1)
    assert_test "docker_help" "echo '$docker_help' | grep -q 'Docker Help'" "Docker help not generated"
    
    # Test ports help
    local ports_help
    ports_help=$(show_help "ports" 2>&1)
    assert_test "ports_help" "echo '$ports_help' | grep -q 'Port Help'" "Port help not generated"
}

# Test error detection and recovery
test_error_detection() {
    test_log "INFO" "Testing error detection and recovery..."
    
    # Test docker_not_running error
    local docker_error
    docker_error=$(detect_and_recover "docker_not_running" 2>&1)
    assert_test "docker_error_detection" "echo '$docker_error' | grep -q 'Docker is not running'" "Docker error detection failed"
    
    # Test vault_not_found error
    local vault_error
    vault_error=$(detect_and_recover "vault_not_found" 2>&1)
    assert_test "vault_error_detection" "echo '$vault_error' | grep -q 'Vault not found'" "Vault error detection failed"
    
    # Test port_in_use error
    local port_error
    port_error=$(detect_and_recover "port_in_use" "3000" 2>&1)
    assert_test "port_error_detection" "echo '$port_error' | grep -q 'Port already in use'" "Port error detection failed"
    
    # Test write_access_denied error
    local write_error
    write_error=$(detect_and_recover "write_access_denied" 2>&1)
    assert_test "write_error_detection" "echo '$write_error' | grep -q 'Write access denied'" "Write access error detection failed"
}

# Test input validation
test_input_validation() {
    test_log "INFO" "Testing input validation..."
    
    # Test port validation
    assert_test "port_validation_valid" "validate_input '8080' 'port'" "Valid port validation failed"
    assert_test "port_validation_invalid" "! validate_input '99999' 'port'" "Invalid port validation failed"
    assert_test "port_validation_zero" "! validate_input '0' 'port'" "Zero port validation failed"
    
    # Test file path validation (create a test file)
    local test_file="/tmp/ux-test-file.txt"
    echo "test content" > "$test_file"
    
    assert_test "file_validation_valid" "validate_input '$test_file' 'file_path'" "Valid file validation failed"
    assert_test "file_validation_invalid" "! validate_input '/nonexistent/file.txt' 'file_path'" "Invalid file validation failed"
    
    # Test markdown file validation
    local test_md_file="/tmp/ux-test-file.md"
    echo "test content" > "$test_md_file"
    
    assert_test "markdown_validation_valid" "validate_input '$test_md_file' 'markdown_file'" "Valid markdown file validation failed"
    assert_test "markdown_validation_invalid" "! validate_input '$test_file' 'markdown_file'" "Invalid markdown file validation failed"
    
    # Cleanup test files
    rm -f "$test_file" "$test_md_file"
}

# Test user guide generation
test_user_guide_generation() {
    test_log "INFO" "Testing user guide generation..."
    
    local guide_file="/tmp/test-user-guide.md"
    
    # Generate user guide
    generate_user_guide "$guide_file"
    
    # Check if guide was created
    assert_test "user_guide_created" "[[ -f '$guide_file' ]]" "User guide file not created"
    
    # Check guide content
    assert_test "user_guide_content" "grep -q 'Journals Infrastructure User Guide' '$guide_file'" "User guide content missing"
    assert_test "user_guide_quick_start" "grep -q 'Quick Start' '$guide_file'" "Quick Start section missing"
    assert_test "user_guide_commands" "grep -q 'Commands Reference' '$guide_file'" "Commands Reference section missing"
    assert_test "user_guide_troubleshooting" "grep -q 'Troubleshooting' '$guide_file'" "Troubleshooting section missing"
    
    # Cleanup
    rm -f "$guide_file"
}

# Test banner and section display
test_banner_display() {
    test_log "INFO" "Testing banner and section display..."
    
    # Test banner display
    local banner_output
    banner_output=$(show_banner "Test System" "1.0" 2>&1)
    assert_test "banner_display" "echo '$banner_output' | grep -q 'Test System'" "Banner not displayed correctly"
    
    # Test section display
    local section_output
    section_output=$(show_section "Test Section" 2>&1)
    assert_test "section_display" "echo '$section_output' | grep -q '=== Test Section ==='" "Section not displayed correctly"
}

# Test completion message
test_completion_message() {
    test_log "INFO" "Testing completion message..."
    
    local completion_output
    completion_output=$(show_completion "Test Operation" "5 seconds" 2>&1)
    assert_test "completion_display" "echo '$completion_output' | grep -q 'Operation completed: Test Operation'" "Completion message not displayed correctly"
    assert_test "completion_duration" "echo '$completion_output' | grep -q 'Duration: 5 seconds'" "Completion duration not displayed correctly"
}

# Test logging functions
test_logging_functions() {
    test_log "INFO" "Testing logging functions..."
    
    # Test different log levels
    local info_log
    info_log=$(ux_log "$LOG_INFO" "Test info message" 2>&1)
    assert_test "info_logging" "echo '$info_log' | grep -q 'Test info message'" "Info logging failed"
    
    local success_log
    success_log=$(ux_log "$LOG_SUCCESS" "Test success message" 2>&1)
    assert_test "success_logging" "echo '$success_log' | grep -q 'Test success message'" "Success logging failed"
    
    local warn_log
    warn_log=$(ux_log "$LOG_WARN" "Test warning message" 2>&1)
    assert_test "warn_logging" "echo '$warn_log' | grep -q 'Test warning message'" "Warning logging failed"
    
    local error_log
    error_log=$(ux_log "$LOG_ERROR" "Test error message" 2>&1)
    assert_test "error_logging" "echo '$error_log' | grep -q 'Test error message'" "Error logging failed"
}

# Test spinner functionality
test_spinner_functionality() {
    test_log "INFO" "Testing spinner functionality..."
    
    # Test spinner with a short-lived process
    local spinner_output
    spinner_output=$(sleep 1 & show_spinner $! "Test spinner" 2>&1)
    assert_test "spinner_display" "echo '$spinner_output' | grep -q 'Test spinner completed'" "Spinner completion message not found"
}

# Test confirmation prompts
test_confirmation_prompts() {
    test_log "INFO" "Testing confirmation prompts..."
    
    # Test default 'n' confirmation
    echo "n" | confirm_action "Test action" "n" >/dev/null 2>&1
    assert_test "confirmation_default_n" "[[ $? -eq 1 ]]" "Default 'n' confirmation failed"
    
    # Test default 'y' confirmation
    echo "y" | confirm_action "Test action" "y" >/dev/null 2>&1
    assert_test "confirmation_default_y" "[[ $? -eq 0 ]]" "Default 'y' confirmation failed"
}

# Test auto recovery
test_auto_recovery() {
    test_log "INFO" "Testing auto recovery..."
    
    # Test containers_stopped recovery
    local recovery_output
    recovery_output=$(auto_recover "containers_stopped" 2>&1)
    assert_test "containers_recovery" "echo '$recovery_output' | grep -q 'Attempting to restart containers'" "Containers recovery message not found"
    
    # Test vault_unmounted recovery
    local vault_recovery
    vault_recovery=$(auto_recover "vault_unmounted" 2>&1)
    assert_test "vault_recovery" "echo '$vault_recovery' | grep -q 'Attempting to remount vault'" "Vault recovery message not found"
}

# Test contextual error messages
test_contextual_errors() {
    test_log "INFO" "Testing contextual error messages..."
    
    # Test permission denied error
    local perm_error
    perm_error=$(show_contextual_error "permission_denied" "/test/path" "Try sudo" 2>&1)
    assert_test "permission_error" "echo '$perm_error' | grep -q 'Permission denied accessing /test/path'" "Permission error message not found"
    assert_test "permission_suggestion" "echo '$perm_error' | grep -q 'Suggestion: Try sudo'" "Permission suggestion not found"
    
    # Test resource unavailable error
    local resource_error
    resource_error=$(show_contextual_error "resource_unavailable" "test-service" 2>&1)
    assert_test "resource_error" "echo '$resource_error' | grep -q 'Resource unavailable: test-service'" "Resource error message not found"
}

# Main test function
run_tests() {
    local start_time=$(date +%s)
    
    echo -e "${CYAN}=== UX Enhancements Test Suite ===${NC}"
    echo
    
    # Load UX library
    if [[ ! -f "$UX_LIB" ]]; then
        test_log "FAIL" "UX library not found: $UX_LIB"
        exit 1
    fi
    
    source "$UX_LIB"
    
    # Create test output directory
    mkdir -p "$TEST_OUTPUT_DIR"
    
    # Initialize test log
    echo "UX Enhancements Test Log - $(date)" > "$TEST_LOG_FILE"
    
    # Run all tests
    test_colorized_output
    test_progress_bar
    test_help_system
    test_error_detection
    test_input_validation
    test_user_guide_generation
    test_banner_display
    test_completion_message
    test_logging_functions
    test_spinner_functionality
    test_confirmation_prompts
    test_auto_recovery
    test_contextual_errors
    
    # Calculate test results
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo
    echo -e "${CYAN}=== Test Results ===${NC}"
    echo -e "Tests run: ${BLUE}$TESTS_RUN${NC}"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Duration: ${BLUE}${duration}s${NC}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        test_log "PASS" "All tests passed successfully!"
        echo -e "${GREEN}✓ All UX enhancement tests passed!${NC}"
        return 0
    else
        test_log "FAIL" "$TESTS_FAILED tests failed"
        echo -e "${RED}✗ $TESTS_FAILED tests failed${NC}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    test_log "INFO" "Cleaning up test files..."
    rm -rf "$TEST_OUTPUT_DIR"
    # Keep test log for debugging
    test_log "INFO" "Test log saved to: $TEST_LOG_FILE"
}

# Handle script interruption
trap 'cleanup; exit 130' INT TERM

# Show help
show_help() {
    cat << EOF
UX Enhancements Test Suite

Usage: $0 [options]

Description:
  Tests the UX enhancement library functions including colorized output,
  progress indicators, error handling, and help system.

Options:
  --help, -h     Show this help message
  --verbose, -v  Enable verbose output
  --cleanup, -c  Clean up test files and exit

Examples:
  $0              # Run all tests
  $0 --verbose    # Run tests with verbose output
  $0 --cleanup    # Clean up test files

EOF
}

# Main function
main() {
    case "${1:-}" in
        "--help"|"-h")
            show_help
            exit 0
            ;;
        "--cleanup"|"-c")
            cleanup
            exit 0
            ;;
        "--verbose"|"-v")
            set -x
            run_tests
            ;;
        "")
            run_tests
            ;;
        *)
            echo "Unknown option: $1. Use '$0 --help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

