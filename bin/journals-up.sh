#!/usr/bin/env bash
set -euo pipefail

# journals-up.sh - Start Journals Infrastructure
# 
# This script starts the complete journals infrastructure including:
# 1. Vault mounting (interactive passphrase entry)
# 2. Docker stack startup with security validation
# 3. Model management and health verification
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly VAULT_MANAGER="$PROJECT_ROOT/src/vault/vault-manager.sh"
readonly DOCKER_MANAGER="$PROJECT_ROOT/src/docker/docker-manager.sh"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
    esac
}

# Error handling
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    log "ERROR" "$message"
    exit "$exit_code"
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if vault manager exists
    if [[ ! -f "$VAULT_MANAGER" ]]; then
        error_exit "Vault manager not found: $VAULT_MANAGER"
    fi
    
    # Check if docker manager exists
    if [[ ! -f "$DOCKER_MANAGER" ]]; then
        error_exit "Docker manager not found: $DOCKER_MANAGER"
    fi
    
    # Make sure scripts are executable
    chmod +x "$VAULT_MANAGER" "$DOCKER_MANAGER"
    
    log "SUCCESS" "Prerequisites check passed"
}

# Start vault
start_vault() {
    log "INFO" "Starting vault management..."
    
    # Check if vault exists
    if ! "$VAULT_MANAGER" exists; then
        log "INFO" "Vault does not exist. Creating new vault..."
        "$VAULT_MANAGER" create
    fi
    
    # Mount vault
    log "INFO" "Mounting vault..."
    "$VAULT_MANAGER" mount
    
    # Verify vault is mounted
    local vault_status
    vault_status=$("$VAULT_MANAGER" status)
    if [[ "$vault_status" != "mounted" ]]; then
        error_exit "Failed to mount vault. Status: $vault_status"
    fi
    
    log "SUCCESS" "Vault mounted successfully"
}

# Start Docker stack
start_docker_stack() {
    log "INFO" "Starting Docker stack..."
    
    # Start Docker services
    if ! "$DOCKER_MANAGER" up; then
        error_exit "Failed to start Docker stack"
    fi
    
    log "SUCCESS" "Docker stack started successfully"
}

# Manage AI models
manage_models() {
    log "INFO" "Managing AI models..."
    
    # Wait for Ollama to be ready
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
            break
        fi
        
        log "INFO" "Waiting for Ollama to be ready... (attempt $((attempt + 1))/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        log "WARN" "Ollama did not become ready in time, skipping model management"
        return 0
    fi
    
    # Check if default model exists
    local model_name="${OLLAMA_MODEL:-llama3.2:3b}"
    if ! curl -s "http://127.0.0.1:11434/api/tags" | grep -q "$model_name"; then
        log "INFO" "Pulling model: $model_name"
        if ! docker exec journals-ollama ollama pull "$model_name"; then
            log "WARN" "Failed to pull model: $model_name"
        else
            log "SUCCESS" "Model pulled successfully: $model_name"
        fi
    else
        log "INFO" "Model already exists: $model_name"
    fi
}

# Verify system health
verify_system_health() {
    log "INFO" "Verifying system health..."
    
    # Check Docker stack health
    local health_status
    health_status=$("$DOCKER_MANAGER" health)
    
    case "$health_status" in
        "healthy")
            log "SUCCESS" "All services are healthy"
            ;;
        "partially_healthy")
            log "WARN" "Some services are healthy, but not all"
            ;;
        "unhealthy")
            error_exit "Services are unhealthy"
            ;;
        *)
            error_exit "Unknown health status: $health_status"
            ;;
    esac
}

# Display system information
display_system_info() {
    echo
    log "SUCCESS" "Journals Infrastructure Started Successfully!"
    echo
    echo "=== Service URLs ==="
    echo "Open WebUI: http://127.0.0.1:3000"
    echo "Ollama API: http://127.0.0.1:11434"
    echo
    echo "=== Journal Access ==="
    echo "Your journals are mounted read-only at /journals inside WebUI"
    echo "Vault location: ${VAULT_MOUNT_POINT:-${HOME}/Journals}"
    echo
    echo "=== Management Commands ==="
    echo "Check status: $0 status"
    echo "Stop system: $0 down"
    echo "View logs: $0 logs [service]"
    echo
}

# Main function
main() {
    log "INFO" "Starting Journals Infrastructure..."
    
    check_prerequisites
    start_vault
    start_docker_stack
    manage_models
    verify_system_health
    display_system_info
    
    log "SUCCESS" "Journals Infrastructure startup completed"
}

# Run main function
main "$@"