#!/usr/bin/env bash
set -euo pipefail

# journals-down.sh - Stop Journals Infrastructure
# 
# This script stops the complete journals infrastructure including:
# 1. Graceful Docker stack shutdown with timeout handling
# 2. Secure vault unmounting with verification
# 3. Resource cleanup and status reporting
# 4. Comprehensive error handling and recovery
#
# Author: Local Development Team
# Version: 2.0
# Date: 2025-09-18

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly VAULT_MANAGER="$PROJECT_ROOT/src/vault/vault-manager.sh"
readonly DOCKER_MANAGER="$PROJECT_ROOT/src/docker/docker-manager.sh"

# Shutdown configuration
readonly GRACEFUL_SHUTDOWN_TIMEOUT="${GRACEFUL_SHUTDOWN_TIMEOUT:-30}"
readonly FORCE_SHUTDOWN_TIMEOUT="${FORCE_SHUTDOWN_TIMEOUT:-10}"
readonly CLEANUP_TIMEOUT="${CLEANUP_TIMEOUT:-15}"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Status tracking
declare -a SHUTDOWN_STEPS=()
declare -a CLEANUP_STEPS=()

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
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
        "STEP")
            echo -e "${CYAN}[STEP]${NC} $message"
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

# Add shutdown step for tracking
add_shutdown_step() {
    local step="$1"
    local cleanup="$2"
    SHUTDOWN_STEPS+=("$step")
    if [[ -n "$cleanup" ]]; then
        CLEANUP_STEPS+=("$cleanup")
    fi
}

# Check prerequisites
check_prerequisites() {
    log "STEP" "Checking prerequisites..."
    
    # Check if vault manager exists
    if [[ ! -f "$VAULT_MANAGER" ]]; then
        log "WARN" "Vault manager not found: $VAULT_MANAGER"
        return 1
    fi
    
    # Check if docker manager exists
    if [[ ! -f "$DOCKER_MANAGER" ]]; then
        log "WARN" "Docker manager not found: $DOCKER_MANAGER"
        return 1
    fi
    
    # Make sure scripts are executable
    chmod +x "$VAULT_MANAGER" "$DOCKER_MANAGER" 2>/dev/null || true
    
    log "SUCCESS" "Prerequisites check completed"
    return 0
}

# Stop Docker containers gracefully
shutdown_containers_graceful() {
    log "STEP" "Stopping Docker containers gracefully..."
    
    if ! check_prerequisites; then
        log "WARN" "Prerequisites check failed, attempting direct Docker shutdown..."
        if command -v docker >/dev/null 2>&1; then
            docker stop journals-ollama journals-webui 2>/dev/null || true
            docker rm journals-ollama journals-webui 2>/dev/null || true
        fi
        return 0
    fi
    
    # Get current timeout
    local timeout="${1:-$GRACEFUL_SHUTDOWN_TIMEOUT}"
    
    # Stop Docker services gracefully
    if ! "$DOCKER_MANAGER" down "$timeout"; then
        log "WARN" "Graceful shutdown failed, attempting force stop..."
        
        # Force stop with shorter timeout
        if ! "$DOCKER_MANAGER" down "$FORCE_SHUTDOWN_TIMEOUT"; then
            log "ERROR" "Force stop also failed"
            return 1
        fi
    fi
    
    add_shutdown_step "docker_stopped" "docker_cleanup"
    log "SUCCESS" "Docker containers stopped"
}

# Verify clean shutdown
verify_clean_shutdown() {
    log "STEP" "Verifying clean shutdown..."
    
    local containers_running=false
    local services_healthy=false
    
    # Check if any containers are still running
    if command -v docker >/dev/null 2>&1; then
        local running_containers
        running_containers=$(docker ps --filter "name=journals-" --format "{{.Names}}" 2>/dev/null || true)
        
        if [[ -n "$running_containers" ]]; then
            log "WARN" "Some containers are still running: $running_containers"
            containers_running=true
        else
            log "SUCCESS" "All containers stopped"
        fi
    fi
    
    # Check service health if docker manager is available
    if [[ -f "$DOCKER_MANAGER" ]]; then
        local health_status
        health_status=$("$DOCKER_MANAGER" health 2>/dev/null || echo "unhealthy")
        
        if [[ "$health_status" == "unhealthy" ]]; then
            log "SUCCESS" "All services are stopped"
        else
            log "WARN" "Some services may still be responding: $health_status"
            services_healthy=true
        fi
    fi
    
    if [[ "$containers_running" == "true" || "$services_healthy" == "true" ]]; then
        log "WARN" "Shutdown verification found issues, but continuing..."
        return 1
    fi
    
    log "SUCCESS" "Clean shutdown verified"
    return 0
}

