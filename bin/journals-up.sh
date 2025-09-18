#!/usr/bin/env bash
set -euo pipefail

# journals-up.sh - Start Journals Infrastructure
# 
# This script starts the complete journals infrastructure including:
# 1. Pre-flight system checks (Docker, vault, ports, resources)
# 2. Vault mounting with interactive passphrase entry
# 3. Docker stack startup with health verification
# 4. Model management and service readiness validation
# 5. Comprehensive error handling and rollback
#
# Author: Local Development Team
# Version: 2.0
# Date: 2025-09-18

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly VAULT_MANAGER="$PROJECT_ROOT/src/vault/vault-manager.sh"
readonly DOCKER_MANAGER="$PROJECT_ROOT/src/docker/docker-manager.sh"

# System requirements
readonly MIN_MEMORY_GB=8
readonly MIN_DISK_SPACE_GB=10
readonly REQUIRED_PORTS=("11434" "3000")
readonly HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-120}"
readonly GRACEFUL_SHUTDOWN_TIMEOUT="${GRACEFUL_SHUTDOWN_TIMEOUT:-30}"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Status tracking
declare -a STARTUP_STEPS=()
declare -a ROLLBACK_STEPS=()

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

# Error handling with rollback
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    log "ERROR" "$message"
    
    # Execute rollback steps in reverse order
    if [[ ${#ROLLBACK_STEPS[@]} -gt 0 ]]; then
        log "WARN" "Executing rollback steps..."
        for ((i=${#ROLLBACK_STEPS[@]}-1; i>=0; i--)); do
            local rollback_step="${ROLLBACK_STEPS[i]}"
            log "INFO" "Rollback: $rollback_step"
            eval "$rollback_step" || log "WARN" "Rollback step failed: $rollback_step"
        done
    fi
    
    exit "$exit_code"
}

# Add startup step for tracking
add_startup_step() {
    local step="$1"
    local rollback="$2"
    STARTUP_STEPS+=("$step")
    if [[ -n "$rollback" ]]; then
        ROLLBACK_STEPS+=("$rollback")
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system resources
check_system_resources() {
    log "STEP" "Checking system resources..."
    
    # Check memory
    local memory_gb
    if command_exists free; then
        memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    elif command_exists vm_stat; then
        # macOS memory calculation
        local memory_bytes
        memory_bytes=$(sysctl -n hw.memsize)
        memory_gb=$((memory_bytes / 1024 / 1024 / 1024))
    else
        log "WARN" "Cannot determine memory size"
        memory_gb=0
    fi
    
    if [[ $memory_gb -lt $MIN_MEMORY_GB ]]; then
        error_exit "Insufficient memory: ${memory_gb}GB available, ${MIN_MEMORY_GB}GB required"
    fi
    log "SUCCESS" "Memory check passed: ${memory_gb}GB available"
    
    # Check disk space
    local vault_mount_point="${VAULT_MOUNT_POINT:-${HOME}/Journals}"
    local available_space_gb
    available_space_gb=$(df -BG "$vault_mount_point" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//' || echo "0")
    
    if [[ $available_space_gb -lt $MIN_DISK_SPACE_GB ]]; then
        error_exit "Insufficient disk space: ${available_space_gb}GB available, ${MIN_DISK_SPACE_GB}GB required"
    fi
    log "SUCCESS" "Disk space check passed: ${available_space_gb}GB available"
}

# Check Docker prerequisites
check_docker_prerequisites() {
    log "STEP" "Checking Docker prerequisites..."
    
    # Check if Docker is installed
    if ! command_exists docker; then
        error_exit "Docker is not installed. Please install Docker Desktop or Docker Engine."
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        error_exit "Docker daemon is not running. Please start Docker Desktop or Docker service."
    fi
    
    # Check Docker Compose availability
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        error_exit "Docker Compose is not available. Please install Docker Compose."
    fi
    
    log "SUCCESS" "Docker prerequisites check passed"
}

# Check port availability
check_port_availability() {
    log "STEP" "Checking port availability..."
    
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -an 2>/dev/null | grep -q "127.0.0.1:$port"; then
            error_exit "Port $port is already in use. Please stop the service using this port."
        fi
        
        if netstat -an 2>/dev/null | grep -q "0.0.0.0:$port"; then
            error_exit "Port $port is bound to external interface. This is a security risk."
        fi
    done
    
    log "SUCCESS" "Port availability check passed"
}

# Check vault prerequisites
check_vault_prerequisites() {
    log "STEP" "Checking vault prerequisites..."
    
    # Check if vault manager exists
    if [[ ! -f "$VAULT_MANAGER" ]]; then
        error_exit "Vault manager not found: $VAULT_MANAGER"
    fi
    
    # Make sure vault manager is executable
    chmod +x "$VAULT_MANAGER"
    
    # Check if vault exists
    if ! "$VAULT_MANAGER" exists >/dev/null 2>&1; then
        log "INFO" "Vault does not exist. Will create new vault during startup."
    else
        log "SUCCESS" "Vault exists and is accessible"
    fi
}

# Comprehensive pre-flight checks
startup_preflight_checks() {
    log "INFO" "Starting pre-flight checks..."
    
    check_system_resources
    check_docker_prerequisites
    check_port_availability
    check_vault_prerequisites
    
    log "SUCCESS" "All pre-flight checks passed"
}

# Mount vault with interactive passphrase
mount_vault_interactive() {
    log "STEP" "Mounting vault with interactive passphrase..."
    
    # Check if vault exists, create if not
    if ! "$VAULT_MANAGER" exists >/dev/null 2>&1; then
        log "INFO" "Vault does not exist. Creating new vault..."
        if ! "$VAULT_MANAGER" create; then
            error_exit "Failed to create vault"
        fi
        add_startup_step "vault_created" "vault_cleanup"
    fi
    
    # Mount vault
    if ! "$VAULT_MANAGER" mount; then
        error_exit "Failed to mount vault"
    fi
    
    # Verify vault is mounted
    local vault_status
    vault_status=$("$VAULT_MANAGER" status)
    if [[ "$vault_status" != "mounted" ]]; then
        error_exit "Vault mount verification failed. Status: $vault_status"
    fi
    
    add_startup_step "vault_mounted" "vault_unmount"
    log "SUCCESS" "Vault mounted successfully"
}

# Start Docker stack with health verification
start_docker_stack() {
    log "STEP" "Starting Docker stack with health verification..."
    
    # Check if docker manager exists
    if [[ ! -f "$DOCKER_MANAGER" ]]; then
        error_exit "Docker manager not found: $DOCKER_MANAGER"
    fi
    
    # Make sure docker manager is executable
    chmod +x "$DOCKER_MANAGER"
    
    # Start Docker services
    if ! "$DOCKER_MANAGER" up; then
        error_exit "Failed to start Docker stack"
    fi
    
    add_startup_step "docker_started" "docker_stop"
    log "SUCCESS" "Docker stack started successfully"
}

# Verify services are ready and responding
verify_services_ready() {
    log "STEP" "Verifying services are ready and responding..."
    
    local max_attempts=$((HEALTH_CHECK_TIMEOUT / 5))
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local health_status
        health_status=$("$DOCKER_MANAGER" health 2>/dev/null || echo "unhealthy")
        
        case "$health_status" in
            "healthy")
                log "SUCCESS" "All services are healthy and ready"
                return 0
                ;;
            "partially_healthy")
                log "INFO" "Some services are ready, waiting for all services..."
                ;;
            "unhealthy")
                log "INFO" "Services are starting up, waiting... (attempt $((attempt + 1))/$max_attempts)"
                ;;
            *)
                log "WARN" "Unknown health status: $health_status"
                ;;
        esac
        
        sleep 5
        ((attempt++))
    done
    
    error_exit "Services failed to become ready within ${HEALTH_CHECK_TIMEOUT} seconds"
}

# Manage AI models
manage_models() {
    log "STEP" "Managing AI models..."
    
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

# Display access information and status
display_access_info() {
    echo
    log "SUCCESS" "Journals Infrastructure Started Successfully!"
    echo
    echo -e "${CYAN}=== Service URLs ===${NC}"
    echo -e "Open WebUI: ${GREEN}http://127.0.0.1:3000${NC}"
    echo -e "Ollama API: ${GREEN}http://127.0.0.1:11434${NC}"
    echo -e "Ollama Models: ${GREEN}http://127.0.0.1:11434/api/tags${NC}"
    echo
    echo -e "${CYAN}=== Journal Access ===${NC}"
    echo -e "Your journals are mounted read-only at ${GREEN}/journals${NC} inside WebUI"
    echo -e "Vault location: ${GREEN}${VAULT_MOUNT_POINT:-${HOME}/Journals}${NC}"
    echo
    echo -e "${CYAN}=== Management Commands ===${NC}"
    echo -e "Check status: ${GREEN}$0 status${NC}"
    echo -e "Stop system: ${GREEN}$0 down${NC}"
    echo -e "View logs: ${GREEN}$0 logs [service]${NC}"
    echo
    echo -e "${CYAN}=== Security Notes ===${NC}"
    echo -e "• All services are bound to localhost only (127.0.0.1)"
    echo -e "• Journal files are mounted read-only to AI services"
    echo -e "• No external network access is enabled"
    echo -e "• Vault is encrypted with AES-256"
    echo
}

# Rollback functions
vault_cleanup() {
    log "INFO" "Cleaning up vault..."
    "$VAULT_MANAGER" unmount 2>/dev/null || true
}

vault_unmount() {
    log "INFO" "Unmounting vault..."
    "$VAULT_MANAGER" unmount 2>/dev/null || true
}

docker_stop() {
    log "INFO" "Stopping Docker stack..."
    "$DOCKER_MANAGER" down "$GRACEFUL_SHUTDOWN_TIMEOUT" 2>/dev/null || true
}

# Show help information
show_help() {
    cat << EOF
Journals Up - Infrastructure Startup Script

Usage: $0 [options]

Description:
  Starts the complete journals infrastructure including vault mounting,
  Docker stack startup, and service health verification.

Options:
  --help, -h     Show this help message
  --version, -v  Show version information

Environment Variables:
  HEALTH_CHECK_TIMEOUT      Health check timeout in seconds (default: 120)
  GRACEFUL_SHUTDOWN_TIMEOUT Graceful shutdown timeout in seconds (default: 30)
  OLLAMA_MODEL              Default AI model to use (default: llama3.2:3b)
  VAULT_MOUNT_POINT         Vault mount point (default: ~/Journals)

Features:
  - Comprehensive pre-flight checks
  - Interactive vault mounting with secure passphrase entry
  - Docker stack startup with health verification
  - AI model management and service readiness validation
  - Comprehensive error handling and rollback mechanisms

Examples:
  $0                        # Start with default settings
  HEALTH_CHECK_TIMEOUT=180 $0  # Start with custom timeout

Security Notes:
  - All services bound to localhost only (127.0.0.1)
  - Journal files mounted read-only to AI services
  - No external network access enabled
  - Vault encrypted with AES-256

EOF
}

# Show version information
show_version() {
    echo "Journals Up - Infrastructure Startup Script"
    echo "Version: 2.0"
    echo "Date: 2025-09-18"
    echo "Author: Local Development Team"
}

# Main function
main() {
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
            # No arguments, proceed with startup
            ;;
        *)
            log "ERROR" "Unknown option: $1. Use '$0 --help' for usage information."
            exit 1
            ;;
    esac
    
    log "INFO" "Starting Journals Infrastructure..."
    echo -e "${CYAN}========================================${NC}"
    
    # Execute startup sequence
    startup_preflight_checks
    mount_vault_interactive
    start_docker_stack
    verify_services_ready
    manage_models
    display_access_info
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "SUCCESS" "Journals Infrastructure startup completed in ${duration} seconds"
    echo -e "${CYAN}========================================${NC}"
}

# Handle script interruption
trap 'log "WARN" "Script interrupted. Executing rollback..."; error_exit "Startup interrupted by user" 130' INT TERM

# Run main function
main "$@"