#!/bin/bash

# Model Management Integration Script
# Provides integration points for automatic model management
# Used by Docker orchestration and session control scripts

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

# Integration Functions

# Initialize model management for startup
init_model_management() {
    local model_name="${1:-${DEFAULT_MODEL}}"
    
    log "INFO" "Initializing model management for: $model_name"
    
    # Check Ollama connection
    if ! check_ollama_connection; then
        log "ERROR" "Cannot connect to Ollama service"
        return 1
    fi
    
    # Ensure model is available
    if ! ensure_model_available "$model_name"; then
        log "ERROR" "Failed to ensure model availability"
        return 1
    fi
    
    # Validate model health
    if ! model_health_check "$model_name"; then
        log "WARN" "Model health check failed, but continuing"
    fi
    
    # Preload if enabled
    if [[ "${ENABLE_PRELOADING:-true}" == "true" ]]; then
        model_preload "$model_name" || log "WARN" "Model preloading failed"
    fi
    
    log "SUCCESS" "Model management initialized successfully"
    return 0
}

# Monitor and maintain model health
monitor_model_health() {
    local model_name="${1:-${DEFAULT_MODEL}}"
    local check_interval="${2:-300}"  # 5 minutes default
    
    log "INFO" "Starting model health monitoring for: $model_name"
    
    while true; do
        # Check model health
        if ! model_health_check "$model_name"; then
            log "WARN" "Model health check failed, attempting recovery"
            
            # Try to recover by ensuring model availability
            if ensure_model_available "$model_name"; then
                log "SUCCESS" "Model recovery successful"
            else
                log "ERROR" "Model recovery failed"
            fi
        fi
        
        # Monitor resources
        monitor_resources
        
        # Sleep before next check
        sleep "$check_interval"
    done
}

# Handle model switching with fallback
handle_model_switch() {
    local requested_model="$1"
    local current_model="${2:-${DEFAULT_MODEL}}"
    
    log "INFO" "Handling model switch request: $requested_model"
    
    # Check if requested model exists
    if model_exists "$requested_model"; then
        if model_switch "$requested_model"; then
            log "SUCCESS" "Switched to model: $requested_model"
            return 0
        else
            log "ERROR" "Failed to switch to model: $requested_model"
            return 1
        fi
    else
        log "WARN" "Requested model not found: $requested_model"
        
        # Try to download it
        if model_download "$requested_model"; then
            if model_switch "$requested_model"; then
                log "SUCCESS" "Downloaded and switched to model: $requested_model"
                return 0
            fi
        fi
        
        # Fall back to current model
        log "WARN" "Falling back to current model: $current_model"
        return 1
    fi
}

# Cleanup models on shutdown
cleanup_models() {
    log "INFO" "Cleaning up models on shutdown"
    
    # Unload all models to free memory
    local models
    models=$(model_list)
    
    if [[ -n "$models" ]]; then
        echo "$models" | while read -r model; do
            if [[ -n "$model" ]]; then
                model_unload "$model" || true
            fi
        done
    fi
    
    log "SUCCESS" "Model cleanup completed"
    return 0
}

# Get model status for reporting
get_model_status() {
    local model_name="${1:-${DEFAULT_MODEL}}"
    
    local status="unknown"
    local health="unknown"
    local memory_usage="unknown"
    
    # Check if model exists
    if model_exists "$model_name"; then
        status="available"
        
        # Check health
        if model_health_check "$model_name" >/dev/null 2>&1; then
            health="healthy"
        else
            health="unhealthy"
        fi
    else
        status="not_found"
        health="n/a"
    fi
    
    # Get memory usage
    memory_usage=$(get_memory_usage)
    
    # Return JSON status
    cat << EOF
{
    "model": "$model_name",
    "status": "$status",
    "health": "$health",
    "memory_usage_gb": "$memory_usage",
    "ollama_connected": $(check_ollama_connection && echo "true" || echo "false")
}
EOF
}

# Performance optimization
optimize_performance() {
    local model_name="${1:-${DEFAULT_MODEL}}"
    
    log "INFO" "Optimizing performance for model: $model_name"
    
    # Ensure model is available
    if ! ensure_model_available "$model_name"; then
        log "ERROR" "Cannot optimize performance - model not available"
        return 1
    fi
    
    # Preload model
    if [[ "${ENABLE_PRELOADING:-true}" == "true" ]]; then
        model_preload "$model_name" || log "WARN" "Model preloading failed"
    fi
    
    # Monitor and cleanup if needed
    monitor_resources
    
    log "SUCCESS" "Performance optimization completed"
    return 0
}

# Main execution
main() {
    local command="$1"
    shift
    
    case "$command" in
        "init")
            init_model_management "$@"
            ;;
        "monitor")
            monitor_model_health "$@"
            ;;
        "switch")
            handle_model_switch "$@"
            ;;
        "cleanup")
            cleanup_models
            ;;
        "status")
            get_model_status "$@"
            ;;
        "optimize")
            optimize_performance "$@"
            ;;
        *)
            echo "Usage: $0 {init|monitor|switch|cleanup|status|optimize} [args...]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
