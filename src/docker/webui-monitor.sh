#!/bin/bash

# webui-monitor.sh - WebUI Security Monitoring and Access Control
# 
# This script provides comprehensive monitoring for the Open WebUI
# including access logging, security event detection, and violation alerting.
#
# Security Features:
# - Real-time access monitoring
# - Security event detection
# - Violation alerting and logging
# - Performance monitoring
# - Audit trail maintenance
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly WEBUI_SECURITY_MANAGER="$SCRIPT_DIR/webui-security-manager.sh"
readonly MONITOR_LOG_FILE="${PROJECT_ROOT}/.webui-monitor.log"
readonly ALERT_LOG_FILE="${PROJECT_ROOT}/.webui-alerts.log"
readonly ACCESS_LOG_FILE="${PROJECT_ROOT}/.webui-access.log"

# Monitoring Configuration
readonly WEBUI_CONTAINER="journals-webui"
readonly OLLAMA_CONTAINER="journals-ollama"
readonly WEBUI_PORT="${WEBUI_PORT:-3000}"
readonly OLLAMA_PORT="${OLLAMA_PORT:-11434}"
readonly MONITOR_INTERVAL="${MONITOR_INTERVAL:-60}"  # 1 minute default
readonly MAX_ACCESS_ATTEMPTS="${MAX_ACCESS_ATTEMPTS:-100}"
readonly MAX_VIOLATIONS="${MAX_VIOLATIONS:-5}"
readonly ALERT_THRESHOLD="${ALERT_THRESHOLD:-3}"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Monitoring state
MONITORING_ACTIVE=false
VIOLATION_COUNT=0
ACCESS_COUNT=0
LAST_ALERT_TIME=0

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user="${USER:-unknown}"
    local hostname=$(hostname)
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            echo "[$timestamp] [ERROR] [$user@$hostname] $message" >> "$MONITOR_LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            echo "[$timestamp] [WARN] [$user@$hostname] $message" >> "$MONITOR_LOG_FILE"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] [$user@$hostname] $message" >> "$MONITOR_LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "[$timestamp] [SUCCESS] [$user@$hostname] $message" >> "$MONITOR_LOG_FILE"
            ;;
        "MONITOR")
            echo -e "${CYAN}[MONITOR]${NC} $message"
            echo "[$timestamp] [MONITOR] [$user@$hostname] $message" >> "$MONITOR_LOG_FILE"
            ;;
        "ALERT")
            echo -e "${RED}[ALERT]${NC} $message" >&2
            echo "[$timestamp] [ALERT] [$user@$hostname] $message" >> "$ALERT_LOG_FILE"
            ;;
    esac
}

# Access logging
access_log() {
    local action="$1"
    local target="$2"
    local result="$3"
    local details="${4:-}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user="${USER:-unknown}"
    local hostname=$(hostname)
    local client_ip="${SSH_CLIENT%% *}"  # Extract IP from SSH_CLIENT if available
    
    echo "[$timestamp] [ACCESS] [$user@$hostname] CLIENT=$client_ip ACTION=$action TARGET=$target RESULT=$result DETAILS=$details" >> "$ACCESS_LOG_FILE"
}

# Alert functions
send_alert() {
    local alert_type="$1"
    local message="$2"
    local severity="${3:-WARNING}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local current_time=$(date +%s)
    
    # Rate limiting for alerts
    if [[ $((current_time - LAST_ALERT_TIME)) -lt 300 ]]; then  # 5 minutes
        log "WARN" "Alert rate limited: $alert_type"
        return 0
    fi
    
    log "ALERT" "[$severity] $alert_type: $message"
    LAST_ALERT_TIME=$current_time
    
    # Log to alert file
    echo "[$timestamp] [ALERT] [$severity] $alert_type: $message" >> "$ALERT_LOG_FILE"
}

# WebUI Container Monitoring

