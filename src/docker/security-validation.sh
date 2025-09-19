#!/bin/bash

# Security Validation System for Journals Infrastructure
# 
# This script provides comprehensive security validation for the journals
# infrastructure including network isolation, file system security,
# container security, and compliance verification.
#
# Security Features:
# - Automated security checks
# - Network isolation validation
# - File system security auditing
# - Container security verification
# - Security reporting and monitoring
# - Compliance verification
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
REPORT_DIR="$PROJECT_ROOT/security-reports"
CONFIG_FILE="$SCRIPT_DIR/security-validation.conf"

# Default configuration
DEFAULT_PORTS=("3000" "11435")
DEFAULT_JOURNAL_PATH="/journals"
DEFAULT_CONTAINERS=("journals-webui" "journals-ollama")
DEFAULT_LOG_LEVEL="INFO"
DEFAULT_MONITORING_INTERVAL="300"

# Global variables
VIOLATIONS=0
WARNINGS=0
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
SECURITY_REPORT=""
CURRENT_TIMESTAMP=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_DIR/security-validation.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_DIR/security-validation.log"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/security-validation.log"
    ((VIOLATIONS++))
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_DIR/security-validation.log"
}

# Initialize logging and directories
init_security_validation() {
    CURRENT_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    # Create necessary directories
    mkdir -p "$LOG_DIR"
    mkdir -p "$REPORT_DIR"
    
    # Initialize log file
    echo "=== SECURITY VALIDATION SESSION STARTED ===" > "$LOG_DIR/security-validation.log"
    echo "Timestamp: $(date)" >> "$LOG_DIR/security-validation.log"
    echo "System: $(uname -a)" >> "$LOG_DIR/security-validation.log"
    echo "" >> "$LOG_DIR/security-validation.log"
    
    log_info "Security validation system initialized"
    log_info "Log directory: $LOG_DIR"
    log_info "Report directory: $REPORT_DIR"
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_info "Configuration loaded from $CONFIG_FILE"
    else
        log_warning "Configuration file not found: $CONFIG_FILE"
        log_info "Using default configuration"
    fi
}

# Network Security Validation
validate_network_isolation() {
    log_info "Starting network isolation validation..."
    local network_violations=0
    
    # Check port binding security
    for port in "${DEFAULT_PORTS[@]}"; do
        ((TOTAL_CHECKS++))
        if netstat -an 2>/dev/null | grep ":$port" | grep -v "127.0.0.1" | grep -v "::1" >/dev/null; then
            log_error "SECURITY VIOLATION: Port $port not bound to localhost only"
            ((network_violations++))
            ((FAILED_CHECKS++))
        else
            log_success "Port $port properly bound to localhost only"
            ((PASSED_CHECKS++))
        fi
    done
    
    # Check for external network access
    ((TOTAL_CHECKS++))
    if docker network ls 2>/dev/null | grep -q "bridge" && ! docker network ls 2>/dev/null | grep -q "journals-internal"; then
        log_warning "Using default bridge network - consider using isolated network"
        ((WARNINGS++))
    else
        log_success "Custom network configuration detected"
        ((PASSED_CHECKS++))
    fi
    
    # Check for unexpected external connections
    ((TOTAL_CHECKS++))
    local external_connections=$(netstat -an 2>/dev/null | grep -v "127.0.0.1" | grep -v "::1" | grep -E ":(3000|11435)" | wc -l)
    if [[ $external_connections -gt 0 ]]; then
        log_error "SECURITY VIOLATION: External connections detected on restricted ports"
        ((network_violations++))
        ((FAILED_CHECKS++))
    else
        log_success "No external connections on restricted ports"
        ((PASSED_CHECKS++))
    fi
    
    return $network_violations
}

