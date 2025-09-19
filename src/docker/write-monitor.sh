#!/bin/bash

# Write Operation Monitor
# 
# This script provides comprehensive monitoring for write operations
# on markdown files in the journals infrastructure. It monitors file
# modifications, validates security constraints, and logs all activities.
#
# Security Features:
# - Real-time file system monitoring
# - Write operation validation
# - Security violation detection
# - Performance monitoring
# - Log management and rotation
# - Alert system for security violations
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOURNAL_ROOT="${JOURNAL_ROOT:-/journals}"
LOG_DIR="${LOG_DIR:-/tmp/journals_logs}"
MONITOR_LOG="$LOG_DIR/write-monitor.log"
SECURITY_LOG="$LOG_DIR/journals-security.log"
WRITE_LOG="$LOG_DIR/journals-write.log"
ALERT_LOG="$LOG_DIR/security-alerts.log"
PERFORMANCE_LOG="$LOG_DIR/performance.log"

# Monitoring configuration
MONITOR_INTERVAL="${MONITOR_INTERVAL:-60}"
ALERT_THRESHOLD="${ALERT_THRESHOLD:-5}"
MAX_LOG_SIZE="${MAX_LOG_SIZE:-10485760}"  # 10MB
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-7}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
MONITOR_PID=""
MONITOR_RUNNING=false
ALERT_COUNT=0
LAST_ALERT_TIME=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date -u +"%Y-%m-%dT%H:%M:%SZ") - $1" | tee -a "$MONITOR_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date -u +"%Y-%m-%dT%H:%M:%SZ") - $1" | tee -a "$MONITOR_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date -u +"%Y-%m-%dT%H:%M:%SZ") - $1" | tee -a "$MONITOR_LOG"
}

log_alert() {
    echo -e "${PURPLE}[ALERT]${NC} $(date -u +"%Y-%m-%dT%H:%M:%SZ") - $1" | tee -a "$ALERT_LOG"
}

# File type validation
validate_file_type() {
    local file_path="$1"
    local extension="${file_path##*.}"
    
    case "$extension" in
        "md"|"markdown")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Path validation
validate_write_path() {
    local file_path="$1"
    
    # Ensure file is within journal directory
    if [[ "$file_path" != "$JOURNAL_ROOT"* ]]; then
        return 1
    fi
    
    # Ensure file is not a hidden file
    local basename=$(basename "$file_path")
    if [[ "$basename" =~ ^\..* ]]; then
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
       grep -q "<script" "$file_path" 2>/dev/null; then
        return 1
    fi
    
    return 0
}

# Log security violation
log_security_violation() {
    local violation_type="$1"
    local file_path="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "$timestamp|SECURITY_VIOLATION|$violation_type|$file_path" >> "$SECURITY_LOG"
    log_alert "SECURITY VIOLATION: $violation_type - $file_path"
    
    # Increment alert count
    ((ALERT_COUNT++))
    LAST_ALERT_TIME=$(date +%s)
}

# Log write operation
log_write_operation() {
    local file_path="$1"
    local operation="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user="ai_model"
    
    echo "$timestamp|WRITE|$user|$operation|$file_path" >> "$WRITE_LOG"
    log_info "Write operation: $operation on $file_path"
}

# Monitor file modifications using inotifywait
monitor_with_inotify() {
    local journal_path="$JOURNAL_ROOT"
    
    log_info "Starting inotify-based monitoring for $journal_path"
    
    inotifywait -m "$journal_path" -e modify,create,delete,move 2>/dev/null | while read -r line; do
        local file_path=$(echo "$line" | cut -d' ' -f3)
        local event=$(echo "$line" | cut -d' ' -f2)
        
        # Process write operations
        if [[ "$event" == "MODIFY" || "$event" == "CREATE" ]]; then
            process_write_event "$file_path" "$event"
        elif [[ "$event" == "DELETE" ]]; then
            log_info "File deleted: $file_path"
        elif [[ "$event" == "MOVED_FROM" || "$event" == "MOVED_TO" ]]; then
            log_info "File moved: $file_path ($event)"
        fi
    done
}

