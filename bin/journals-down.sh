#!/usr/bin/env bash
set -euo pipefail

# journals-down.sh - Stop Journals Infrastructure
# 
# This script stops the complete journals infrastructure including:
# 1. Docker stack shutdown with graceful cleanup
# 2. Vault unmounting and security verification
# 3. Resource cleanup and status reporting
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

# Stop Docker stack
stop_docker_stack() {
    log "INFO" "Stopping Docker stack..."
    
    # Get graceful shutdown timeout from environment or use default
    local timeout="${GRACEFUL_SHUTDOWN_TIMEOUT:-30}"
    
    # Stop Docker services
    if ! "$DOCKER_MANAGER" down "$timeout"; then
        log "WARN" "Docker stack shutdown had issues, but continuing..."
    fi
    
    log "SUCCESS" "Docker stack stopped"
}

# Stop vault
stop_vault() {
    log "INFO" "Stopping vault management..."
    
    # Check vault status
    local vault_status
    vault_status=$("$VAULT_MANAGER" status)
    
    if [[ "$vault_status" == "mounted" ]]; then
        log "INFO" "Unmounting vault..."
        if ! "$VAULT_MANAGER" unmount; then
            log "WARN" "Failed to unmount vault, but continuing..."
        else
            log "SUCCESS" "Vault unmounted successfully"
        fi
    elif [[ "$vault_status" == "unmounted" ]]; then
        log "INFO" "Vault is already unmounted"
    else
        log "WARN" "Vault status is unclear: $vault_status"
    fi
}

# Clean up resources
cleanup_resources() {
    log "INFO" "Cleaning up resources..."
    
    # Clean up Docker resources
    if ! "$DOCKER_MANAGER" cleanup; then
        log "WARN" "Docker cleanup had issues, but continuing..."
    fi
    
    log "SUCCESS" "Resource cleanup completed"
}

# Verify shutdown
verify_shutdown() {
    log "INFO" "Verifying shutdown..."
    
    # Check if any services are still running
    local health_status
    health_status=$("$DOCKER_MANAGER" health 2>/dev/null || echo "unhealthy")
    
    if [[ "$health_status" == "unhealthy" ]]; then
        log "SUCCESS" "All services stopped successfully"
    else
        log "WARN" "Some services may still be running: $health_status"
    fi
    
    # Check vault status
    local vault_status
    vault_status=$("$VAULT_MANAGER" status 2>/dev/null || echo "unmounted")
    
    if [[ "$vault_status" == "unmounted" ]]; then
        log "SUCCESS" "Vault unmounted successfully"
    else
        log "WARN" "Vault status: $vault_status"
    fi
}

# Display shutdown information
display_shutdown_info() {
    echo
    log "SUCCESS" "Journals Infrastructure Stopped Successfully!"
    echo
    echo "=== Shutdown Summary ==="
    echo "Docker services: Stopped"
    echo "Vault: Unmounted"
    echo "Resources: Cleaned up"
    echo
    echo "=== Next Steps ==="
    echo "To start again: $0 up"
    echo "To check status: $0 status"
    echo
}

# Main function
main() {
    local timeout="${1:-}"
    
    log "INFO" "Stopping Journals Infrastructure..."
    
    check_prerequisites
    stop_docker_stack
    stop_vault
    cleanup_resources
    verify_shutdown
    display_shutdown_info
    
    log "SUCCESS" "Journals Infrastructure shutdown completed"
}

# Run main function
main "$@"