# File System Security Auditing
audit_file_permissions() {
    log_info "Starting file system security audit..."
    local fs_violations=0
    
    # Check if journal directory exists and is accessible
    ((TOTAL_CHECKS++))
    if [[ ! -d "$DEFAULT_JOURNAL_PATH" ]]; then
        log_error "Journal directory not found: $DEFAULT_JOURNAL_PATH"
        ((fs_violations++))
        ((FAILED_CHECKS++))
    else
        log_success "Journal directory accessible: $DEFAULT_JOURNAL_PATH"
        ((PASSED_CHECKS++))
    fi
    
    # Test write access to non-markdown files (should fail)
    local test_files=("$DEFAULT_JOURNAL_PATH/security_test.txt" "$DEFAULT_JOURNAL_PATH/test.json" "$DEFAULT_JOURNAL_PATH/test.sh")
    for test_file in "${test_files[@]}"; do
        ((TOTAL_CHECKS++))
        if touch "$test_file" 2>/dev/null; then
            log_error "SECURITY VIOLATION: Write access to non-markdown files detected: $test_file"
            rm -f "$test_file"
            ((fs_violations++))
            ((FAILED_CHECKS++))
        else
            log_success "Non-markdown file write access properly restricted: $(basename "$test_file")"
            ((PASSED_CHECKS++))
        fi
    done
    
    # Test write access to markdown files (should succeed if Phase 5.5 implemented)
    ((TOTAL_CHECKS++))
    local test_md_file="$DEFAULT_JOURNAL_PATH/test_security_validation.md"
    if touch "$test_md_file" 2>/dev/null; then
        log_success "Markdown file write access enabled (Phase 5.5 implemented)"
        rm -f "$test_md_file"
        ((PASSED_CHECKS++))
    else
        log_warning "Markdown file write access disabled (Phase 5.5 not implemented)"
        ((WARNINGS++))
    fi
    
    # Check mount options
    ((TOTAL_CHECKS++))
    if mount | grep "$DEFAULT_JOURNAL_PATH" | grep -q "ro"; then
        log_info "Journals mounted read-only (Phase 5.5 not implemented)"
        ((PASSED_CHECKS++))
    elif mount | grep "$DEFAULT_JOURNAL_PATH" | grep -q "rw"; then
        log_info "Journals mounted read-write (Phase 5.5 implemented)"
        ((PASSED_CHECKS++))
    else
        log_warning "Mount status unclear for journal directory"
        ((WARNINGS++))
    fi
    
    # Check file permissions
    ((TOTAL_CHECKS++))
    local journal_perms=$(stat -c "%a" "$DEFAULT_JOURNAL_PATH" 2>/dev/null || echo "000")
    if [[ "$journal_perms" =~ ^[0-7]{3}$ ]] && [[ $journal_perms -le 755 ]]; then
        log_success "Journal directory permissions secure: $journal_perms"
        ((PASSED_CHECKS++))
    else
        log_warning "Journal directory permissions may be too permissive: $journal_perms"
        ((WARNINGS++))
    fi
    
    return $fs_violations
}

# Container Security Verification
verify_container_security() {
    log_info "Starting container security verification..."
    local container_violations=0
    
    # Check if containers are running
    for container in "${DEFAULT_CONTAINERS[@]}"; do
        ((TOTAL_CHECKS++))
        if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^$container$"; then
            log_success "Container $container is running"
            ((PASSED_CHECKS++))
        else
            log_warning "Container $container is not running"
            ((WARNINGS++))
        fi
    done
    
    # Check for root user execution
    ((TOTAL_CHECKS++))
    local root_containers=$(docker ps --format "table {{.Names}}\t{{.Command}}" 2>/dev/null | grep -v "nonroot" | grep -v "1000:1000" | wc -l)
    if [[ $root_containers -gt 0 ]]; then
        log_warning "Some containers may be running as root"
        ((WARNINGS++))
    else
        log_success "No containers running as root detected"
        ((PASSED_CHECKS++))
    fi
    
    # Check security options
    ((TOTAL_CHECKS++))
    local security_opts=$(docker inspect journals-webui 2>/dev/null | grep -o '"SecurityOpt":\[[^]]*\]' | grep -o 'no-new-privileges' | wc -l)
    if [[ $security_opts -gt 0 ]]; then
        log_success "Security options properly configured"
        ((PASSED_CHECKS++))
    else
        log_warning "Security options may not be properly configured"
        ((WARNINGS++))
    fi
    
    # Check resource limits
    ((TOTAL_CHECKS++))
    local memory_limit=$(docker inspect journals-webui 2>/dev/null | grep -o '"Memory":[0-9]*' | head -1 | cut -d: -f2)
    if [[ -n "$memory_limit" ]] && [[ $memory_limit -gt 0 ]]; then
        log_success "Memory limits configured: $((memory_limit / 1024 / 1024))MB"
        ((PASSED_CHECKS++))
    else
        log_warning "Memory limits not properly configured"
        ((WARNINGS++))
    fi
    
    # Check read-only filesystem
    ((TOTAL_CHECKS++))
    local readonly_fs=$(docker inspect journals-webui 2>/dev/null | grep -o '"ReadonlyRootfs":true' | wc -l)
    if [[ $readonly_fs -gt 0 ]]; then
        log_success "Read-only filesystem enabled"
        ((PASSED_CHECKS++))
    else
        log_warning "Read-only filesystem not enabled"
        ((WARNINGS++))
    fi
    
    return $container_violations
}

