#!/bin/bash

# Security Monitoring and Reporting System
# 
# This system provides real-time security monitoring, alerting,
# and comprehensive reporting for the journals infrastructure.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MONITOR_LOG="$PROJECT_ROOT/logs/security-monitor.log"
ALERT_LOG="$PROJECT_ROOT/logs/security-alerts.log"
METRICS_LOG="$PROJECT_ROOT/logs/security-metrics.log"
REPORT_DIR="$PROJECT_ROOT/security-reports"
CONFIG_FILE="$SCRIPT_DIR/security-validation.conf"

# Default configuration
DEFAULT_PORTS=("3000" "11435")
DEFAULT_CONTAINERS=("journals-webui" "journals-ollama")
DEFAULT_JOURNAL_PATH="/journals"
DEFAULT_MONITOR_INTERVAL="30"
DEFAULT_ALERT_THRESHOLD="1"

# Global variables
MONITORING_ACTIVE=false
ALERT_COUNT=0
VIOLATION_COUNT=0
WARNING_COUNT=0
LAST_CHECK_TIME=""
MONITOR_PID=""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# Logging functions
monitor_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[MONITOR INFO]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[MONITOR WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[MONITOR ERROR]${NC} $message"
            ;;
        "ALERT")
            echo -e "${RED}[SECURITY ALERT]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[MONITOR SUCCESS]${NC} $message"
            ;;
    esac
    
    echo "$timestamp|$level|$message" >> "$MONITOR_LOG"
}

# Initialize monitoring
init_monitoring() {
    mkdir -p "$(dirname "$MONITOR_LOG")"
    mkdir -p "$(dirname "$ALERT_LOG")"
    mkdir -p "$(dirname "$METRICS_LOG")"
    mkdir -p "$REPORT_DIR"
    
    echo "=== SECURITY MONITORING STARTED ===" > "$MONITOR_LOG"
    echo "Timestamp: $(date)" >> "$MONITOR_LOG"
    echo "System: $(uname -a)" >> "$MONITOR_LOG"
    echo "" >> "$MONITOR_LOG"
    
    monitor_log "INFO" "Security monitoring system initialized"
}

# Network security monitoring
monitor_network_security() {
    local violations=0
    
    # Check for unexpected external connections
    for port in "${DEFAULT_PORTS[@]}"; do
        local external_connections=$(netstat -an 2>/dev/null | grep -v "127.0.0.1" | grep -v "::1" | grep ":$port" | wc -l)
        if [[ $external_connections -gt 0 ]]; then
            monitor_log "ALERT" "SECURITY VIOLATION: External connection detected on port $port"
            ((violations++))
            ((ALERT_COUNT++))
        fi
    done
    
    # Check for unexpected port bindings
    for port in "${DEFAULT_PORTS[@]}"; do
        local binding=$(netstat -an 2>/dev/null | grep ":$port" | head -1)
        if [[ -n "$binding" ]] && ! echo "$binding" | grep -q "127.0.0.1"; then
            monitor_log "ALERT" "SECURITY VIOLATION: Port $port not bound to localhost only"
            ((violations++))
            ((ALERT_COUNT++))
        fi
    done
    
    return $violations
}

# File system security monitoring
monitor_filesystem_security() {
    local violations=0
    
    # Check journal directory accessibility
    if [[ ! -d "$DEFAULT_JOURNAL_PATH" ]]; then
        monitor_log "ERROR" "Journal directory not accessible: $DEFAULT_JOURNAL_PATH"
        ((violations++))
        return $violations
    fi
    
    # Check for unauthorized file modifications
    local unauthorized_files=$(find "$DEFAULT_JOURNAL_PATH" -type f ! -name "*.md" ! -name "*.markdown" -newer "$MONITOR_LOG" 2>/dev/null | wc -l)
    if [[ $unauthorized_files -gt 0 ]]; then
        monitor_log "ALERT" "SECURITY VIOLATION: Unauthorized file modifications detected: $unauthorized_files files"
        ((violations++))
        ((ALERT_COUNT++))
    fi
    
    # Check file permissions
    local perms=$(stat -c "%a" "$DEFAULT_JOURNAL_PATH" 2>/dev/null || echo "000")
    if [[ $perms -gt 755 ]]; then
        monitor_log "WARNING" "Journal directory permissions may be too permissive: $perms"
        ((WARNING_COUNT++))
    fi
    
    return $violations
}

