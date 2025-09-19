#!/bin/bash
# Setup script for optimized Llama 3.2 1B models
# Downloads and configures models with performance-optimized parameters

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
MODEL_SCRIPT="${SCRIPT_DIR}/src/model/model-manager.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[$timestamp] [INFO]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[$timestamp] [WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[$timestamp] [ERROR]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[$timestamp] [SUCCESS]${NC} $message" ;;
    esac
}

# Check if model manager script exists
if [[ ! -f "$MODEL_SCRIPT" ]]; then
    log "ERROR" "Model manager script not found at: $MODEL_SCRIPT"
    exit 1
fi

# Source the model manager script
source "$MODEL_SCRIPT"

# Models to setup
MODELS=("qwen2.5:3b-instruct" "llama3.2:1b")

log "INFO" "Starting optimized model setup for Qwen2.5 instruct and Llama3.2 base models"
log "INFO" "Models to setup: ${MODELS[*]}"

# Check Ollama connection
log "INFO" "Checking Ollama connection..."
if ! check_ollama_connection; then
    log "ERROR" "Cannot connect to Ollama. Please ensure Ollama is running."
    exit 1
fi
log "SUCCESS" "Ollama connection established"

# Download models
for model in "${MODELS[@]}"; do
    log "INFO" "Setting up model: $model"
    
    # Download model if it doesn't exist
    if ! model_exists "$model"; then
        log "INFO" "Downloading model: $model"
        if model_download "$model"; then
            log "SUCCESS" "Model '$model' downloaded successfully"
        else
            log "ERROR" "Failed to download model '$model'"
            exit 1
        fi
    else
        log "INFO" "Model '$model' already exists"
    fi
    
    # Validate model
    log "INFO" "Validating model: $model"
    if model_validate "$model"; then
        log "SUCCESS" "Model '$model' validation successful"
    else
        log "ERROR" "Model '$model' validation failed"
        exit 1
    fi
    
    # Preload model for better performance
    log "INFO" "Preloading model: $model"
    if model_preload "$model"; then
        log "SUCCESS" "Model '$model' preloaded successfully"
    else
        log "WARN" "Failed to preload model '$model' (non-critical)"
    fi
done

# Set default model
log "INFO" "Setting default model to: qwen2.5:3b-instruct"
if model_switch "qwen2.5:3b-instruct"; then
    log "SUCCESS" "Default model set to qwen2.5:3b-instruct"
else
    log "ERROR" "Failed to set default model"
    exit 1
fi

# Display optimization parameters
log "INFO" "Optimization parameters configured:"
log "INFO" "  - OLLAMA_NUM_THREADS: $OLLAMA_NUM_THREADS"
log "INFO" "  - OLLAMA_NGL: $OLLAMA_NGL (max Metal offload)"
log "INFO" "  - OLLAMA_QUANTIZATION: $OLLAMA_QUANTIZATION (speed > quality)"
log "INFO" "  - OLLAMA_NUM_CTX: $OLLAMA_NUM_CTX (context length)"
log "INFO" "  - OLLAMA_NUM_BATCH: $OLLAMA_NUM_BATCH (generation throughput)"
log "INFO" "  - OLLAMA_THREADS: $OLLAMA_THREADS (P-cores)"

# Test the optimized setup
log "INFO" "Testing optimized model setup..."
if model_health_check "qwen2.5:3b-instruct"; then
    log "SUCCESS" "Model health check passed"
else
    log "ERROR" "Model health check failed"
    exit 1
fi

log "SUCCESS" "Optimized model setup completed successfully!"
log "INFO" "You can now run models with optimized parameters using:"
log "INFO" "  ./src/model/model-manager.sh run-optimized qwen2.5:3b-instruct"
log "INFO" "  ./src/model/model-manager.sh run-optimized llama3.2:1b"

echo ""
echo "🚀 Setup Complete! Your optimized models are ready with high performance."
echo "   - Default model: qwen2.5:3b-instruct (3.2B parameters, instruct-tuned for MCP and tool calling)"
echo "   - Fallback model: llama3.2:1b (1.3B parameters, base model)"
echo "   - Optimized for speed with Metal GPU acceleration"
echo ""