# Encryption Status Check
check_encryption_status() {
    log_info "Checking encryption status..."
    local encryption_violations=0
    
    # Check for encryption configuration
    ((TOTAL_CHECKS++))
    if grep -q "WEBUI_SECRET_KEY" "$SCRIPT_DIR/webui-security.conf" 2>/dev/null; then
        log_success "Secret keys configured"
        ((PASSED_CHECKS++))
    else
        log_warning "Secret keys not found in configuration"
        ((WARNINGS++))
    fi
    
    # Check for JWT secret
    ((TOTAL_CHECKS++))
    if grep -q "WEBUI_JWT_SECRET_KEY" "$SCRIPT_DIR/webui-security.conf" 2>/dev/null; then
        log_success "JWT secret configured"
        ((PASSED_CHECKS++))
    else
        log_warning "JWT secret not found in configuration"
        ((WARNINGS++))
    fi
    
    return $encryption_violations
}

# Security Report Generation
generate_security_report() {
    local report_file="$REPORT_DIR/security_report_$CURRENT_TIMESTAMP.txt"
    
    {
        echo "=== SECURITY VALIDATION REPORT ==="
        echo "Generated: $(date)"
        echo "System: $(uname -a)"
        echo "Hostname: $(hostname)"
        echo ""
        
        echo "=== EXECUTIVE SUMMARY ==="
        echo "Total Checks: $TOTAL_CHECKS"
        echo "Passed: $PASSED_CHECKS"
        echo "Failed: $FAILED_CHECKS"
        echo "Warnings: $WARNINGS"
        echo "Violations: $VIOLATIONS"
        echo ""
        
        if [[ $VIOLATIONS -eq 0 ]]; then
            echo "SECURITY STATUS: ✅ SECURE"
        elif [[ $VIOLATIONS -le 2 ]]; then
            echo "SECURITY STATUS: ⚠️  MINOR ISSUES"
        else
            echo "SECURITY STATUS: ❌ SECURITY VIOLATIONS DETECTED"
        fi
        echo ""
        
        echo "=== NETWORK SECURITY ==="
        echo "Port Binding Analysis:"
        for port in "${DEFAULT_PORTS[@]}"; do
            local binding=$(netstat -an 2>/dev/null | grep ":$port" | head -1)
            if [[ -n "$binding" ]]; then
                echo "  Port $port: $binding"
            else
                echo "  Port $port: Not bound"
            fi
        done
        echo ""
        
        echo "=== FILE SYSTEM SECURITY ==="
        echo "Journal Directory: $DEFAULT_JOURNAL_PATH"
        if [[ -d "$DEFAULT_JOURNAL_PATH" ]]; then
            echo "Status: Accessible"
            echo "Permissions: $(stat -c "%a" "$DEFAULT_JOURNAL_PATH" 2>/dev/null || echo "Unknown")"
            echo "Mount Status: $(mount | grep "$DEFAULT_JOURNAL_PATH" | head -1 || echo "Not mounted")"
        else
            echo "Status: Not accessible"
        fi
        echo ""
        
        echo "=== CONTAINER SECURITY ==="
        echo "Container Status:"
        for container in "${DEFAULT_CONTAINERS[@]}"; do
            local status=$(docker ps --format "{{.Status}}" --filter "name=$container" 2>/dev/null || echo "Not running")
            echo "  $container: $status"
        done
        echo ""
        
        echo "=== RECOMMENDATIONS ==="
        if [[ $VIOLATIONS -gt 0 ]]; then
            echo "1. Address security violations immediately"
            echo "2. Review network binding configuration"
            echo "3. Verify file system permissions"
            echo "4. Check container security settings"
        fi
        if [[ $WARNINGS -gt 0 ]]; then
            echo "5. Review warnings for potential improvements"
            echo "6. Consider enabling additional security features"
        fi
        echo ""
        
        echo "=== DETAILED LOG ==="
        if [[ -f "$LOG_DIR/security-validation.log" ]]; then
            cat "$LOG_DIR/security-validation.log"
        fi
        
    } > "$report_file"
    
    log_info "Security report generated: $report_file"
    echo "$report_file"
}