# Container security monitoring
monitor_container_security() {
    local violations=0
    
    # Check container status
    for container in "${DEFAULT_CONTAINERS[@]}"; do
        if ! docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^$container$"; then
            monitor_log "WARNING" "Container $container is not running"
            ((WARNING_COUNT++))
        fi
    done
    
    # Check for privileged containers
    for container in "${DEFAULT_CONTAINERS[@]}"; do
        local privileged=$(docker inspect "$container" 2>/dev/null | grep -o '"Privileged":true' | wc -l)
        if [[ $privileged -gt 0 ]]; then
            monitor_log "ALERT" "SECURITY VIOLATION: Container $container is running in privileged mode"
            ((violations++))
            ((ALERT_COUNT++))
        fi
    done
    
    # Check for root user execution
    for container in "${DEFAULT_CONTAINERS[@]}"; do
        local user=$(docker inspect "$container" 2>/dev/null | grep -o '"User":"[^"]*"' | cut -d'"' -f4)
        if [[ "$user" == "root" ]] || [[ "$user" == "0" ]]; then
            monitor_log "WARNING" "Container $container running as root user"
            ((WARNING_COUNT++))
        fi
    done
    
    return $violations
}

# Performance monitoring
monitor_performance() {
    local timestamp=$(date +%s)
    
    # System metrics
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "0")
    local memory_usage=$(ps -A -o %mem | awk '{s+=$1} END {print s}' 2>/dev/null || echo "0")
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    
    # Container metrics
    local container_cpu=0
    local container_memory=0
    
    for container in "${DEFAULT_CONTAINERS[@]}"; do
        if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^$container$"; then
            local stats=$(docker stats --no-stream --format "table {{.CPUPerc}},{{.MemUsage}}" "$container" 2>/dev/null | tail -1)
            if [[ -n "$stats" ]]; then
                local cpu=$(echo "$stats" | cut -d',' -f1 | sed 's/%//')
                local mem=$(echo "$stats" | cut -d',' -f2 | cut -d'/' -f1 | sed 's/[^0-9.]//g')
                container_cpu=$(echo "$container_cpu + $cpu" | bc 2>/dev/null || echo "$container_cpu")
                container_memory=$(echo "$container_memory + $mem" | bc 2>/dev/null || echo "$container_memory")
            fi
        fi
    done
    
    # Log metrics
    echo "$timestamp|CPU|$cpu_usage|$container_cpu" >> "$METRICS_LOG"
    echo "$timestamp|MEMORY|$memory_usage|$container_memory" >> "$METRICS_LOG"
    echo "$timestamp|DISK|$disk_usage|0" >> "$METRICS_LOG"
    
    # Check for performance issues
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        monitor_log "WARNING" "High CPU usage detected: ${cpu_usage}%"
        ((WARNING_COUNT++))
    fi
    
    if (( $(echo "$memory_usage > 80" | bc -l) )); then
        monitor_log "WARNING" "High memory usage detected: ${memory_usage}%"
        ((WARNING_COUNT++))
    fi
    
    if [[ $disk_usage -gt 90 ]]; then
        monitor_log "WARNING" "High disk usage detected: ${disk_usage}%"
        ((WARNING_COUNT++))
    fi
}

# Security event detection
detect_security_events() {
    local events=0
    
    # Check for failed login attempts
    local failed_logins=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l || echo "0")
    if [[ $failed_logins -gt 0 ]]; then
        monitor_log "WARNING" "Failed login attempts detected: $failed_logins"
        ((WARNING_COUNT++))
    fi
    
    # Check for suspicious processes
    local suspicious_procs=$(ps aux | grep -E "(nc|netcat|nmap|masscan)" | grep -v grep | wc -l)
    if [[ $suspicious_procs -gt 0 ]]; then
        monitor_log "WARNING" "Suspicious processes detected: $suspicious_procs"
        ((WARNING_COUNT++))
    fi
    
    # Check for unusual network connections
    local unusual_connections=$(netstat -an | grep -v "127.0.0.1" | grep -v "::1" | grep -v "0.0.0.0" | wc -l)
    if [[ $unusual_connections -gt 10 ]]; then
        monitor_log "WARNING" "Unusual number of network connections: $unusual_connections"
        ((WARNING_COUNT++))
    fi
    
    return $events
}