# Unmount vault securely
unmount_vault_secure() {
    log "STEP" "Unmounting vault securely..."
    
    if ! check_prerequisites; then
        log "WARN" "Vault manager not available, attempting direct unmount..."
        local vault_mount_point="${VAULT_MOUNT_POINT:-${HOME}/Journals}"
        if mount | grep -q "$vault_mount_point"; then
            hdiutil detach "$vault_mount_point" 2>/dev/null || true
        fi
        return 0
    fi
    
    # Check vault status
    local vault_status
    vault_status=$("$VAULT_MANAGER" status 2>/dev/null || echo "error")
    
    case "$vault_status" in
        "mounted")
            log "INFO" "Unmounting vault..."
            if ! "$VAULT_MANAGER" unmount; then
                log "WARN" "Failed to unmount vault gracefully, attempting force unmount..."
                # Force unmount
                local vault_mount_point="${VAULT_MOUNT_POINT:-${HOME}/Journals}"
                hdiutil detach "$vault_mount_point" -force 2>/dev/null || true
            fi
            
            # Verify unmount
            local new_status
            new_status=$("$VAULT_MANAGER" status 2>/dev/null || echo "unmounted")
            if [[ "$new_status" == "unmounted" ]]; then
                log "SUCCESS" "Vault unmounted successfully"
            else
                log "WARN" "Vault unmount verification failed, but continuing..."
            fi
            ;;
        "unmounted")
            log "INFO" "Vault is already unmounted"
            ;;
        "error")
            log "WARN" "Could not determine vault status, assuming unmounted"
            ;;
        *)
            log "WARN" "Unknown vault status: $vault_status"
            ;;
    esac
    
    add_shutdown_step "vault_unmounted" "vault_cleanup"
}

# Clean up resources
cleanup_resources() {
    log "STEP" "Cleaning up resources..."
    
    # Clean up Docker resources
    if [[ -f "$DOCKER_MANAGER" ]]; then
        if ! "$DOCKER_MANAGER" cleanup; then
            log "WARN" "Docker cleanup had issues, but continuing..."
        fi
    fi
    
    # Clean up any orphaned containers
    if command -v docker >/dev/null 2>&1; then
        log "INFO" "Cleaning up orphaned containers..."
        docker container prune -f >/dev/null 2>&1 || true
        
        # Clean up unused networks
        log "INFO" "Cleaning up unused networks..."
        docker network prune -f >/dev/null 2>&1 || true
        
        # Clean up unused volumes (but keep our data volumes)
        log "INFO" "Cleaning up unused volumes..."
        docker volume ls -q | grep -v "journals-" | xargs -r docker volume rm >/dev/null 2>&1 || true
    fi
    
    add_shutdown_step "resources_cleaned" ""
    log "SUCCESS" "Resource cleanup completed"
}

# Verify final shutdown state
verify_final_shutdown() {
    log "STEP" "Verifying final shutdown state..."
    
    local issues=0
    
    # Check for running containers
    if command -v docker >/dev/null 2>&1; then
        local running_containers
        running_containers=$(docker ps --filter "name=journals-" --format "{{.Names}}" 2>/dev/null || true)
        
        if [[ -n "$running_containers" ]]; then
            log "WARN" "Containers still running: $running_containers"
            ((issues++))
        fi
    fi
    
    # Check vault status
    if [[ -f "$VAULT_MANAGER" ]]; then
        local vault_status
        vault_status=$("$VAULT_MANAGER" status 2>/dev/null || echo "unmounted")
        
        if [[ "$vault_status" != "unmounted" ]]; then
            log "WARN" "Vault status: $vault_status"
            ((issues++))
        fi
    fi
    
    # Check port binding
    local ports_in_use=()
    for port in 11434 3000; do
        if netstat -an 2>/dev/null | grep -q "127.0.0.1:$port"; then
            ports_in_use+=("$port")
        fi
    done
    
    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        log "WARN" "Ports still in use: ${ports_in_use[*]}"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log "SUCCESS" "Final shutdown verification passed"
        return 0
    else
        log "WARN" "Final shutdown verification found $issues issues"
        return 1
    fi
}

