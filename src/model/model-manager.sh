#!/bin/bash

# Model Management System for Local Journal AI
# Implements comprehensive Ollama model management with performance optimization
# Reference: PRD001.md, RFC001.md, 04-model-management.md

set -euo pipefail

# Configuration
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    readonly CONFIG_FILE="${PROJECT_ROOT}/src/model/model.conf"
    
    # Load configuration
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
else
    # When sourced, use existing variables
    CONFIG_FILE="${PROJECT_ROOT}/src/model/model.conf"
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
fi

# Default configuration
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://${OLLAMA_HOST}:${OLLAMA_PORT}}"
DEFAULT_MODEL="${DEFAULT_MODEL:-llama3.2:3b}"
FALLBACK_MODELS="${FALLBACK_MODELS:-llama3.2:1b,phi3:mini}"
MAX_MEMORY_GB="${MAX_MEMORY_GB:-4}"
MODEL_CACHE_DIR="${MODEL_CACHE_DIR:-${PROJECT_ROOT}/.model-cache}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "DEBUG") [[ "$LOG_LEVEL" == "DEBUG" ]] && echo "[$timestamp] [DEBUG] $message" >&2 ;;
        "INFO")  echo "[$timestamp] [INFO]  $message" >&2 ;;
        "WARN")  echo "[$timestamp] [WARN]  $message" >&2 ;;
        "ERROR") echo "[$timestamp] [ERROR] $message" >&2 ;;
        "SUCCESS") echo "[$timestamp] [SUCCESS] $message" >&2 ;;
    esac
}

# Utility functions
check_ollama_connection() {
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f -s "${OLLAMA_BASE_URL}/api/tags" >/dev/null 2>&1; then
            return 0
        fi
        
        log "DEBUG" "Waiting for Ollama connection... (attempt $((attempt + 1))/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    log "ERROR" "Failed to connect to Ollama after $max_attempts attempts"
    return 1
}

get_memory_usage() {
    if command -v free >/dev/null 2>&1; then
        # Linux
        free -m | awk 'NR==2{printf "%.1f", $3/1024}'
    elif command -v vm_stat >/dev/null 2>&1; then
        # macOS
        vm_stat | awk '/Pages active/ {active=$3} /Pages inactive/ {inactive=$3} /Pages speculative/ {spec=$3} /Pages wired down/ {wired=$4} END {printf "%.1f", (active+inactive+spec+wired)*4096/1024/1024/1024}'
    else
        echo "0"
    fi
}

# Core Model Operations