# Monitor file modifications using polling
monitor_with_polling() {
    local journal_path="$JOURNAL_ROOT"
    local last_check=$(date +%s)
    
    log_info "Starting polling-based monitoring for $journal_path (interval: ${MONITOR_INTERVAL}s)"
    
    while [[ "$MONITOR_RUNNING" == "true" ]]; do
        sleep "$MONITOR_INTERVAL"
        current_time=$(date +%s)
        
        # Check for modified markdown files
        find "$journal_path" -name "*.md" -o -name "*.markdown" -newer "$last_check" 2>/dev/null | while read -r file; do
            if [[ -f "$file" ]]; then
                process_write_event "$file" "MODIFY"
            fi
        done
        
        last_check="$current_time"
    done
}

# Process write event
process_write_event() {
    local file_path="$1"
    local event="$2"
    
    # Validate file type
    if ! validate_file_type "$file_path"; then
        log_security_violation "unauthorized_file_type" "$file_path"
        return 1
    fi
    
    # Validate path
    if ! validate_write_path "$file_path"; then
        log_security_violation "unauthorized_path" "$file_path"
        return 1
    fi
    
    # Validate content if file exists
    if [[ -f "$file_path" ]]; then
        if ! validate_markdown_content "$file_path"; then
            log_warning "Potentially dangerous content detected in $file_path"
        fi
    fi
    
    # Log legitimate write operation
    log_write_operation "$file_path" "$event"
    
    # Update performance metrics
    update_performance_metrics "$file_path" "$event"
}

# Update performance metrics
update_performance_metrics() {
    local file_path="$1"
    local event="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
    
    echo "$timestamp|PERFORMANCE|$event|$file_path|$file_size" >> "$PERFORMANCE_LOG"
}

# Check for security violations
check_security_violations() {
    local current_time=$(date +%s)
    local time_since_last_alert=$((current_time - LAST_ALERT_TIME))
    
    # Reset alert count if enough time has passed
    if [[ $time_since_last_alert -gt 3600 ]]; then  # 1 hour
        ALERT_COUNT=0
    fi
    
    # Check if alert threshold exceeded
    if [[ $ALERT_COUNT -gt $ALERT_THRESHOLD ]]; then
        log_alert "High number of security violations detected: $ALERT_COUNT"
        # Could send email notification here
    fi
}

# Log rotation
rotate_logs() {
    local log_file="$1"
    local max_size="$2"
    
    if [[ -f "$log_file" ]]; then
        local file_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
        
        if [[ $file_size -gt $max_size ]]; then
            local backup_file="${log_file}.$(date +%Y%m%d_%H%M%S)"
            mv "$log_file" "$backup_file"
            touch "$log_file"
            gzip "$backup_file" 2>/dev/null || true
            log_info "Rotated log file: $log_file"
        fi
    fi
}

# Cleanup old logs
cleanup_old_logs() {
    local log_dir="$1"
    local retention_days="$2"
    
    find "$log_dir" -name "*.log.*" -mtime +"$retention_days" -delete 2>/dev/null || true
    find "$log_dir" -name "*.gz" -mtime +"$retention_days" -delete 2>/dev/null || true
}

# Generate monitoring report
generate_report() {
    local report_file="/tmp/write-monitor-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Write Operation Monitor Report"
        echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "========================================"
        echo ""
        
        echo "Security Violations (last 24 hours):"
        if [[ -f "$SECURITY_LOG" ]]; then
            grep "$(date -d '1 day ago' +%Y-%m-%d)" "$SECURITY_LOG" | wc -l
        else
            echo "0"
        fi
        echo ""
        
        echo "Write Operations (last 24 hours):"
        if [[ -f "$WRITE_LOG" ]]; then
            grep "$(date -d '1 day ago' +%Y-%m-%d)" "$WRITE_LOG" | wc -l
        else
            echo "0"
        fi
        echo ""
        
        echo "Current Alert Count: $ALERT_COUNT"
        echo "Monitor Status: $([ "$MONITOR_RUNNING" == "true" ] && echo "Running" || echo "Stopped")"
        echo ""
        
        echo "Recent Security Violations:"
        if [[ -f "$SECURITY_LOG" ]]; then
            tail -10 "$SECURITY_LOG"
        fi
        echo ""
        
        echo "Recent Write Operations:"
        if [[ -f "$WRITE_LOG" ]]; then
            tail -10 "$WRITE_LOG"
        fi
        
    } > "$report_file"
    
    echo "Report generated: $report_file"
    cat "$report_file"
}

