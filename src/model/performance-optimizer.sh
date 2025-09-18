#!/bin/bash

# Performance Optimizer for Model Management
# Implements advanced performance optimization features
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

# Performance Configuration
readonly CACHE_DIR="${MODEL_CACHE_DIR:-${PROJECT_ROOT}/.model-cache}"
readonly PERFORMANCE_LOG="${CACHE_DIR}/performance.log"
readonly METRICS_FILE="${CACHE_DIR}/metrics.json"

# Create cache directory
mkdir -p "$CACHE_DIR"

# Logging functions
perf_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [PERF-$level] $message" >> "$PERFORMANCE_LOG"
    log "$level" "$message"
}

# Performance Metrics Collection

collect_metrics() {
    local model_name="$1"
    local operation="$2"
    local start_time="$3"
    local end_time="$4"
    
    local duration=$((end_time - start_time))
    local memory_usage
    memory_usage=$(get_memory_usage)
    
    # Create metrics entry
    local metrics_entry=$(cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "model": "$model_name",
    "operation": "$operation",
    "duration_seconds": $duration,
    "memory_usage_gb": $memory_usage,
    "success": true
}
EOF
)
    
    # Append to metrics file
    if [[ -f "$METRICS_FILE" ]]; then
        # Add comma and new entry
        echo "," >> "$METRICS_FILE"
        echo "$metrics_entry" >> "$METRICS_FILE"
    else
        # Create new file with array start
        echo "[$metrics_entry" > "$METRICS_FILE"
    fi
    
    perf_log "INFO" "Metrics collected: $operation for $model_name took ${duration}s"
}

# Smart Model Preloading

smart_preload() {
    local model_name="$1"
    local priority="${2:-normal}"
    
    perf_log "INFO" "Starting smart preload for $model_name (priority: $priority)"
    
    local start_time
    start_time=$(date +%s)
    
    # Check if model is already loaded
    if model_exists "$model_name"; then
        # Test if model is responsive
        if model_validate "$model_name" >/dev/null 2>&1; then
            perf_log "INFO" "Model $model_name is already loaded and responsive"
            return 0
        fi
    fi
    
    # Preload based on priority
    case "$priority" in
        "high")
            # Immediate preload with full validation
            if model_preload "$model_name"; then
                local end_time
                end_time=$(date +%s)
                collect_metrics "$model_name" "preload_high" "$start_time" "$end_time"
                return 0
            fi
            ;;
        "normal")
            # Background preload
            (
                if model_preload "$model_name"; then
                    local end_time
                    end_time=$(date +%s)
                    collect_metrics "$model_name" "preload_normal" "$start_time" "$end_time"
                fi
            ) &
            return 0
            ;;
        "low")
            # Deferred preload
            (
                sleep 30  # Wait 30 seconds
                if model_preload "$model_name"; then
                    local end_time
                    end_time=$(date +%s)
                    collect_metrics "$model_name" "preload_low" "$start_time" "$end_time"
                fi
            ) &
            return 0
            ;;
    esac
    
    return 1
}

# Memory Management

advanced_memory_management() {
    local target_memory_gb="${1:-3.5}"
    
    perf_log "INFO" "Starting advanced memory management (target: ${target_memory_gb}GB)"
    
    local current_memory
    current_memory=$(get_memory_usage)
    
    if (( $(echo "$current_memory <= $target_memory_gb" | bc -l) )); then
        perf_log "INFO" "Memory usage is within target (${current_memory}GB <= ${target_memory_gb}GB)"
        return 0
    fi
    
    perf_log "WARN" "Memory usage exceeds target (${current_memory}GB > ${target_memory_gb}GB), starting cleanup"
    
    # Get model usage statistics
    local models
    models=$(model_list)
    
    if [[ -n "$models" ]]; then
        # Unload models in reverse order (least recently used)
        echo "$models" | tail -r | while read -r model; do
            if [[ -n "$model" ]]; then
                perf_log "INFO" "Unloading model: $model"
                model_unload "$model" || true
                
                # Check if we've reached target
                current_memory=$(get_memory_usage)
                if (( $(echo "$current_memory <= $target_memory_gb" | bc -l) )); then
                    perf_log "SUCCESS" "Memory target reached (${current_memory}GB <= ${target_memory_gb}GB)"
                    break
                fi
            fi
        done
    fi
    
    # Final memory check
    current_memory=$(get_memory_usage)
    perf_log "INFO" "Memory management completed (current: ${current_memory}GB)"
}

# Model Caching Strategy