# Monitoring Functions
monitor_network_traffic() {
    log_info "Starting network traffic monitoring..."
    local monitor_duration=${1:-300}  # Default 5 minutes
    
    log_info "Monitoring network traffic for $monitor_duration seconds..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + monitor_duration))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local unexpected_connections=$(netstat -an 2>/dev/null | grep -v "127.0.0.1" | grep -v "::1" | grep -E ":(3000|11435)" | wc -l)
        if [[ $unexpected_connections -gt 0 ]]; then
            log_error "Unexpected external connection detected during monitoring"
        fi
        sleep 30
    done
    
    log_info "Network traffic monitoring completed"
}

monitor_file_access() {
    log_info "Starting file access monitoring..."
    local monitor_duration=${1:-300}  # Default 5 minutes
    
    if ! command -v inotifywait >/dev/null 2>&1; then
        log_warning "inotifywait not available, using polling method"
        monitor_file_access_polling "$monitor_duration"
        return
    fi
    
    log_info "Monitoring file access for $monitor_duration seconds..."
    
    timeout "$monitor_duration" inotifywait -m "$DEFAULT_JOURNAL_PATH" -e access,open,close_read,close_write 2>/dev/null | while read -r line; do
        log_info "FILE ACCESS: $line"
    done
    
    log_info "File access monitoring completed"
}

monitor_file_access_polling() {
    local monitor_duration=$1
    local start_time=$(date +%s)
    local end_time=$((start_time + monitor_duration))
    local last_check=0
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local current_time=$(date +%s)
        if [[ $((current_time - last_check)) -ge 30 ]]; then
            # Check for recent file modifications
            find "$DEFAULT_JOURNAL_PATH" -type f -newermt "30 seconds ago" 2>/dev/null | while read -r file; do
                log_info "FILE MODIFIED: $file"
            done
            last_check=$current_time
        fi
        sleep 10
    done
}

# Main security validation function
run_security_validation() {
    log_info "Starting comprehensive security validation..."
    
    local network_violations=0
    local fs_violations=0
    local container_violations=0
    local encryption_violations=0
    
    # Run all validation checks
    validate_network_isolation || network_violations=$?
    audit_file_permissions || fs_violations=$?
    verify_container_security || container_violations=$?
    check_encryption_status || encryption_violations=$?
    
    # Calculate total violations
    local total_violations=$((network_violations + fs_violations + container_violations + encryption_violations))
    
    # Generate report
    local report_file=$(generate_security_report)
    
    # Summary
    log_info "=== SECURITY VALIDATION COMPLETE ==="
    log_info "Total checks: $TOTAL_CHECKS"
    log_info "Passed: $PASSED_CHECKS"
    log_info "Failed: $FAILED_CHECKS"
    log_info "Warnings: $WARNINGS"
    log_info "Violations: $VIOLATIONS"
    log_info "Report: $report_file"
    
    if [[ $VIOLATIONS -eq 0 ]]; then
        log_success "Security validation PASSED - No violations detected"
        return 0
    else
        log_error "Security validation FAILED - $VIOLATIONS violations detected"
        return 1
    fi
}

# Main execution
main() {
    local command="${1:-run}"
    
    case "$command" in
        "run")
            init_security_validation
            load_config
            run_security_validation
            ;;
        "network")
            init_security_validation
            load_config
            validate_network_isolation
            ;;
        "filesystem")
            init_security_validation
            load_config
            audit_file_permissions
            ;;
        "container")
            init_security_validation
            load_config
            verify_container_security
            ;;
        "encryption")
            init_security_validation
            load_config
            check_encryption_status
            ;;
        "monitor")
            init_security_validation
            load_config
            local duration=${2:-300}
            monitor_network_traffic "$duration" &
            monitor_file_access "$duration" &
            wait
            ;;
        "report")
            init_security_validation
            load_config
            generate_security_report
            ;;
        "help"|"-h"|"--help")
            echo "Security Validation System"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  run         Run complete security validation (default)"
            echo "  network     Validate network isolation only"
            echo "  filesystem  Audit file system security only"
            echo "  container   Verify container security only"
            echo "  encryption  Check encryption status only"
            echo "  monitor     Monitor network and file access"
            echo "  report      Generate security report only"
            echo "  help        Show this help message"
            echo ""
            echo "Options:"
            echo "  monitor [duration]  Monitor for specified seconds (default: 300)"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
