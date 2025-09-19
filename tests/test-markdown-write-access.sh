#!/bin/bash

# Markdown Write Access Test Suite
# 
# This script tests the markdown write access implementation for the
# journals infrastructure. It validates file type restrictions, path
# validation, content validation, backup/rollback functionality, and
# monitoring capabilities.
#
# Test Categories:
# - File type validation
# - Path validation
# - Content validation
# - Write operations
# - Backup and rollback
# - Monitoring functionality
# - Security violations
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JOURNAL_ROOT="/tmp/test_journals"  # Use local directory for testing
TEST_DIR="$JOURNAL_ROOT/test_markdown_write"
MARKDOWN_MANAGER="$PROJECT_ROOT/src/docker/markdown-write-manager.sh"
WRITE_MONITOR="$PROJECT_ROOT/src/docker/write-monitor.sh"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_test() {
    echo -e "${PURPLE}[TEST]${NC} $1"
}

# Test result tracking
test_passed() {
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
    log_success "$1"
}

test_failed() {
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
    log_error "$1"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment"
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    
    # Initialize markdown write manager
    if [[ -f "$MARKDOWN_MANAGER" ]]; then
        "$MARKDOWN_MANAGER" init
    else
        log_error "Markdown write manager not found: $MARKDOWN_MANAGER"
        exit 1
    fi
    
    # Initialize write monitor
    if [[ -f "$WRITE_MONITOR" ]]; then
        "$WRITE_MONITOR" init
    else
        log_error "Write monitor not found: $WRITE_MONITOR"
        exit 1
    fi
    
    log_info "Test environment setup complete"
}

# Cleanup test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment"
    
    # Remove test directory
    rm -rf "$TEST_DIR"
    
    # Stop monitoring if running
    "$WRITE_MONITOR" stop 2>/dev/null || true
    
    log_info "Test environment cleanup complete"
}

# Test file type validation
test_file_type_validation() {
    log_test "Testing file type validation"
    
    # Test valid markdown files
    local valid_files=("test.md" "test.markdown" "journal.md" "notes.markdown")
    for file in "${valid_files[@]}"; do
        if "$MARKDOWN_MANAGER" validate "$TEST_DIR/$file" 2>/dev/null; then
            test_passed "Valid file type accepted: $file"
        else
            test_failed "Valid file type rejected: $file"
        fi
    done
    
    # Test invalid file types
    local invalid_files=("test.txt" "test.json" "test.sh" "test.py" "test.js")
    for file in "${invalid_files[@]}"; do
        if "$MARKDOWN_MANAGER" validate "$TEST_DIR/$file" 2>/dev/null; then
            test_failed "Invalid file type accepted: $file"
        else
            test_passed "Invalid file type rejected: $file"
        fi
    done
}

# Test path validation
test_path_validation() {
    log_test "Testing path validation"
    
    # Test valid paths (within journal directory)
    local valid_paths=("$TEST_DIR/test.md" "$JOURNAL_ROOT/notes.md")
    for path in "${valid_paths[@]}"; do
        if "$MARKDOWN_MANAGER" validate "$path" 2>/dev/null; then
            test_passed "Valid path accepted: $path"
        else
            test_failed "Valid path rejected: $path"
        fi
    done
    
    # Test invalid paths (outside journal directory)
    local invalid_paths=("/tmp/test.md" "/etc/test.md" "/root/test.md")
    for path in "${invalid_paths[@]}"; do
        if "$MARKDOWN_MANAGER" validate "$path" 2>/dev/null; then
            test_failed "Invalid path accepted: $path"
        else
            test_passed "Invalid path rejected: $path"
        fi
    done
}

# Test content validation
test_content_validation() {
    log_test "Testing content validation"
    
    # Test safe content
    local safe_content="# Test Markdown\n\nThis is safe content."
    echo -e "$safe_content" > "$TEST_DIR/safe.md"
    if "$MARKDOWN_MANAGER" validate "$TEST_DIR/safe.md" 2>/dev/null; then
        test_passed "Safe content accepted"
    else
        test_failed "Safe content rejected"
    fi
    
    # Test potentially dangerous content
    local dangerous_content="<script>alert('xss')</script>"
    echo "$dangerous_content" > "$TEST_DIR/dangerous.md"
    if "$MARKDOWN_MANAGER" validate "$TEST_DIR/dangerous.md" 2>/dev/null; then
        log_warning "Dangerous content accepted (may be expected behavior)"
    else
        test_passed "Dangerous content rejected"
    fi
}

# Test write operations
test_write_operations() {
    log_test "Testing write operations"
    
    # Test markdown file creation
    local test_content="# Test Journal Entry\n\nThis is a test entry."
    if "$MARKDOWN_MANAGER" write "$TEST_DIR/test_write.md" "$test_content" "create" 2>/dev/null; then
        test_passed "Markdown file creation successful"
    else
        test_failed "Markdown file creation failed"
    fi
    
    # Test markdown file modification
    local modified_content="# Test Journal Entry\n\nThis is a modified entry."
    if "$MARKDOWN_MANAGER" write "$TEST_DIR/test_write.md" "$modified_content" "modify" 2>/dev/null; then
        test_passed "Markdown file modification successful"
    else
        test_failed "Markdown file modification failed"
    fi
    
    # Test non-markdown file write (should fail)
    if "$MARKDOWN_MANAGER" write "$TEST_DIR/test.txt" "test content" "create" 2>/dev/null; then
        test_failed "Non-markdown file write succeeded (should fail)"
    else
        test_passed "Non-markdown file write properly rejected"
    fi
}