# Generate security alerts
generate_security_alert() {
    local alert_type="$1"
    local message="$2"
    local severity="${3:-WARNING}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    {
        echo "=== SECURITY ALERT ==="
        echo "Timestamp: $timestamp"
        echo "Type: $alert_type"
        echo "Severity: $severity"
        echo "Message: $message"
        echo "System: $(hostname)"
        echo "User: $(whoami)"
        echo ""
    } >> "$ALERT_LOG"
    
    monitor_log "ALERT" "$message"
    
    # Send alert if configured
    if [[ -n "${ALERT_EMAIL:-}" ]]; then
        send_email_alert "$alert_type" "$message" "$severity"
    fi
    
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        send_webhook_alert "$alert_type" "$message" "$severity"
    fi
}

# Send email alert
send_email_alert() {
    local alert_type="$1"
    local message="$2"
    local severity="$3"
    
    if command -v mail >/dev/null 2>&1; then
        echo "Security Alert: $alert_type - $message" | mail -s "Security Alert - $severity" "$ALERT_EMAIL"
    fi
}

# Send webhook alert
send_webhook_alert() {
    local alert_type="$1"
    local message="$2"
    local severity="$3"
    
    if command -v curl >/dev/null 2>&1; then
        local payload=$(cat <<EOF
{
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "type": "$alert_type",
    "severity": "$severity",
    "message": "$message",
    "system": "$(hostname)"
}
EOF
)
        curl -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK_URL" 2>/dev/null || true
    fi
}

# Generate security report
generate_security_report() {
    local report_file="$REPORT_DIR/security-monitor-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== SECURITY MONITORING REPORT ==="
        echo "Generated: $(date)"
        echo "System: $(uname -a)"
        echo "Hostname: $(hostname)"
        echo ""
        
        echo "=== MONITORING SUMMARY ==="
        echo "Monitoring Duration: $(date -d "@$(( $(date +%s) - $(stat -c %Y "$MONITOR_LOG" 2>/dev/null || echo $(date +%s)) ))" 2>/dev/null || echo "Unknown")"
        echo "Total Alerts: $ALERT_COUNT"
        echo "Total Violations: $VIOLATION_COUNT"
        echo "Total Warnings: $WARNING_COUNT"
        echo ""
        
        if [[ $ALERT_COUNT -eq 0 ]]; then
            echo "SECURITY STATUS: ✅ SECURE"
        elif [[ $ALERT_COUNT -le 2 ]]; then
            echo "SECURITY STATUS: ⚠️  MINOR ISSUES"
        else
            echo "SECURITY STATUS: ❌ SECURITY VIOLATIONS DETECTED"
        fi
        echo ""
        
        echo "=== RECENT ALERTS ==="
        if [[ -f "$ALERT_LOG" ]]; then
            tail -20 "$ALERT_LOG"
        else
            echo "No alerts recorded"
        fi
        echo ""
        
        echo "=== PERFORMANCE METRICS ==="
        if [[ -f "$METRICS_LOG" ]]; then
            echo "Recent CPU usage:"
            tail -10 "$METRICS_LOG" | grep "CPU" | tail -5
            echo ""
            echo "Recent Memory usage:"
            tail -10 "$METRICS_LOG" | grep "MEMORY" | tail -5
            echo ""
            echo "Recent Disk usage:"
            tail -10 "$METRICS_LOG" | grep "DISK" | tail -5
        else
            echo "No metrics recorded"
        fi
        echo ""
        
        echo "=== MONITORING LOG ==="
        if [[ -f "$MONITOR_LOG" ]]; then
            tail -50 "$MONITOR_LOG"
        else
            echo "No monitoring log found"
        fi
        
    } > "$report_file"
    
    monitor_log "INFO" "Security report generated: $report_file"
    echo "$report_file"
}

