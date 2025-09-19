#!/bin/bash

# File System Security Audit Module
# 
# This module provides comprehensive file system security auditing
# including permission checks, mount validation, and access control verification.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_LOG="$SCRIPT_DIR/../logs/filesystem-audit.log"
JOURNAL_PATH="/journals"
BACKUP_DIR="/tmp/journals_backup"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Global variables
AUDIT_VIOLATIONS=0
AUDIT_WARNINGS=0
AUDIT_CHECKS=0
AUDIT_PASSED=0
AUDIT_FAILED=0

# Logging functions
audit_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[AUDIT INFO]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[AUDIT WARNING]${NC} $message"
            ((AUDIT_WARNINGS++))
            ;;
        "ERROR")
            echo -e "${RED}[AUDIT ERROR]${NC} $message"
            ((AUDIT_VIOLATIONS++))
            ;;
        "SUCCESS")
            echo -e "${GREEN}[AUDIT SUCCESS]${NC} $message"
            ;;
    esac
    
    echo "$timestamp|$level|$message" >> "$AUDIT_LOG"
}

# Initialize audit
init_audit() {
    mkdir -p "$(dirname "$AUDIT_LOG")"
    echo "=== FILESYSTEM SECURITY AUDIT STARTED ===" > "$AUDIT_LOG"
    echo "Timestamp: $(date)" >> "$AUDIT_LOG"
    echo "Journal Path: $JOURNAL_PATH" >> "$AUDIT_LOG"
    echo "" >> "$AUDIT_LOG"
    
    audit_log "INFO" "File system security audit initialized"
}

# Check directory permissions
check_directory_permissions() {
    audit_log "INFO" "Checking directory permissions..."
    
    ((AUDIT_CHECKS++))
    if [[ ! -d "$JOURNAL_PATH" ]]; then
        audit_log "ERROR" "Journal directory not found: $JOURNAL_PATH"
        ((AUDIT_FAILED++))
        return 1
    fi
    
    local perms=$(stat -c "%a" "$JOURNAL_PATH" 2>/dev/null || echo "000")
    local owner=$(stat -c "%U" "$JOURNAL_PATH" 2>/dev/null || echo "unknown")
    local group=$(stat -c "%G" "$JOURNAL_PATH" 2>/dev/null || echo "unknown")
    
    audit_log "INFO" "Directory permissions: $perms (owner: $owner, group: $group)"
    
    # Check if permissions are too permissive
    if [[ $perms -gt 755 ]]; then
        audit_log "WARNING" "Directory permissions may be too permissive: $perms"
        ((AUDIT_FAILED++))
    else
        audit_log "SUCCESS" "Directory permissions are secure: $perms"
        ((AUDIT_PASSED++))
    fi
}

# Check mount options
check_mount_options() {
    audit_log "INFO" "Checking mount options..."
    
    ((AUDIT_CHECKS++))
    local mount_info=$(mount | grep "$JOURNAL_PATH" | head -1)
    
    if [[ -z "$mount_info" ]]; then
        audit_log "WARNING" "Mount information not found for journal directory"
        ((AUDIT_FAILED++))
        return 1
    fi
    
    audit_log "INFO" "Mount information: $mount_info"
    
    # Check for read-only mount
    if echo "$mount_info" | grep -q "ro,"; then
        audit_log "INFO" "Journal directory mounted read-only (Phase 5.5 not implemented)"
        ((AUDIT_PASSED++))
    elif echo "$mount_info" | grep -q "rw,"; then
        audit_log "INFO" "Journal directory mounted read-write (Phase 5.5 implemented)"
        ((AUDIT_PASSED++))
    else
        audit_log "WARNING" "Mount options unclear"
        ((AUDIT_FAILED++))
    fi
}

