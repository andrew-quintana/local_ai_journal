#!/bin/bash

# Security Manager for Model Management
# Implements security considerations and resource protection
# Reference: 04-model-management.md

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly MODEL_MANAGER="${SCRIPT_DIR}/model-manager.sh"

# Load model manager
if [[ -f "$MODEL_MANAGER" ]]; then
    source "$MODEL_MANAGER"
else
    echo "ERROR: Model manager not found: $MODEL_MANAGER" >&2
    exit 1
fi

# Security Configuration
readonly SECURITY_LOG="${PROJECT_ROOT}/.security.log"
readonly AUDIT_LOG="${PROJECT_ROOT}/.audit.log"
readonly MAX_CONCURRENT_DOWNLOADS="${MAX_CONCURRENT_DOWNLOADS:-2}"
readonly DOWNLOAD_TIMEOUT="${DOWNLOAD_TIMEOUT:-1800}"  # 30 minutes
readonly MODEL_SIZE_LIMIT_GB="${MODEL_SIZE_LIMIT_GB:-10}"
readonly CPU_LIMIT_PERCENT="${CPU_LIMIT_PERCENT:-80}"

# Security Logging
sec_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user="${USER:-unknown}"
    local hostname=$(hostname)
    
    echo "[$timestamp] [SEC-$level] [$user@$hostname] $message" >> "$SECURITY_LOG"
    log "$level" "$message"
}

# Audit Logging
audit_log() {
    local action="$1"
    local model="$2"
    local result="$3"
    local details="${4:-}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user="${USER:-unknown}"
    local hostname=$(hostname)
    
    echo "[$timestamp] [AUDIT] [$user@$hostname] ACTION=$action MODEL=$model RESULT=$result DETAILS=$details" >> "$AUDIT_LOG"
}

# Model Security Validation

validate_model_integrity() {
    local model_name="$1"
    
    sec_log "INFO" "Validating model integrity: $model_name"
    
    if ! model_exists "$model_name"; then
        sec_log "ERROR" "Model does not exist: $model_name"
        audit_log "INTEGRITY_CHECK" "$model_name" "FAILED" "Model not found"
        return 1
    fi
    
    # Check if model can be loaded and responds correctly
    local test_prompt="Hello, please respond with 'test'"
    local response
    response=$(curl -s -X POST "${OLLAMA_BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model_name}\",\"prompt\":\"${test_prompt}\",\"stream\":false}" \
        --max-time 30 2>/dev/null)
    
    if [[ $? -eq 0 ]] && echo "$response" | jq -e '.response' >/dev/null 2>&1; then
        sec_log "SUCCESS" "Model integrity validation passed: $model_name"
        audit_log "INTEGRITY_CHECK" "$model_name" "PASSED" "Model responds correctly"
        return 0
    else
        sec_log "ERROR" "Model integrity validation failed: $model_name"
        audit_log "INTEGRITY_CHECK" "$model_name" "FAILED" "Model does not respond correctly"
        return 1
    fi
}

# Resource Protection

enforce_resource_limits() {
    local operation="$1"
    local model_name="$2"
    
    sec_log "INFO" "Enforcing resource limits for $operation: $model_name"
    
    # Check memory usage
    local current_memory
    current_memory=$(get_memory_usage)
    
    if (( $(echo "$current_memory > $MAX_MEMORY_GB" | bc -l) )); then
        sec_log "WARN" "Memory usage exceeds limit: ${current_memory}GB > ${MAX_MEMORY_GB}GB"
        audit_log "RESOURCE_LIMIT" "$model_name" "WARN" "Memory limit exceeded"
        
        # Trigger cleanup
        model_cleanup
    fi
    
    # Check CPU usage
    local cpu_usage
    cpu_usage=$(ps -A -o %cpu | awk '{s+=$1} END {print s}' 2>/dev/null || echo "0")
    
    if (( $(echo "$cpu_usage > $CPU_LIMIT_PERCENT" | bc -l) )); then
        sec_log "WARN" "CPU usage exceeds limit: ${cpu_usage}% > ${CPU_LIMIT_PERCENT}%"
        audit_log "RESOURCE_LIMIT" "$model_name" "WARN" "CPU limit exceeded"
    fi
    
    # Check disk space
    local disk_usage
    disk_usage=$(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $disk_usage -gt 90 ]]; then
        sec_log "ERROR" "Disk usage exceeds 90%: ${disk_usage}%"
        audit_log "RESOURCE_LIMIT" "$model_name" "ERROR" "Disk space critical"
        return 1
    fi
    
    sec_log "SUCCESS" "Resource limits check passed"
    return 0
}

# Download Security