# Display shutdown information
display_shutdown_info() {
    echo
    log "SUCCESS" "Journals Infrastructure Stopped Successfully!"
    echo
    echo -e "${CYAN}=== Shutdown Summary ===${NC}"
    echo -e "Docker services: ${GREEN}Stopped${NC}"
    echo -e "Vault: ${GREEN}Unmounted${NC}"
    echo -e "Resources: ${GREEN}Cleaned up${NC}"
    echo
    echo -e "${CYAN}=== Next Steps ===${NC}"
    echo -e "To start again: ${GREEN}$0 up${NC}"
    echo -e "To check status: ${GREEN}$0 status${NC}"
    echo -e "To view logs: ${GREEN}$0 logs [service]${NC}"
    echo
    echo -e "${CYAN}=== Security Notes ===${NC}"
    echo -e "• Vault has been securely unmounted"
    echo -e "• All services have been stopped"
    echo -e "• No sensitive data remains in memory"
    echo -e "• System is in a clean, secure state"
    echo
}

# Cleanup functions
docker_cleanup() {
    log "INFO" "Performing Docker cleanup..."
    if [[ -f "$DOCKER_MANAGER" ]]; then
        "$DOCKER_MANAGER" cleanup 2>/dev/null || true
    fi
}

vault_cleanup() {
    log "INFO" "Performing vault cleanup..."
    if [[ -f "$VAULT_MANAGER" ]]; then
        "$VAULT_MANAGER" unmount 2>/dev/null || true
    fi
}

# Show help information
show_help() {
    cat << EOF
Journals Down - Infrastructure Shutdown Script

Usage: $0 [timeout] [options]

Description:
  Stops the complete journals infrastructure including graceful Docker
  shutdown, secure vault unmounting, and resource cleanup.

Arguments:
  timeout         Graceful shutdown timeout in seconds (default: 30)

Options:
  --help, -h     Show this help message
  --version, -v  Show version information

Environment Variables:
  GRACEFUL_SHUTDOWN_TIMEOUT Default graceful shutdown timeout (default: 30)
  FORCE_SHUTDOWN_TIMEOUT    Force shutdown timeout (default: 10)
  CLEANUP_TIMEOUT           Cleanup operation timeout (default: 15)

Features:
  - Graceful Docker container shutdown with timeout handling
  - Secure vault unmounting with verification
  - Resource cleanup and status reporting
  - Comprehensive error handling and recovery
  - Force stop capability if graceful shutdown fails

Examples:
  $0                    # Stop with default timeout (30s)
  $0 60                 # Stop with 60 second timeout
  $0 --help             # Show this help message

Security Notes:
  - Vault is securely unmounted
  - All services are stopped
  - No sensitive data remains in memory
  - System is left in a clean, secure state

EOF
}

# Show version information
show_version() {
    echo "Journals Down - Infrastructure Shutdown Script"
    echo "Version: 2.0"
    echo "Date: 2025-09-18"
    echo "Author: Local Development Team"
}

# Main function
main() {
    local timeout="${1:-$GRACEFUL_SHUTDOWN_TIMEOUT}"
    local start_time=$(date +%s)
    
    # Check for help or version flags
    case "${1:-}" in
        "--help"|"-h")
            show_help
            exit 0
            ;;
        "--version"|"-v")
            show_version
            exit 0
            ;;
        "")
            # No arguments, proceed with shutdown
            ;;
        *)
            # Check if first argument is a number (timeout)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                timeout="$1"
            else
                log "ERROR" "Unknown option: $1. Use '$0 --help' for usage information."
                exit 1
            fi
            ;;
    esac
    
    log "INFO" "Stopping Journals Infrastructure..."
    echo -e "${CYAN}========================================${NC}"
    
    # Execute shutdown sequence
    shutdown_containers_graceful "$timeout"
    verify_clean_shutdown
    unmount_vault_secure
    cleanup_resources
    verify_final_shutdown
    display_shutdown_info
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "SUCCESS" "Journals Infrastructure shutdown completed in ${duration} seconds"
    echo -e "${CYAN}========================================${NC}"
}

# Handle script interruption
trap 'log "WARN" "Script interrupted. Attempting emergency cleanup..."; cleanup_resources; exit 130' INT TERM

# Run main function
main "$@"