# Test file type restrictions
test_file_type_restrictions() {
    audit_log "INFO" "Testing file type restrictions..."
    
    # Test files that should be blocked
    local blocked_extensions=("txt" "json" "yaml" "sh" "py" "js" "html" "css")
    local test_dir="$JOURNAL_PATH/security_test_$(date +%s)"
    
    mkdir -p "$test_dir"
    
    for ext in "${blocked_extensions[@]}"; do
        ((AUDIT_CHECKS++))
        local test_file="$test_dir/test.$ext"
        
        if touch "$test_file" 2>/dev/null; then
            audit_log "ERROR" "SECURITY VIOLATION: Write access to blocked file type: .$ext"
            rm -f "$test_file"
            ((AUDIT_FAILED++))
        else
            audit_log "SUCCESS" "File type restriction working: .$ext"
            ((AUDIT_PASSED++))
        fi
    done
    
    # Test markdown files (should work if Phase 5.5 implemented)
    ((AUDIT_CHECKS++))
    local test_md="$test_dir/test.md"
    if touch "$test_md" 2>/dev/null; then
        audit_log "SUCCESS" "Markdown file write access enabled (Phase 5.5)"
        rm -f "$test_md"
        ((AUDIT_PASSED++))
    else
        audit_log "WARNING" "Markdown file write access disabled (Phase 5.5 not implemented)"
        ((AUDIT_FAILED++))
    fi
    
    # Cleanup
    rm -rf "$test_dir"
}

# Test path validation
test_path_validation() {
    audit_log "INFO" "Testing path validation..."
    
    # Test paths outside journal directory
    local test_paths=(
        "/tmp/test.md"
        "/var/tmp/test.md"
        "/home/test.md"
        "$JOURNAL_PATH/../test.md"
        "$JOURNAL_PATH/../../test.md"
    )
    
    for test_path in "${test_paths[@]}"; do
        ((AUDIT_CHECKS++))
        if touch "$test_path" 2>/dev/null; then
            audit_log "WARNING" "Write access outside journal directory: $test_path"
            rm -f "$test_path"
            ((AUDIT_FAILED++))
        else
            audit_log "SUCCESS" "Path validation working: $test_path"
            ((AUDIT_PASSED++))
        fi
    done
}

# Test hidden file restrictions
test_hidden_file_restrictions() {
    audit_log "INFO" "Testing hidden file restrictions..."
    
    local hidden_files=(
        "$JOURNAL_PATH/.test.md"
        "$JOURNAL_PATH/.hidden.md"
        "$JOURNAL_PATH/..test.md"
    )
    
    for hidden_file in "${hidden_files[@]}"; do
        ((AUDIT_CHECKS++))
        if touch "$hidden_file" 2>/dev/null; then
            audit_log "WARNING" "Write access to hidden file: $hidden_file"
            rm -f "$hidden_file"
            ((AUDIT_FAILED++))
        else
            audit_log "SUCCESS" "Hidden file restriction working: $hidden_file"
            ((AUDIT_PASSED++))
        fi
    done
}

# Test content validation
test_content_validation() {
    audit_log "INFO" "Testing content validation..."
    
    local test_file="$JOURNAL_PATH/test_content_validation.md"
    local dangerous_content=(
        "javascript:alert('xss')"
        "data:text/html,<script>alert('xss')</script>"
        "<script>alert('xss')</script>"
        "<?php system('ls'); ?>"
        "<iframe src='javascript:alert(1)'></iframe>"
    )
    
    for content in "${dangerous_content[@]}"; do
        ((AUDIT_CHECKS++))
        if echo "$content" > "$test_file" 2>/dev/null; then
            # Check if content validation would catch this
            if grep -q "javascript:\|data:\|<script\|<?php\|<iframe" "$test_file" 2>/dev/null; then
                audit_log "WARNING" "Potentially dangerous content not filtered: $content"
                ((AUDIT_FAILED++))
            else
                audit_log "SUCCESS" "Content validation working: $content"
                ((AUDIT_PASSED++))
            fi
            rm -f "$test_file"
        else
            audit_log "SUCCESS" "Content validation working: $content"
            ((AUDIT_PASSED++))
        fi
    done
}

