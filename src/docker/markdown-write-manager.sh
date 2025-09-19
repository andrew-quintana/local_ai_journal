#!/bin/bash

# Markdown Write Access Manager
# 
# This script provides secure write access management for markdown files
# in the journals infrastructure. It implements file type validation,
# backup/rollback functionality, and monitoring for write operations.
#
# Security Features:
# - File type validation (markdown only)
# - Path validation (journal directory only)
# - Content validation (basic security checks)
# - Automatic backup before modifications
# - Rollback capability
# - Write operation monitoring
# - Security violation logging
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOURNAL_ROOT="${JOURNAL_ROOT:-/journals}"
BACKUP_DIR="${BACKUP_DIR:-/tmp/journals_backup}"
LOG_DIR="${LOG_DIR:-/tmp/journals_logs}"
ALLOWED_EXTENSIONS=("md" "markdown")
SECURITY_LOG="$LOG_DIR/journals-security.log"
WRITE_LOG="$LOG_DIR/journals-write.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date -u +"%Y-%m-%dT%H:%M:%SZ") - $1" | tee -a "$WRITE_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date -u +"%Y-%m-%dT%H:%M:%SZ") - $1" | tee -a "$WRITE_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date -u +"%Y-%m-%dT%H:%M:%SZ") - $1" | tee -a "$WRITE_LOG"
}

log_security_violation() {
    local violation_type="$1"
    local file_path="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "$timestamp|SECURITY_VIOLATION|$violation_type|$file_path" >> "$SECURITY_LOG"
    log_error "SECURITY VIOLATION: $violation_type - $file_path"
}

log_write_operation() {
    local file_path="$1"
    local operation="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user="ai_model"
    
    echo "$timestamp|WRITE|$user|$operation|$file_path" >> "$WRITE_LOG"
    log_info "Write operation: $operation on $file_path"
}

# File type validation
validate_file_type() {
    local file_path="$1"
    local extension="${file_path##*.}"
    
    # Check if extension is in allowed list
    for allowed_ext in "${ALLOWED_EXTENSIONS[@]}"; do
        if [[ "$extension" == "$allowed_ext" ]]; then
            return 0
        fi
    done
    
    log_security_violation "unauthorized_file_type" "$file_path"
    return 1
}

# Path validation
validate_write_path() {
    local file_path="$1"
    
    # Ensure file is within journal directory
    if [[ "$file_path" != "$JOURNAL_ROOT"* ]]; then
        log_security_violation "path_outside_journal" "$file_path"
        return 1
    fi
    
    # Ensure file is not a hidden file
    local basename=$(basename "$file_path")
    if [[ "$basename" =~ ^\..* ]]; then
        log_security_violation "hidden_file_access" "$file_path"
        return 1
    fi
    
    # Ensure file is not a system file
    if [[ "$basename" =~ ^(docker-compose\.yml|\.env|\.gitignore|README\.md)$ ]]; then
        log_security_violation "system_file_access" "$file_path"
        return 1
    fi
    
    return 0
}

# Content validation
validate_markdown_content() {
    local file_path="$1"
    
    # Check for potentially dangerous content
    if grep -q "javascript:" "$file_path" 2>/dev/null || \
       grep -q "data:" "$file_path" 2>/dev/null || \
       grep -q "<script" "$file_path" 2>/dev/null || \
       grep -q "onload=" "$file_path" 2>/dev/null || \
       grep -q "onerror=" "$file_path" 2>/dev/null; then
        log_warning "Potentially dangerous content detected in $file_path"
        return 1
    fi
    
    return 0
}

# Create backup before modification
create_backup() {
    local file_path="$1"
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/$backup_timestamp/$(basename "$file_path")"
    
    # Create backup directory
    mkdir -p "$(dirname "$backup_file")"
    
    # Create backup
    if cp "$file_path" "$backup_file" 2>/dev/null; then
        log_info "Backup created: $backup_file"
        echo "$backup_file" >&1
        return 0
    else
        log_error "Failed to create backup for $file_path"
        return 1
    fi
}

# Rollback file from backup
rollback_file() {
    local file_path="$1"
    local backup_path="$2"
    
    if [[ -f "$backup_path" ]]; then
        if cp "$backup_path" "$file_path"; then
            log_info "File rolled back successfully: $file_path"
            return 0
        else
            log_error "Failed to rollback file: $file_path"
            return 1
        fi
    else
        log_error "Backup file not found: $backup_path"
        return 1
    fi
}