secure_model_download() {
    local model_name="$1"
    local progress_callback="${2:-}"
    
    sec_log "INFO" "Starting secure download: $model_name"
    audit_log "DOWNLOAD_START" "$model_name" "STARTED" ""
    
    # Validate model name format
    if ! [[ "$model_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        sec_log "ERROR" "Invalid model name format: $model_name"
        audit_log "DOWNLOAD_START" "$model_name" "FAILED" "Invalid name format"
        return 1
    fi
    
    # Check concurrent downloads
    local current_downloads
    current_downloads=$(ps aux | grep -c "ollama pull" || echo "0")
    
    if [[ $current_downloads -gt $MAX_CONCURRENT_DOWNLOADS ]]; then
        sec_log "ERROR" "Too many concurrent downloads: $current_downloads > $MAX_CONCURRENT_DOWNLOADS"
        audit_log "DOWNLOAD_START" "$model_name" "FAILED" "Too many concurrent downloads"
        return 1
    fi
    
    # Enforce resource limits
    if ! enforce_resource_limits "download" "$model_name"; then
        sec_log "ERROR" "Resource limits check failed for download"
        audit_log "DOWNLOAD_START" "$model_name" "FAILED" "Resource limits exceeded"
        return 1
    fi
    
    # Start download with timeout
    local download_pid
    (
        timeout "$DOWNLOAD_TIMEOUT" model_download "$model_name" "$progress_callback"
    ) &
    download_pid=$!
    
    # Monitor download progress
    local start_time
    start_time=$(date +%s)
    
    while kill -0 "$download_pid" 2>/dev/null; do
        local elapsed=$(( $(date +%s) - start_time ))
        
        # Check for timeout
        if [[ $elapsed -gt $DOWNLOAD_TIMEOUT ]]; then
            sec_log "ERROR" "Download timeout exceeded: ${elapsed}s > ${DOWNLOAD_TIMEOUT}s"
            kill "$download_pid" 2>/dev/null || true
            audit_log "DOWNLOAD_START" "$model_name" "FAILED" "Timeout exceeded"
            return 1
        fi
        
        # Check resource usage during download
        enforce_resource_limits "download" "$model_name" || true
        
        sleep 10
    done
    
    # Check download result
    wait "$download_pid"
    local download_result=$?
    
    if [[ $download_result -eq 0 ]]; then
        sec_log "SUCCESS" "Secure download completed: $model_name"
        audit_log "DOWNLOAD_START" "$model_name" "SUCCESS" ""
        
        # Validate downloaded model
        if validate_model_integrity "$model_name"; then
            sec_log "SUCCESS" "Downloaded model passed integrity check: $model_name"
        else
            sec_log "ERROR" "Downloaded model failed integrity check: $model_name"
            audit_log "DOWNLOAD_START" "$model_name" "FAILED" "Integrity check failed"
            return 1
        fi
    else
        sec_log "ERROR" "Download failed: $model_name (exit code: $download_result)"
        audit_log "DOWNLOAD_START" "$model_name" "FAILED" "Download process failed"
        return 1
    fi
    
    return 0
}

# Model Isolation

isolate_model_execution() {
    local model_name="$1"
    local prompt="$2"
    
    sec_log "INFO" "Isolating model execution: $model_name"
    
    # Create isolated execution environment
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Set up restricted environment
    local restricted_env=(
        "PATH=/usr/bin:/bin"
        "HOME=$temp_dir"
        "TMPDIR=$temp_dir"
        "OLLAMA_HOST=$OLLAMA_HOST"
        "OLLAMA_PORT=$OLLAMA_PORT"
    )
    
    # Execute model with restrictions
    local response
    response=$(env "${restricted_env[@]}" curl -s -X POST "${OLLAMA_BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model_name}\",\"prompt\":\"${prompt}\",\"stream\":false}" \
        --max-time 30 2>/dev/null)
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
    
    if [[ $? -eq 0 ]] && echo "$response" | jq -e '.response' >/dev/null 2>&1; then
        sec_log "SUCCESS" "Isolated model execution completed: $model_name"
        audit_log "MODEL_EXECUTION" "$model_name" "SUCCESS" "Isolated execution"
        echo "$response"
        return 0
    else
        sec_log "ERROR" "Isolated model execution failed: $model_name"
        audit_log "MODEL_EXECUTION" "$model_name" "FAILED" "Isolated execution failed"
        return 1
    fi
}

# Security Monitoring

start_security_monitoring() {
    local check_interval="${1:-300}"  # 5 minutes default
    
    sec_log "INFO" "Starting security monitoring (interval: ${check_interval}s)"
    
    while true; do
        # Monitor for suspicious activity
        monitor_suspicious_activity
        
        # Check resource usage
        enforce_resource_limits "monitoring" "system"
        
        # Validate model integrity
        validate_all_models
        
        # Clean up old logs
        cleanup_security_logs
        
        sleep "$check_interval"
    done
}

monitor_suspicious_activity() {
    # Check for unusual network connections
    local external_connections
    external_connections=$(netstat -an 2>/dev/null | grep -c "ESTABLISHED.*[^127.0.0.1]" || echo "0")
    
    if [[ $external_connections -gt 0 ]]; then
        sec_log "WARN" "External network connections detected: $external_connections"
        audit_log "SECURITY_MONITOR" "system" "WARN" "External connections detected"
    fi
    
    # Check for unusual process activity
    local ollama_processes
    ollama_processes=$(ps aux | grep -c "ollama" || echo "0")
    
    if [[ $ollama_processes -gt 10 ]]; then
        sec_log "WARN" "Unusual number of Ollama processes: $ollama_processes"
        audit_log "SECURITY_MONITOR" "system" "WARN" "Unusual process count"
    fi
}

validate_all_models() {
    local models
    models=$(model_list)
    
    if [[ -n "$models" ]]; then
        echo "$models" | while read -r model; do
            if [[ -n "$model" ]]; then
                validate_model_integrity "$model" || true
            fi
        done
    fi
}

cleanup_security_logs() {
    # Keep only last 1000 lines of security log
    if [[ -f "$SECURITY_LOG" ]] && [[ $(wc -l < "$SECURITY_LOG") -gt 1000 ]]; then
        tail -n 1000 "$SECURITY_LOG" > "${SECURITY_LOG}.tmp" && mv "${SECURITY_LOG}.tmp" "$SECURITY_LOG"
    fi
    
    # Keep only last 1000 lines of audit log
    if [[ -f "$AUDIT_LOG" ]] && [[ $(wc -l < "$AUDIT_LOG") -gt 1000 ]]; then
        tail -n 1000 "$AUDIT_LOG" > "${AUDIT_LOG}.tmp" && mv "${AUDIT_LOG}.tmp" "$AUDIT_LOG"
    fi
}

# Circuit Breaker

implement_circuit_breaker() {
    local operation="$1"
    local model_name="$2"
    local failure_threshold="${3:-3}"
    
    local failure_file="${PROJECT_ROOT}/.circuit_breaker_${operation}_${model_name//[^a-zA-Z0-9._-]/_}"
    local current_failures=0
    
    if [[ -f "$failure_file" ]]; then
        current_failures=$(cat "$failure_file")
    fi
    
    if [[ $current_failures -ge $failure_threshold ]]; then
        sec_log "ERROR" "Circuit breaker open for $operation:$model_name (failures: $current_failures)"
        audit_log "CIRCUIT_BREAKER" "$model_name" "OPEN" "Too many failures"
        return 1
    fi
    
    # Increment failure count on error
    if ! "$@"; then
        echo $((current_failures + 1)) > "$failure_file"
        sec_log "WARN" "Operation failed, incrementing circuit breaker: $operation:$model_name"
        return 1
    else
        # Reset on success
        rm -f "$failure_file"
        return 0
    fi
}

# Security Validation

validate_security_configuration() {
    sec_log "INFO" "Validating security configuration"
    
    local issues=0
    
    # Check if running as non-root
    if [[ $EUID -eq 0 ]]; then
        sec_log "ERROR" "Running as root user - security risk"
        ((issues++))
    fi
    
    # Check file permissions
    if [[ -f "$MODEL_MANAGER" ]] && [[ $(stat -c "%a" "$MODEL_MANAGER" 2>/dev/null || stat -f "%A" "$MODEL_MANAGER" 2>/dev/null || echo "000") != "755" ]]; then
        sec_log "WARN" "Model manager has incorrect permissions"
        ((issues++))
    fi
    
    # Check network binding
    if ! netstat -an 2>/dev/null | grep -q "127.0.0.1.*11434"; then
        sec_log "WARN" "Ollama not bound to localhost only"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        sec_log "SUCCESS" "Security configuration validation passed"
        return 0
    else
        sec_log "ERROR" "Security configuration validation failed ($issues issues)"
        return 1
    fi
}

# Main execution
main() {
    local command="$1"
    shift
    
    case "$command" in
        "validate")
            validate_model_integrity "$@"
            ;;
        "download")
            secure_model_download "$@"
            ;;
        "isolate")
            isolate_model_execution "$@"
            ;;
        "monitor")
            start_security_monitoring "$@"
            ;;
        "circuit")
            implement_circuit_breaker "$@"
            ;;
        "config")
            validate_security_configuration
            ;;
        *)
            echo "Usage: $0 {validate|download|isolate|monitor|circuit|config} [args...]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