# Start monitoring
start_monitoring() {
    if [[ "$MONITOR_RUNNING" == "true" ]]; then
        log_warning "Monitoring is already running"
        return 1
    fi
    
    MONITOR_RUNNING=true
    
    # Create log files if they don't exist
    touch "$MONITOR_LOG" "$SECURITY_LOG" "$WRITE_LOG" "$ALERT_LOG" "$PERFORMANCE_LOG"
    
    log_info "Starting write operation monitoring"
    
    # Choose monitoring method
    if command -v inotifywait >/dev/null 2>&1; then
        monitor_with_inotify &
        MONITOR_PID=$!
    else
        monitor_with_polling &
        MONITOR_PID=$!
    fi
    
    # Start background tasks
    start_background_tasks &
    
    log_info "Monitoring started with PID: $MONITOR_PID"
}

# Start background tasks
start_background_tasks() {
    while [[ "$MONITOR_RUNNING" == "true" ]]; do
        # Check for security violations
        check_security_violations
        
        # Rotate logs
        rotate_logs "$MONITOR_LOG" "$MAX_LOG_SIZE"
        rotate_logs "$SECURITY_LOG" "$MAX_LOG_SIZE"
        rotate_logs "$WRITE_LOG" "$MAX_LOG_SIZE"
        rotate_logs "$ALERT_LOG" "$MAX_LOG_SIZE"
        rotate_logs "$PERFORMANCE_LOG" "$MAX_LOG_SIZE"
        
        # Cleanup old logs
        cleanup_old_logs "$LOG_DIR" "$LOG_RETENTION_DAYS"
        
        sleep 300  # Run every 5 minutes
    done
}

# Stop monitoring
stop_monitoring() {
    if [[ "$MONITOR_RUNNING" == "false" ]]; then
        log_warning "Monitoring is not running"
        return 1
    fi
    
    MONITOR_RUNNING=false
    
    if [[ -n "$MONITOR_PID" ]]; then
        kill "$MONITOR_PID" 2>/dev/null || true
        wait "$MONITOR_PID" 2>/dev/null || true
    fi
    
    log_info "Monitoring stopped"
}

# Get monitoring status
get_status() {
    if [[ "$MONITOR_RUNNING" == "true" ]]; then
        echo "Status: Running"
        echo "PID: $MONITOR_PID"
        echo "Alert Count: $ALERT_COUNT"
        echo "Last Alert: $([ $LAST_ALERT_TIME -gt 0 ] && date -d "@$LAST_ALERT_TIME" || echo "None")"
    else
        echo "Status: Stopped"
    fi
}

# Initialize monitoring
init_monitoring() {
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Set up log files
    touch "$MONITOR_LOG" "$SECURITY_LOG" "$WRITE_LOG" "$ALERT_LOG" "$PERFORMANCE_LOG"
    chmod 644 "$MONITOR_LOG" "$SECURITY_LOG" "$WRITE_LOG" "$ALERT_LOG" "$PERFORMANCE_LOG"
    
    log_info "Write operation monitoring initialized"
}

# Main function
main() {
    local command="${1:-help}"
    
    case "$command" in
        "init")
            init_monitoring
            ;;
        "start")
            start_monitoring
            ;;
        "stop")
            stop_monitoring
            ;;
        "status")
            get_status
            ;;
        "report")
            generate_report
            ;;
        "test")
            # Test monitoring functionality
            log_info "Testing monitoring functionality"
            process_write_event "/journals/test.md" "CREATE"
            ;;
        "help"|*)
            echo "Write Operation Monitor"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init     Initialize monitoring system"
            echo "  start    Start monitoring"
            echo "  stop     Stop monitoring"
            echo "  status   Show monitoring status"
            echo "  report   Generate monitoring report"
            echo "  test     Test monitoring functionality"
            echo "  help     Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  MONITOR_INTERVAL     Monitoring interval in seconds (default: 60)"
            echo "  ALERT_THRESHOLD      Alert threshold for violations (default: 5)"
            echo "  MAX_LOG_SIZE         Maximum log file size in bytes (default: 10485760)"
            echo "  LOG_RETENTION_DAYS   Log retention period in days (default: 7)"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