# Check file ownership
check_file_ownership() {
    audit_log "INFO" "Checking file ownership..."
    
    ((AUDIT_CHECKS++))
    local files=($(find "$JOURNAL_PATH" -type f -name "*.md" 2>/dev/null | head -10))
    
    if [[ ${#files[@]} -eq 0 ]]; then
        audit_log "WARNING" "No markdown files found for ownership check"
        ((AUDIT_FAILED++))
        return 1
    fi
    
    local expected_owner=$(stat -c "%U" "$JOURNAL_PATH" 2>/dev/null || echo "unknown")
    local ownership_violations=0
    
    for file in "${files[@]}"; do
        local file_owner=$(stat -c "%U" "$file" 2>/dev/null || echo "unknown")
        if [[ "$file_owner" != "$expected_owner" ]]; then
            audit_log "WARNING" "File ownership mismatch: $file (owner: $file_owner, expected: $expected_owner)"
            ((ownership_violations++))
        fi
    done
    
    if [[ $ownership_violations -eq 0 ]]; then
        audit_log "SUCCESS" "File ownership consistent"
        ((AUDIT_PASSED++))
    else
        audit_log "WARNING" "File ownership issues detected: $ownership_violations files"
        ((AUDIT_FAILED++))
    fi
}

# Check backup functionality
check_backup_functionality() {
    audit_log "INFO" "Checking backup functionality..."
    
    ((AUDIT_CHECKS++))
    local test_file="$JOURNAL_PATH/test_backup.md"
    local test_content="# Test Backup\nThis is a test file for backup functionality."
    
    # Create test file
    if echo -e "$test_content" > "$test_file" 2>/dev/null; then
        # Test backup creation
        local backup_file="$BACKUP_DIR/$(basename "$test_file")_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$(dirname "$backup_file")"
        
        if cp "$test_file" "$backup_file" 2>/dev/null; then
            audit_log "SUCCESS" "Backup functionality working"
            ((AUDIT_PASSED++))
            
            # Test rollback
            local modified_content="# Modified Test Backup\nThis content has been modified."
            echo -e "$modified_content" > "$test_file"
            
            if cp "$backup_file" "$test_file" 2>/dev/null; then
                if [[ "$(cat "$test_file")" == "$test_content" ]]; then
                    audit_log "SUCCESS" "Rollback functionality working"
                else
                    audit_log "WARNING" "Rollback functionality may have issues"
                fi
            else
                audit_log "WARNING" "Rollback functionality not working"
            fi
            
            # Cleanup
            rm -f "$test_file" "$backup_file"
        else
            audit_log "WARNING" "Backup functionality not working"
            ((AUDIT_FAILED++))
        fi
    else
        audit_log "WARNING" "Cannot create test file for backup check"
        ((AUDIT_FAILED++))
    fi
}

# Check disk space and quotas
check_disk_space() {
    audit_log "INFO" "Checking disk space and quotas..."
    
    ((AUDIT_CHECKS++))
    local journal_dir=$(dirname "$JOURNAL_PATH")
    local available_space=$(df "$journal_dir" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    local used_space=$(df "$journal_dir" 2>/dev/null | awk 'NR==2 {print $3}' || echo "0")
    local total_space=$(df "$journal_dir" 2>/dev/null | awk 'NR==2 {print $2}' || echo "0")
    
    if [[ $total_space -gt 0 ]]; then
        local usage_percent=$((used_space * 100 / total_space))
        audit_log "INFO" "Disk usage: $usage_percent% ($used_space/$total_space blocks)"
        
        if [[ $usage_percent -gt 90 ]]; then
            audit_log "WARNING" "Disk usage is high: $usage_percent%"
            ((AUDIT_FAILED++))
        else
            audit_log "SUCCESS" "Disk usage is acceptable: $usage_percent%"
            ((AUDIT_PASSED++))
        fi
    else
        audit_log "WARNING" "Cannot determine disk usage"
        ((AUDIT_FAILED++))
    fi
}

# Check file system integrity
check_filesystem_integrity() {
    audit_log "INFO" "Checking file system integrity..."
    
    ((AUDIT_CHECKS++))
    local journal_dir=$(dirname "$JOURNAL_PATH")
    
    # Check for file system errors
    if command -v fsck >/dev/null 2>&1; then
        if fsck -n "$journal_dir" 2>/dev/null | grep -q "clean"; then
            audit_log "SUCCESS" "File system integrity check passed"
            ((AUDIT_PASSED++))
        else
            audit_log "WARNING" "File system integrity check found issues"
            ((AUDIT_FAILED++))
        fi
    else
        audit_log "INFO" "fsck not available, skipping integrity check"
        ((AUDIT_PASSED++))
    fi
}

# Generate audit report
generate_audit_report() {
    local report_file="$SCRIPT_DIR/../security-reports/filesystem-audit-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== FILESYSTEM SECURITY AUDIT REPORT ==="
        echo "Generated: $(date)"
        echo "Journal Path: $JOURNAL_PATH"
        echo ""
        
        echo "=== AUDIT SUMMARY ==="
        echo "Total Checks: $AUDIT_CHECKS"
        echo "Passed: $AUDIT_PASSED"
        echo "Failed: $AUDIT_FAILED"
        echo "Warnings: $AUDIT_WARNINGS"
        echo "Violations: $AUDIT_VIOLATIONS"
        echo ""
        
        if [[ $AUDIT_VIOLATIONS -eq 0 ]]; then
            echo "AUDIT STATUS: ✅ PASSED"
        elif [[ $AUDIT_VIOLATIONS -le 2 ]]; then
            echo "AUDIT STATUS: ⚠️  MINOR ISSUES"
        else
            echo "AUDIT STATUS: ❌ FAILED"
        fi
        echo ""
        
        echo "=== DETAILED FINDINGS ==="
        if [[ -f "$AUDIT_LOG" ]]; then
            cat "$AUDIT_LOG"
        fi
        
    } > "$report_file"
    
    audit_log "INFO" "Audit report generated: $report_file"
    echo "$report_file"
}

# Main audit function
run_filesystem_audit() {
    audit_log "INFO" "Starting comprehensive file system security audit..."
    
    init_audit
    check_directory_permissions
    check_mount_options
    test_file_type_restrictions
    test_path_validation
    test_hidden_file_restrictions
    test_content_validation
    check_file_ownership
    check_backup_functionality
    check_disk_space
    check_filesystem_integrity
    
    local report_file=$(generate_audit_report)
    
    audit_log "INFO" "=== FILESYSTEM AUDIT COMPLETE ==="
    audit_log "INFO" "Total checks: $AUDIT_CHECKS"
    audit_log "INFO" "Passed: $AUDIT_PASSED"
    audit_log "INFO" "Failed: $AUDIT_FAILED"
    audit_log "INFO" "Warnings: $AUDIT_WARNINGS"
    audit_log "INFO" "Violations: $AUDIT_VIOLATIONS"
    audit_log "INFO" "Report: $report_file"
    
    if [[ $AUDIT_VIOLATIONS -eq 0 ]]; then
        audit_log "SUCCESS" "File system audit PASSED"
        return 0
    else
        audit_log "ERROR" "File system audit FAILED - $AUDIT_VIOLATIONS violations"
        return 1
    fi
}

# Main execution
main() {
    local command="${1:-run}"
    
    case "$command" in
        "run")
            run_filesystem_audit
            ;;
        "permissions")
            init_audit
            check_directory_permissions
            ;;
        "mount")
            init_audit
            check_mount_options
            ;;
        "filetypes")
            init_audit
            test_file_type_restrictions
            ;;
        "paths")
            init_audit
            test_path_validation
            ;;
        "hidden")
            init_audit
            test_hidden_file_restrictions
            ;;
        "content")
            init_audit
            test_content_validation
            ;;
        "ownership")
            init_audit
            check_file_ownership
            ;;
        "backup")
            init_audit
            check_backup_functionality
            ;;
        "disk")
            init_audit
            check_disk_space
            ;;
        "integrity")
            init_audit
            check_filesystem_integrity
            ;;
        "help"|"-h"|"--help")
            echo "File System Security Audit Module"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  run         Run complete file system audit (default)"
            echo "  permissions Check directory permissions"
            echo "  mount       Check mount options"
            echo "  filetypes   Test file type restrictions"
            echo "  paths       Test path validation"
            echo "  hidden      Test hidden file restrictions"
            echo "  content     Test content validation"
            echo "  ownership   Check file ownership"
            echo "  backup      Check backup functionality"
            echo "  disk        Check disk space"
            echo "  integrity   Check file system integrity"
            echo "  help        Show this help message"
            ;;
        *)
            audit_log "ERROR" "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