monitor_webui_container() {
    log "MONITOR" "Monitoring WebUI container status..."
    
    # Check if WebUI container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "^${WEBUI_CONTAINER}$"; then
        send_alert "CONTAINER_DOWN" "WebUI container is not running" "CRITICAL"
        access_log "CONTAINER_CHECK" "webui" "DOWN" "Container not running"
        return 1
    fi
    
    # Check container health
    local container_health
    container_health=$(docker inspect "$WEBUI_CONTAINER" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    
    if [[ "$container_health" == "unhealthy" ]]; then
        send_alert "CONTAINER_UNHEALTHY" "WebUI container is unhealthy" "WARNING"
        access_log "CONTAINER_CHECK" "webui" "UNHEALTHY" "Container health check failed"
    elif [[ "$container_health" == "healthy" ]]; then
        access_log "CONTAINER_CHECK" "webui" "HEALTHY" "Container running normally"
    else
        log "WARN" "WebUI container health status unknown: $container_health"
    fi
    
    # Check container resource usage
    monitor_container_resources
    
    return 0
}

monitor_container_resources() {
    # Check memory usage
    local memory_usage
    memory_usage=$(docker stats --no-stream --format "table {{.MemUsage}}" "$WEBUI_CONTAINER" 2>/dev/null | tail -n 1 || echo "unknown")
    
    if [[ "$memory_usage" != "unknown" ]]; then
        local memory_mb
        memory_mb=$(echo "$memory_usage" | grep -o '[0-9.]*' | head -n 1)
        
        if (( $(echo "$memory_mb > 1500" | bc -l 2>/dev/null || echo "0") )); then
            send_alert "HIGH_MEMORY_USAGE" "WebUI memory usage high: $memory_usage" "WARNING"
        fi
        
        access_log "RESOURCE_CHECK" "webui_memory" "OK" "Usage: $memory_usage"
    fi
    
    # Check CPU usage
    local cpu_usage
    cpu_usage=$(docker stats --no-stream --format "table {{.CPUPerc}}" "$WEBUI_CONTAINER" 2>/dev/null | tail -n 1 || echo "unknown")
    
    if [[ "$cpu_usage" != "unknown" ]]; then
        local cpu_percent
        cpu_percent=$(echo "$cpu_usage" | grep -o '[0-9.]*' | head -n 1)
        
        if (( $(echo "$cpu_percent > 80" | bc -l 2>/dev/null || echo "0") )); then
            send_alert "HIGH_CPU_USAGE" "WebUI CPU usage high: $cpu_usage" "WARNING"
        fi
        
        access_log "RESOURCE_CHECK" "webui_cpu" "OK" "Usage: $cpu_usage"
    fi
}

# Network Security Monitoring

monitor_network_security() {
    log "MONITOR" "Monitoring network security..."
    
    # Check WebUI port binding
    local webui_localhost
    webui_localhost=$(netstat -an 2>/dev/null | grep -c "127.0.0.1:$WEBUI_PORT" || echo "0")
    
    if [[ "$webui_localhost" -eq 0 ]]; then
        send_alert "PORT_NOT_BOUND" "WebUI port $WEBUI_PORT not bound to localhost" "CRITICAL"
        access_log "NETWORK_CHECK" "webui_port" "FAILED" "Not bound to localhost"
    else
        access_log "NETWORK_CHECK" "webui_port" "OK" "Bound to localhost"
    fi
    
    # Check for external port binding (security violation)
    local webui_external
    webui_external=$(netstat -an 2>/dev/null | grep -c "0.0.0.0:$WEBUI_PORT" || echo "0")
    
    if [[ "$webui_external" -gt 0 ]]; then
        send_alert "SECURITY_VIOLATION" "WebUI bound to external interfaces" "CRITICAL"
        access_log "NETWORK_CHECK" "webui_port" "VIOLATION" "External binding detected"
        ((VIOLATION_COUNT++))
    else
        access_log "NETWORK_CHECK" "webui_port" "SECURE" "No external binding"
    fi
    
    # Check for external connections
    local external_connections
    external_connections=$(netstat -an 2>/dev/null | grep -c "ESTABLISHED.*[^127.0.0.1]" || echo "0")
    
    if [[ $external_connections -gt 0 ]]; then
        send_alert "EXTERNAL_CONNECTIONS" "External network connections detected: $external_connections" "WARNING"
        access_log "NETWORK_CHECK" "external_connections" "WARNING" "Count: $external_connections"
    else
        access_log "NETWORK_CHECK" "external_connections" "OK" "No external connections"
    fi
}

# File System Security Monitoring

monitor_filesystem_security() {
    log "MONITOR" "Monitoring filesystem security..."
    
    # Test read-only mount
    local write_test
    write_test=$(docker exec "$WEBUI_CONTAINER" touch /journals/security-test-write 2>&1 || echo "write_failed")
    
    if [[ "$write_test" == *"write_failed"* ]] || [[ "$write_test" == *"Read-only"* ]] || [[ "$write_test" == *"Permission denied"* ]]; then
        access_log "FILESYSTEM_CHECK" "readonly_mount" "OK" "Write access properly blocked"
    else
        send_alert "SECURITY_VIOLATION" "Write access to journals directory allowed" "CRITICAL"
        access_log "FILESYSTEM_CHECK" "readonly_mount" "VIOLATION" "Write access detected"
        ((VIOLATION_COUNT++))
    fi
    
    # Clean up test file if it was created
    docker exec "$WEBUI_CONTAINER" rm -f /journals/security-test-write 2>/dev/null || true
    
    # Check journal directory access
    local journal_access
    journal_access=$(docker exec "$WEBUI_CONTAINER" ls /journals >/dev/null 2>&1 && echo "accessible" || echo "not_accessible")
    
    if [[ "$journal_access" == "accessible" ]]; then
        access_log "FILESYSTEM_CHECK" "journal_access" "OK" "Journals directory accessible"
    else
        send_alert "ACCESS_DENIED" "Cannot access journals directory" "WARNING"
        access_log "FILESYSTEM_CHECK" "journal_access" "FAILED" "Directory not accessible"
    fi
}

# Access Pattern Monitoring

monitor_access_patterns() {
    log "MONITOR" "Monitoring access patterns..."
    
    # Count access attempts in the last hour
    local current_time=$(date +%s)
    local one_hour_ago=$((current_time - 3600))
    
    # Count access log entries from the last hour
    local recent_accesses
    recent_accesses=$(awk -v cutoff="$one_hour_ago" '
        BEGIN { count = 0 }
        {
            # Extract timestamp and convert to epoch
            gsub(/\[|\]/, "", $1)
            gsub(/\[|\]/, "", $2)
            timestamp = $1 " " $2
            epoch = mktime(gsub(/-/, " ", substr(timestamp, 1, 10)) " " substr(timestamp, 12, 8))
            if (epoch > cutoff) count++
        }
        END { print count }
    ' "$ACCESS_LOG_FILE" 2>/dev/null || echo "0")
    
    if [[ $recent_accesses -gt $MAX_ACCESS_ATTEMPTS ]]; then
        send_alert "HIGH_ACCESS_RATE" "High access rate detected: $recent_accesses attempts in last hour" "WARNING"
        access_log "ACCESS_PATTERN" "rate_check" "WARNING" "High rate: $recent_accesses"
    else
        access_log "ACCESS_PATTERN" "rate_check" "OK" "Normal rate: $recent_accesses"
    fi
    
    # Check for suspicious access patterns
    monitor_suspicious_activity
}

monitor_suspicious_activity() {
    # Check for repeated failed access attempts
    local failed_attempts
    failed_attempts=$(grep -c "RESULT=FAILED\|RESULT=VIOLATION" "$ACCESS_LOG_FILE" 2>/dev/null || echo "0")
    
    if [[ $failed_attempts -gt 10 ]]; then
        send_alert "SUSPICIOUS_ACTIVITY" "Multiple failed access attempts detected: $failed_attempts" "WARNING"
        access_log "SECURITY_CHECK" "suspicious_activity" "WARNING" "Failed attempts: $failed_attempts"
    fi
    
    # Check for unusual process activity
    local webui_processes
    webui_processes=$(docker exec "$WEBUI_CONTAINER" ps aux 2>/dev/null | wc -l || echo "0")
    
    if [[ $webui_processes -gt 50 ]]; then
        send_alert "HIGH_PROCESS_COUNT" "Unusual number of processes in WebUI container: $webui_processes" "WARNING"
        access_log "SECURITY_CHECK" "process_count" "WARNING" "High count: $webui_processes"
    fi
}

# Security Event Detection

detect_security_events() {
    log "MONITOR" "Detecting security events..."
    
    # Check for security violations
    if [[ $VIOLATION_COUNT -gt $MAX_VIOLATIONS ]]; then
        send_alert "SECURITY_VIOLATIONS" "Too many security violations detected: $VIOLATION_COUNT" "CRITICAL"
        access_log "SECURITY_CHECK" "violation_count" "CRITICAL" "Count: $VIOLATION_COUNT"
    fi
    
    # Check for container escape attempts
    local escape_attempts
    escape_attempts=$(docker exec "$WEBUI_CONTAINER" ls /host 2>/dev/null && echo "detected" || echo "none")
    
    if [[ "$escape_attempts" == "detected" ]]; then
        send_alert "CONTAINER_ESCAPE" "Potential container escape attempt detected" "CRITICAL"
        access_log "SECURITY_CHECK" "container_escape" "CRITICAL" "Host filesystem accessible"
        ((VIOLATION_COUNT++))
    fi
    
    # Check for privilege escalation attempts
    local privilege_check
    privilege_check=$(docker exec "$WEBUI_CONTAINER" id 2>/dev/null | grep -o "uid=0" || echo "non_root")
    
    if [[ "$privilege_check" == "uid=0" ]]; then
        send_alert "PRIVILEGE_ESCALATION" "WebUI running as root user" "CRITICAL"
        access_log "SECURITY_CHECK" "privilege_escalation" "CRITICAL" "Running as root"
        ((VIOLATION_COUNT++))
    fi
}

# Performance Monitoring

monitor_performance() {
    log "MONITOR" "Monitoring performance metrics..."
    
    # Check WebUI response time
    local response_time
    response_time=$(curl -w "%{time_total}" -s -o /dev/null "http://127.0.0.1:$WEBUI_PORT/" 2>/dev/null || echo "timeout")
    
    if [[ "$response_time" == "timeout" ]]; then
        send_alert "RESPONSE_TIMEOUT" "WebUI not responding to health checks" "WARNING"
        access_log "PERFORMANCE_CHECK" "response_time" "TIMEOUT" "No response"
    elif (( $(echo "$response_time > 5.0" | bc -l 2>/dev/null || echo "0") )); then
        send_alert "SLOW_RESPONSE" "WebUI response time slow: ${response_time}s" "WARNING"
        access_log "PERFORMANCE_CHECK" "response_time" "SLOW" "Time: ${response_time}s"
    else
        access_log "PERFORMANCE_CHECK" "response_time" "OK" "Time: ${response_time}s"
    fi
    
    # Check Ollama connectivity
    local ollama_response
    ollama_response=$(curl -w "%{time_total}" -s -o /dev/null "http://127.0.0.1:$OLLAMA_PORT/api/tags" 2>/dev/null || echo "timeout")
    
    if [[ "$ollama_response" == "timeout" ]]; then
        send_alert "OLLAMA_TIMEOUT" "Ollama not responding" "WARNING"
        access_log "PERFORMANCE_CHECK" "ollama_response" "TIMEOUT" "No response"
    else
        access_log "PERFORMANCE_CHECK" "ollama_response" "OK" "Time: ${ollama_response}s"
    fi
}

# Log Management

manage_logs() {
    log "MONITOR" "Managing log files..."
    
    # Rotate logs if they get too large
    local max_log_size=10485760  # 10MB
    
    for log_file in "$MONITOR_LOG_FILE" "$ALERT_LOG_FILE" "$ACCESS_LOG_FILE"; do
        if [[ -f "$log_file" ]] && [[ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0") -gt $max_log_size ]]; then
            log "INFO" "Rotating log file: $log_file"
            mv "$log_file" "${log_file}.old"
            touch "$log_file"
        fi
    done
    
    # Clean up old rotated logs
    find "$PROJECT_ROOT" -name "*.log.old" -mtime +7 -delete 2>/dev/null || true
}

# Main monitoring loop

start_monitoring() {
    local interval="${1:-$MONITOR_INTERVAL}"
    
    log "MONITOR" "Starting WebUI security monitoring (interval: ${interval}s)"
    MONITORING_ACTIVE=true
    
    # Initialize log files
    touch "$MONITOR_LOG_FILE" "$ALERT_LOG_FILE" "$ACCESS_LOG_FILE"
    
    # Start monitoring loop
    while [[ "$MONITORING_ACTIVE" == "true" ]]; do
        log "MONITOR" "Running security monitoring cycle..."
        
        # Run all monitoring functions
        monitor_webui_container
        monitor_network_security
        monitor_filesystem_security
        monitor_access_patterns
        detect_security_events
        monitor_performance
        manage_logs
        
        # Reset violation count if no new violations
        if [[ $VIOLATION_COUNT -gt 0 ]]; then
            log "WARN" "Security violations detected: $VIOLATION_COUNT"
        else
            log "SUCCESS" "No security violations detected"
        fi
        
        # Wait for next cycle
        sleep "$interval"
    done
    
    log "MONITOR" "WebUI security monitoring stopped"
}

stop_monitoring() {
    log "MONITOR" "Stopping WebUI security monitoring..."
    MONITORING_ACTIVE=false
}

# Status reporting

get_monitoring_status() {
    echo "=== WebUI Security Monitoring Status ==="
    echo "Monitoring Active: $MONITORING_ACTIVE"
    echo "Violation Count: $VIOLATION_COUNT"
    echo "Access Count: $ACCESS_COUNT"
    echo "Last Alert Time: $(date -d "@$LAST_ALERT_TIME" 2>/dev/null || echo "Never")"
    echo
    echo "=== Recent Alerts ==="
    tail -n 10 "$ALERT_LOG_FILE" 2>/dev/null || echo "No alerts recorded"
    echo
    echo "=== Recent Access Logs ==="
    tail -n 10 "$ACCESS_LOG_FILE" 2>/dev/null || echo "No access logs recorded"
    echo
    echo "=== Container Status ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(webui|ollama)" || echo "No containers running"
}

# Main function
main() {
    local command="${1:-}"
    
    case "$command" in
        "start")
            local interval="${2:-$MONITOR_INTERVAL}"
            start_monitoring "$interval"
            ;;
        "stop")
            stop_monitoring
            ;;
        "status")
            get_monitoring_status
            ;;
        "test")
            # Run a single monitoring cycle
            monitor_webui_container
            monitor_network_security
            monitor_filesystem_security
            monitor_access_patterns
            detect_security_events
            monitor_performance
            ;;
        "help"|"--help"|"-h")
            cat << EOF
WebUI Security Monitor

Usage: $0 <command> [options]

Commands:
  start [interval]        Start monitoring (default: 60s interval)
  stop                   Stop monitoring
  status                 Show monitoring status
  test                   Run single monitoring cycle
  help                   Show this help message

Monitoring Features:
  - Container health monitoring
  - Network security validation
  - Filesystem security checks
  - Access pattern analysis
  - Security event detection
  - Performance monitoring
  - Log management

Examples:
  $0 start               # Start monitoring with default interval
  $0 start 30            # Start monitoring with 30-second interval
  $0 status              # Show current status
  $0 test                # Run single monitoring cycle

EOF
            ;;
        "")
            log "ERROR" "No command specified. Use '$0 help' for usage information."
            exit 1
            ;;
        *)
            log "ERROR" "Unknown command: $command. Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