# Secure write function
secure_write() {
    local file_path="$1"
    local content="$2"
    local operation="${3:-modify}"
    
    # Validate file type
    if ! validate_file_type "$file_path"; then
        log_error "File type validation failed: $file_path"
        return 1
    fi
    
    # Validate path
    if ! validate_write_path "$file_path"; then
        log_error "Path validation failed: $file_path"
        return 1
    fi
    
    # Create backup if file exists
    local backup_path=""
    if [[ -f "$file_path" ]]; then
        backup_path=$(create_backup "$file_path")
        if [[ $? -ne 0 ]]; then
            log_error "Backup creation failed, aborting write operation"
            return 1
        fi
    fi
    
    # Write content to temporary file first
    local temp_file=$(mktemp)
    echo "$content" > "$temp_file"
    
    # Validate content
    if ! validate_markdown_content "$temp_file"; then
        log_warning "Content validation failed, but proceeding with write"
    fi
    
    # Move temp file to final location
    if mv "$temp_file" "$file_path"; then
        log_write_operation "$file_path" "$operation"
        log_info "Successfully wrote to $file_path"
        
        # Store backup path for potential rollback
        if [[ -n "$backup_path" ]]; then
            echo "$backup_path" > "$file_path.backup"
        fi
        
        return 0
    else
        log_error "Failed to write to $file_path"
        rm -f "$temp_file"
        return 1
    fi
}

# Monitor write operations
monitor_write_operations() {
    local journal_path="$JOURNAL_ROOT"
    local monitor_interval="${1:-60}"
    
    log_info "Starting write operation monitoring for $journal_path"
    
    # Check if inotifywait is available
    if ! command -v inotifywait >/dev/null 2>&1; then
        log_warning "inotifywait not available, using polling method"
        monitor_write_operations_polling "$journal_path" "$monitor_interval"
        return
    fi
    
    # Use inotifywait for real-time monitoring
    inotifywait -m "$journal_path" -e modify,create,delete,move 2>/dev/null | while read -r line; do
        local file_path=$(echo "$line" | cut -d' ' -f3)
        local event=$(echo "$line" | cut -d' ' -f2)
        
        # Validate file type for write operations
        if [[ "$event" == "MODIFY" || "$event" == "CREATE" ]]; then
            if ! validate_file_type "$file_path"; then
                log_security_violation "unauthorized_file_type" "$file_path"
            else
                log_write_operation "$file_path" "$event"
            fi
        fi
    done
}

# Polling-based monitoring (fallback)
monitor_write_operations_polling() {
    local journal_path="$JOURNAL_ROOT"
    local monitor_interval="$1"
    local last_check=$(date +%s)
    
    while true; do
        sleep "$monitor_interval"
        current_time=$(date +%s)
        
        # Check for modified files
        find "$journal_path" -name "*.md" -o -name "*.markdown" -newer "$last_check" 2>/dev/null | while read -r file; do
            if [[ -f "$file" ]]; then
                if validate_file_type "$file"; then
                    log_write_operation "$file" "MODIFY"
                else
                    log_security_violation "unauthorized_file_type" "$file"
                fi
            fi
        done
        
        last_check="$current_time"
    done
}

# List recent backups
list_backups() {
    local file_path="$1"
    local basename=$(basename "$file_path")
    
    if [[ -d "$BACKUP_DIR" ]]; then
        find "$BACKUP_DIR" -name "$basename" -type f | sort -r | head -10
    else
        log_warning "No backup directory found"
        return 1
    fi
}

# Cleanup old backups
cleanup_backups() {
    local retention_days="${1:-7}"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        find "$BACKUP_DIR" -type f -mtime +"$retention_days" -delete
        log_info "Cleaned up backups older than $retention_days days"
    fi
}

# Initialize the write manager
init_write_manager() {
    # Create necessary directories
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"
    
    # Set up log files
    touch "$SECURITY_LOG" "$WRITE_LOG"
    chmod 644 "$SECURITY_LOG" "$WRITE_LOG"
    
    log_info "Markdown write manager initialized"
}

# Main function
main() {
    local command="${1:-help}"
    
    case "$command" in
        "init")
            init_write_manager
            ;;
        "write")
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 write <file_path> <content> [operation]"
                exit 1
            fi
            secure_write "$2" "$3" "${4:-modify}"
            ;;
        "validate")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 validate <file_path>"
                exit 1
            fi
            validate_file_type "$2" && validate_write_path "$2" && validate_markdown_content "$2"
            ;;
        "backup")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 backup <file_path>"
                exit 1
            fi
            create_backup "$2"
            ;;
        "rollback")
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 rollback <file_path> <backup_path>"
                exit 1
            fi
            rollback_file "$2" "$3"
            ;;
        "monitor")
            monitor_write_operations "${2:-60}"
            ;;
        "list-backups")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 list-backups <file_path>"
                exit 1
            fi
            list_backups "$2"
            ;;
        "cleanup")
            cleanup_backups "${2:-7}"
            ;;
        "help"|*)
            echo "Markdown Write Access Manager"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init                    Initialize the write manager"
            echo "  write <file> <content>  Write content to markdown file"
            echo "  validate <file>         Validate file type, path, and content"
            echo "  backup <file>           Create backup of file"
            echo "  rollback <file> <backup> Rollback file from backup"
            echo "  monitor [interval]      Monitor write operations"
            echo "  list-backups <file>     List recent backups for file"
            echo "  cleanup [days]          Cleanup old backups"
            echo "  help                    Show this help message"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