# Test backup and rollback
test_backup_rollback() {
    log_test "Testing backup and rollback functionality"
    
    # Create initial file
    local initial_content="# Initial Content\n\nThis is the original content."
    echo -e "$initial_content" > "$TEST_DIR/backup_test.md"
    
    # Create backup
    local backup_path
    if backup_path=$("$MARKDOWN_MANAGER" backup "$TEST_DIR/backup_test.md" 2>/dev/null); then
        test_passed "Backup creation successful"
    else
        test_failed "Backup creation failed"
        return
    fi
    
    # Modify file
    local modified_content="# Modified Content\n\nThis is the modified content."
    echo -e "$modified_content" > "$TEST_DIR/backup_test.md"
    
    # Rollback file
    if "$MARKDOWN_MANAGER" rollback "$TEST_DIR/backup_test.md" "$backup_path" 2>/dev/null; then
        test_passed "File rollback successful"
    else
        test_failed "File rollback failed"
    fi
    
    # Verify rollback worked
    if grep -q "Initial Content" "$TEST_DIR/backup_test.md"; then
        test_passed "Rollback verification successful"
    else
        test_failed "Rollback verification failed"
    fi
}

# Test monitoring functionality
test_monitoring() {
    log_test "Testing monitoring functionality"
    
    # Start monitoring
    if "$WRITE_MONITOR" start 2>/dev/null; then
        test_passed "Monitoring started successfully"
    else
        test_failed "Monitoring start failed"
        return
    fi
    
    # Wait a moment for monitoring to initialize
    sleep 2
    
    # Test monitoring with a file operation
    echo "# Test for monitoring" > "$TEST_DIR/monitor_test.md"
    sleep 2
    
    # Check monitoring status
    if "$WRITE_MONITOR" status 2>/dev/null | grep -q "Running"; then
        test_passed "Monitoring status check successful"
    else
        test_failed "Monitoring status check failed"
    fi
    
    # Stop monitoring
    if "$WRITE_MONITOR" stop 2>/dev/null; then
        test_passed "Monitoring stopped successfully"
    else
        test_failed "Monitoring stop failed"
    fi
}

# Test security violations
test_security_violations() {
    log_test "Testing security violation detection"
    
    # Test unauthorized file type write attempt
    if echo "test" > "$TEST_DIR/unauthorized.txt" 2>/dev/null; then
        log_warning "Unauthorized file type write succeeded (may be expected if not using manager)"
    else
        test_passed "Unauthorized file type write properly blocked"
    fi
    
    # Test path outside journal directory
    if "$MARKDOWN_MANAGER" write "/tmp/unauthorized.md" "test" "create" 2>/dev/null; then
        test_failed "Unauthorized path write succeeded (should fail)"
    else
        test_passed "Unauthorized path write properly blocked"
    fi
}

# Test Docker integration
test_docker_integration() {
    log_test "Testing Docker integration"
    
    # Check if Docker is running
    if ! docker ps >/dev/null 2>&1; then
        log_warning "Docker not running, skipping Docker integration tests"
        return
    fi
    
    # Check if journals containers are running
    if docker ps | grep -q "journals-webui"; then
        test_passed "WebUI container is running"
    else
        test_warning "WebUI container not running"
    fi
    
    if docker ps | grep -q "journals-ollama"; then
        test_passed "Ollama container is running"
    else
        test_warning "Ollama container not running"
    fi
}

# Test performance
test_performance() {
    log_test "Testing performance"
    
    # Test write performance
    local start_time=$(date +%s.%N)
    local test_content="# Performance Test\n\n"$(seq 1 100 | sed 's/^/Line /')
    
    if "$MARKDOWN_MANAGER" write "$TEST_DIR/performance_test.md" "$test_content" "create" 2>/dev/null; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        
        if (( $(echo "$duration < 5.0" | bc -l) )); then
            test_passed "Write performance acceptable: ${duration}s"
        else
            test_warning "Write performance slow: ${duration}s"
        fi
    else
        test_failed "Performance test write failed"
    fi
}

# Generate test report
generate_test_report() {
    log_info "Generating test report"
    
    echo ""
    echo "=========================================="
    echo "Markdown Write Access Test Report"
    echo "=========================================="
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Success Rate: $(( (TESTS_PASSED * 100) / TESTS_TOTAL ))%"
    echo "=========================================="
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "$TESTS_FAILED tests failed"
        return 1
    fi
}

# Main test function
run_tests() {
    log_info "Starting markdown write access tests"
    
    # Setup
    setup_test_environment
    
    # Run tests
    test_file_type_validation
    test_path_validation
    test_content_validation
    test_write_operations
    test_backup_rollback
    test_monitoring
    test_security_violations
    test_docker_integration
    test_performance
    
    # Cleanup
    cleanup_test_environment
    
    # Generate report
    generate_test_report
}

# Main function
main() {
    local command="${1:-run}"
    
    case "$command" in
        "run")
            run_tests
            ;;
        "setup")
            setup_test_environment
            ;;
        "cleanup")
            cleanup_test_environment
            ;;
        "help"|*)
            echo "Markdown Write Access Test Suite"
            echo ""
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  run      Run all tests (default)"
            echo "  setup    Setup test environment"
            echo "  cleanup  Cleanup test environment"
            echo "  help     Show this help message"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