implement_caching_strategy() {
    local model_name="$1"
    
    perf_log "INFO" "Implementing caching strategy for: $model_name"
    
    # Create model-specific cache directory
    local model_cache_dir="${CACHE_DIR}/${model_name//[^a-zA-Z0-9._-]/_}"
    mkdir -p "$model_cache_dir"
    
    # Check if model is already cached
    if [[ -f "${model_cache_dir}/cached" ]]; then
        local cache_time
        cache_time=$(stat -f "%m" "${model_cache_dir}/cached" 2>/dev/null || stat -c "%Y" "${model_cache_dir}/cached" 2>/dev/null || echo "0")
        local current_time
        current_time=$(date +%s)
        local cache_age=$((current_time - cache_time))
        
        # Cache is valid for 1 hour
        if [[ $cache_age -lt 3600 ]]; then
            perf_log "INFO" "Using cached model: $model_name (age: ${cache_age}s)"
            return 0
        else
            perf_log "INFO" "Cache expired for model: $model_name (age: ${cache_age}s)"
        fi
    fi
    
    # Cache the model
    if model_exists "$model_name"; then
        touch "${model_cache_dir}/cached"
        perf_log "SUCCESS" "Model cached: $model_name"
        return 0
    else
        perf_log "ERROR" "Cannot cache non-existent model: $model_name"
        return 1
    fi
}

# Performance Monitoring

start_performance_monitoring() {
    local check_interval="${1:-60}"  # 1 minute default
    
    perf_log "INFO" "Starting performance monitoring (interval: ${check_interval}s)"
    
    while true; do
        # Collect current metrics
        local memory_usage
        memory_usage=$(get_memory_usage)
        
        # Log performance metrics
        perf_log "DEBUG" "Performance check - Memory: ${memory_usage}GB"
        
        # Trigger cleanup if needed
        if (( $(echo "$memory_usage > ${CLEANUP_THRESHOLD_GB:-3.5}" | bc -l) )); then
            advanced_memory_management
        fi
        
        # Sleep before next check
        sleep "$check_interval"
    done
}

# Performance Analysis

analyze_performance() {
    local days="${1:-7}"
    
    perf_log "INFO" "Analyzing performance data for last $days days"
    
    if [[ ! -f "$METRICS_FILE" ]]; then
        perf_log "WARN" "No metrics file found: $METRICS_FILE"
        return 1
    fi
    
    # Complete the JSON array
    echo "]" >> "$METRICS_FILE"
    
    # Analyze metrics using jq
    local analysis
    analysis=$(jq -r --argjson days "$days" '
        map(select(.timestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime > (now - ($days * 24 * 60 * 60))))
        | {
            total_operations: length,
            avg_duration: (map(.duration_seconds) | add / length),
            max_duration: (map(.duration_seconds) | max),
            min_duration: (map(.duration_seconds) | min),
            avg_memory: (map(.memory_usage_gb) | add / length),
            max_memory: (map(.memory_usage_gb) | max),
            operations_by_model: group_by(.model) | map({model: .[0].model, count: length}),
            operations_by_type: group_by(.operation) | map({operation: .[0].operation, count: length})
        }
    ' "$METRICS_FILE" 2>/dev/null)
    
    if [[ -n "$analysis" ]]; then
        echo "$analysis" | jq '.'
        perf_log "SUCCESS" "Performance analysis completed"
    else
        perf_log "ERROR" "Failed to analyze performance data"
        return 1
    fi
}

# Resource Optimization

optimize_resources() {
    local model_name="$1"
    
    perf_log "INFO" "Optimizing resources for model: $model_name"
    
    # Ensure model is available
    if ! ensure_model_available "$model_name"; then
        perf_log "ERROR" "Cannot optimize resources - model not available"
        return 1
    fi
    
    # Implement caching strategy
    implement_caching_strategy "$model_name"
    
    # Smart preload
    smart_preload "$model_name" "normal"
    
    # Advanced memory management
    advanced_memory_management
    
    perf_log "SUCCESS" "Resource optimization completed for: $model_name"
    return 0
}

# Main execution
main() {
    local command="$1"
    shift
    
    case "$command" in
        "preload")
            smart_preload "$@"
            ;;
        "memory")
            advanced_memory_management "$@"
            ;;
        "cache")
            implement_caching_strategy "$@"
            ;;
        "monitor")
            start_performance_monitoring "$@"
            ;;
        "analyze")
            analyze_performance "$@"
            ;;
        "optimize")
            optimize_resources "$@"
            ;;
        *)
            echo "Usage: $0 {preload|memory|cache|monitor|analyze|optimize} [args...]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