# Main monitoring loop
monitor_loop() {
    local interval="${1:-$DEFAULT_MONITOR_INTERVAL}"
    
    monitor_log "INFO" "Starting security monitoring loop (interval: ${interval}s)"
    MONITORING_ACTIVE=true
    
    while $MONITORING_ACTIVE; do
        local start_time=$(date +%s)
        
        # Run security checks
        monitor_network_security || ((VIOLATION_COUNT++))
        monitor_filesystem_security || ((VIOLATION_COUNT++))
        monitor_container_security || ((VIOLATION_COUNT++))
        monitor_performance
        detect_security_events
        
        # Update last check time
        LAST_CHECK_TIME=$(date +%s)
        
        # Sleep for remaining interval
        local elapsed=$(($(date +%s) - start_time))
        local sleep_time=$((interval - elapsed))
        if [[ $sleep_time -gt 0 ]]; then
            sleep $sleep_time
        fi
    done
    
    monitor_log "INFO" "Security monitoring loop stopped"
}

# Start monitoring
start_monitoring() {
    local interval="${1:-$DEFAULT_MONITOR_INTERVAL}"
    
    if $MONITORING_ACTIVE; then
        monitor_log "WARNING" "Monitoring is already active"
        return 1
    fi
    
    init_monitoring
    load_config
    
    # Start monitoring in background
    monitor_loop "$interval" &
    MONITOR_PID=$!
    
    monitor_log "INFO" "Security monitoring started (PID: $MONITOR_PID)"
    echo "$MONITOR_PID" > "$PROJECT_ROOT/.monitor.pid"
}

# Stop monitoring
stop_monitoring() {
    if ! $MONITORING_ACTIVE; then
        monitor_log "WARNING" "Monitoring is not active"
        return 1
    fi
    
    MONITORING_ACTIVE=false
    
    if [[ -n "$MONITOR_PID" ]] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID" 2>/dev/null || true
        monitor_log "INFO" "Security monitoring stopped (PID: $MONITOR_PID)"
    fi
    
    rm -f "$PROJECT_ROOT/.monitor.pid"
    MONITOR_PID=""
}

# Get monitoring status
get_monitoring_status() {
    if [[ -f "$PROJECT_ROOT/.monitor.pid" ]]; then
        local pid=$(cat "$PROJECT_ROOT/.monitor.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo "ACTIVE (PID: $pid)"
            return 0
        else
            echo "INACTIVE (stale PID file)"
            return 1
        fi
    else
        echo "INACTIVE"
        return 1
    fi
}

# Run single security check
run_security_check() {
    init_monitoring
    load_config
    
    monitor_log "INFO" "Running single security check..."
    
    local violations=0
    monitor_network_security || ((violations++))
    monitor_filesystem_security || ((violations++))
    monitor_container_security || ((violations++))
    monitor_performance
    detect_security_events
    
    if [[ $violations -eq 0 ]]; then
        monitor_log "SUCCESS" "Security check passed - no violations detected"
        return 0
    else
        monitor_log "ERROR" "Security check failed - $violations violations detected"
        return 1
    fi
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        "start")
            local interval="${2:-$DEFAULT_MONITOR_INTERVAL}"
            start_monitoring "$interval"
            ;;
        "stop")
            stop_monitoring
            ;;
        "status")
            local status=$(get_monitoring_status)
            echo "Monitoring Status: $status"
            ;;
        "check")
            run_security_check
            ;;
        "report")
            generate_security_report
            ;;
        "alerts")
            if [[ -f "$ALERT_LOG" ]]; then
                cat "$ALERT_LOG"
            else
                echo "No alerts recorded"
            fi
            ;;
        "metrics")
            if [[ -f "$METRICS_LOG" ]]; then
                tail -20 "$METRICS_LOG"
            else
                echo "No metrics recorded"
            fi
            ;;
        "logs")
            if [[ -f "$MONITOR_LOG" ]]; then
                tail -50 "$MONITOR_LOG"
            else
                echo "No monitoring log found"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Security Monitoring and Reporting System"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  start [interval]  Start monitoring (default interval: 30s)"
            echo "  stop              Stop monitoring"
            echo "  status            Show monitoring status"
            echo "  check             Run single security check"
            echo "  report            Generate security report"
            echo "  alerts            Show recent alerts"
            echo "  metrics           Show recent metrics"
            echo "  logs              Show recent logs"
            echo "  help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 start 60       Start monitoring with 60-second interval"
            echo "  $0 check          Run single security check"
            echo "  $0 report         Generate security report"
            ;;
        *)
            monitor_log "ERROR" "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