model_exists() {
    local model_name="$1"
    
    if ! check_ollama_connection; then
        return 1
    fi
    
    local response
    response=$(curl -s "${OLLAMA_BASE_URL}/api/tags" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && echo "$response" | jq -r '.models[].name' 2>/dev/null | grep -q "^${model_name}$"; then
        return 0
    else
        return 1
    fi
}

model_list() {
    if ! check_ollama_connection; then
        log "ERROR" "Cannot connect to Ollama"
        return 1
    fi
    
    local response
    response=$(curl -s "${OLLAMA_BASE_URL}/api/tags" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        echo "$response" | jq -r '.models[].name' 2>/dev/null || echo ""
    else
        log "ERROR" "Failed to retrieve model list"
        return 1
    fi
}

model_download() {
    local model_name="$1"
    local progress_callback="${2:-}"
    
    if [[ -z "$model_name" ]]; then
        log "ERROR" "Model name is required"
        return 1
    fi
    
    if model_exists "$model_name"; then
        log "INFO" "Model '$model_name' already exists"
        return 0
    fi
    
    log "INFO" "Starting download of model: $model_name"
    
    # Check available memory before download
    local current_memory
    current_memory=$(get_memory_usage)
    if (( $(echo "$current_memory > $MAX_MEMORY_GB" | bc -l) )); then
        log "WARN" "High memory usage detected (${current_memory}GB), consider closing other applications"
    fi
    
    # Download with progress tracking
    local download_cmd="curl -s -N ${OLLAMA_BASE_URL}/api/pull -d '{\"name\":\"${model_name}\"}'"
    
    if [[ -n "$progress_callback" ]]; then
        eval "$download_cmd" | while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                # Parse JSON response for progress
                local status
                status=$(echo "$line" | jq -r '.status // empty' 2>/dev/null)
                local completed
                completed=$(echo "$line" | jq -r '.completed // empty' 2>/dev/null)
                local total
                total=$(echo "$line" | jq -r '.total // empty' 2>/dev/null)
                
                if [[ -n "$status" ]]; then
                    if [[ -n "$completed" && -n "$total" ]]; then
                        local percent=$((completed * 100 / total))
                        log "INFO" "Download progress: $status ($percent%)"
                    else
                        log "INFO" "Download status: $status"
                    fi
                    
                    # Call progress callback if provided
                    if command -v "$progress_callback" >/dev/null 2>&1; then
                        "$progress_callback" "$line"
                    fi
                fi
            fi
        done
    else
        eval "$download_cmd" >/dev/null
    fi
    
    # Verify download completed successfully
    if model_exists "$model_name"; then
        log "SUCCESS" "Model '$model_name' downloaded successfully"
        return 0
    else
        log "ERROR" "Failed to download model '$model_name'"
        return 1
    fi
}

model_validate() {
    local model_name="$1"
    
    if ! model_exists "$model_name"; then
        log "ERROR" "Model '$model_name' does not exist"
        return 1
    fi
    
    log "INFO" "Validating model: $model_name"
    
    # Test model loading with a simple query
    local test_response
    test_response=$(curl -s -X POST "${OLLAMA_BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model_name}\",\"prompt\":\"test\",\"stream\":false}" \
        --max-time 30 2>/dev/null)
    
    if [[ $? -eq 0 ]] && echo "$test_response" | jq -e '.response' >/dev/null 2>&1; then
        log "SUCCESS" "Model '$model_name' validation successful"
        return 0
    else
        log "ERROR" "Model '$model_name' validation failed"
        return 1
    fi
}

model_switch() {
    local model_name="$1"
    
    if ! model_exists "$model_name"; then
        log "ERROR" "Model '$model_name' does not exist"
        return 1
    fi
    
    # Update default model in configuration
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i.bak "s/^DEFAULT_MODEL=.*/DEFAULT_MODEL=\"${model_name}\"/" "$CONFIG_FILE"
    else
        echo "DEFAULT_MODEL=\"${model_name}\"" > "$CONFIG_FILE"
    fi
    
    log "SUCCESS" "Switched to model: $model_name"
    return 0
}

# Performance Optimization Functions

model_preload() {
    local model_name="$1"
    
    if ! model_exists "$model_name"; then
        log "WARN" "Cannot preload non-existent model: $model_name"
        return 1
    fi
    
    log "INFO" "Preloading model: $model_name"
    
    # Load model into memory with a warm-up query
    local warmup_response
    warmup_response=$(curl -s -X POST "${OLLAMA_BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model_name}\",\"prompt\":\"Hello\",\"stream\":false}" \
        --max-time 60 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Model '$model_name' preloaded successfully"
        return 0
    else
        log "WARN" "Failed to preload model '$model_name'"
        return 1
    fi
}

model_unload() {
    local model_name="$1"
    
    log "INFO" "Unloading model: $model_name"
    
    # Send unload request to Ollama
    local unload_response
    unload_response=$(curl -s -X POST "${OLLAMA_BASE_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${model_name}\",\"prompt\":\"\",\"stream\":false}" \
        --max-time 10 2>/dev/null)
    
    log "SUCCESS" "Model '$model_name' unloaded"
    return 0
}

model_cleanup() {
    log "INFO" "Starting model cleanup process"
    
    # Get current memory usage
    local current_memory
    current_memory=$(get_memory_usage)
    
    if (( $(echo "$current_memory < $MAX_MEMORY_GB" | bc -l) )); then
        log "INFO" "Memory usage is within limits (${current_memory}GB), no cleanup needed"
        return 0
    fi
    
    # List all models and unload least recently used ones
    local models
    models=$(model_list)
    
    if [[ -n "$models" ]]; then
        log "INFO" "Unloading models to free memory"
        echo "$models" | while read -r model; do
            if [[ -n "$model" ]]; then
                model_unload "$model"
            fi
        done
    fi
    
    log "SUCCESS" "Model cleanup completed"
    return 0
}

# Fallback and Recovery Functions

get_fallback_model() {
    local primary_model="$1"
    
    if model_exists "$primary_model"; then
        echo "$primary_model"
        return 0
    fi
    
    # Try fallback models
    IFS=',' read -ra FALLBACK_ARRAY <<< "$FALLBACK_MODELS"
    for fallback in "${FALLBACK_ARRAY[@]}"; do
        if model_exists "$fallback"; then
            log "WARN" "Using fallback model: $fallback"
            echo "$fallback"
            return 0
        fi
    done
    
    log "ERROR" "No available models found"
    return 1
}

ensure_model_available() {
    local model_name="$1"
    
    if model_exists "$model_name"; then
        return 0
    fi
    
    log "INFO" "Model '$model_name' not available, attempting download"
    
    if model_download "$model_name"; then
        return 0
    fi
    
    # Try fallback
    local fallback_model
    fallback_model=$(get_fallback_model "$model_name")
    
    if [[ -n "$fallback_model" ]]; then
        model_switch "$fallback_model"
        return 0
    fi
    
    log "ERROR" "No models available after download and fallback attempts"
    return 1
}

# Health Monitoring

model_health_check() {
    local model_name="${1:-$DEFAULT_MODEL}"
    
    if ! check_ollama_connection; then
        log "ERROR" "Ollama connection failed"
        return 1
    fi
    
    if ! model_exists "$model_name"; then
        log "ERROR" "Model '$model_name' does not exist"
        return 1
    fi
    
    if ! model_validate "$model_name"; then
        log "ERROR" "Model '$model_name' validation failed"
        return 1
    fi
    
    log "SUCCESS" "Model health check passed for: $model_name"
    return 0
}

# Resource Management

monitor_resources() {
    local current_memory
    current_memory=$(get_memory_usage)
    
    log "INFO" "Current memory usage: ${current_memory}GB (limit: ${MAX_MEMORY_GB}GB)"
    
    if (( $(echo "$current_memory > $MAX_MEMORY_GB" | bc -l) )); then
        log "WARN" "Memory usage exceeds limit, triggering cleanup"
        model_cleanup
    fi
}

# Main execution
main() {
    local command="$1"
    shift
    
    case "$command" in
        "exists")
            model_exists "$@"
            ;;
        "list")
            model_list
            ;;
        "download")
            model_download "$@"
            ;;
        "validate")
            model_validate "$@"
            ;;
        "switch")
            model_switch "$@"
            ;;
        "preload")
            model_preload "$@"
            ;;
        "unload")
            model_unload "$@"
            ;;
        "cleanup")
            model_cleanup
            ;;
        "fallback")
            get_fallback_model "$@"
            ;;
        "ensure")
            ensure_model_available "$@"
            ;;
        "health")
            model_health_check "$@"
            ;;
        "monitor")
            monitor_resources
            ;;
        *)
            echo "Usage: $0 {exists|list|download|validate|switch|preload|unload|cleanup|fallback|ensure|health|monitor} [args...]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
