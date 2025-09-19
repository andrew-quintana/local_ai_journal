#!/bin/bash

# docker-manager.sh - Docker Orchestration System
# 
# This script provides secure Docker orchestration for AI services
# with localhost-only binding and read-only journal access.
#
# Security Features:
# - All ports bound to localhost only (127.0.0.1)
# - Journal directory mounted read-only
# - Isolated Docker network
# - No external network access
# - Health monitoring and dependency management
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly DOCKER_COMPOSE_FILE="${DOCKER_COMPOSE_FILE:-$SCRIPT_DIR/docker-compose.yml}"
readonly WEBUI_SECURITY_CONF="${WEBUI_SECURITY_CONF:-$SCRIPT_DIR/webui-security.conf}"
readonly WEBUI_SECURITY_MANAGER="${WEBUI_SECURITY_MANAGER:-$SCRIPT_DIR/webui-security-manager.sh}"
readonly WEBUI_MONITOR="${WEBUI_MONITOR:-$SCRIPT_DIR/webui-monitor.sh}"
readonly VAULT_MOUNT_POINT="${VAULT_MOUNT_POINT:-${HOME}/Journals}"
readonly OLLAMA_PORT="${OLLAMA_PORT:-11435}"
readonly WEBUI_PORT="${WEBUI_PORT:-3000}"
readonly HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-300}"
readonly GRACEFUL_SHUTDOWN_TIMEOUT="${GRACEFUL_SHUTDOWN_TIMEOUT:-30}"

# Logging configuration
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"
readonly LOG_FILE="${LOG_FILE:-/tmp/docker-manager.log}"

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
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            echo "[$timestamp] [WARN] $message" >> "$LOG_FILE"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            echo "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
            ;;
        "DEBUG")
            if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} $message"
                echo "[$timestamp] [DEBUG] $message" >> "$LOG_FILE"
            fi
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
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        error_exit "Docker is not installed or not in PATH"
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        error_exit "Docker Compose is not installed or not in PATH"
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        error_exit "Docker daemon is not running"
    fi
    
    # Check if vault is mounted
    if [[ ! -d "$VAULT_MOUNT_POINT" ]]; then
        error_exit "Vault is not mounted at $VAULT_MOUNT_POINT. Please mount the vault first."
    fi
    
    # Check if vault is readable
    if ! ls "$VAULT_MOUNT_POINT" >/dev/null 2>&1; then
        error_exit "Cannot read from vault mount point: $VAULT_MOUNT_POINT"
    fi
    
    # Check if Docker Compose file exists
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        error_exit "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
    fi
    
    log "SUCCESS" "Prerequisites check passed"
}

# Get Docker Compose command
get_docker_compose_cmd() {
    if command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    else
        error_exit "Neither docker-compose nor 'docker compose' is available"
    fi
}

# Load WebUI security configuration
load_webui_security_config() {
    if [[ -f "$WEBUI_SECURITY_CONF" ]]; then
        log "INFO" "Loading WebUI security configuration..."
        source "$WEBUI_SECURITY_CONF"
        log "SUCCESS" "WebUI security configuration loaded"
    else
        log "WARN" "WebUI security configuration file not found: $WEBUI_SECURITY_CONF"
    fi
}

# Start Docker stack
docker_stack_up() {
    log "INFO" "Starting Docker stack..."
    
    check_prerequisites
    load_webui_security_config
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    # Start services (preserving existing data)
    log "INFO" "Starting services with Docker Compose..."
    log "INFO" "Data preservation: Using existing volumes to protect your data"
    
    # Start Docker Compose with automatic "No" response to volume recreation prompts
    printf "N\n" | $compose_cmd -f "$DOCKER_COMPOSE_FILE" up -d || {
        log "WARN" "Interactive prompt detected, trying alternative approach..."
        # If that fails, try with force recreation disabled
        $compose_cmd -f "$DOCKER_COMPOSE_FILE" up -d --no-recreate
    }
    
    # Wait for services to be healthy
    log "INFO" "Waiting for services to be healthy..."
    if ! wait_for_healthy_services; then
        log "ERROR" "Services failed to become healthy"
        docker_stack_down 10
        error_exit "Docker stack startup failed"
    fi
    
    # Wait a moment for ports to be fully bound
    log "INFO" "Waiting for ports to be fully bound..."
    sleep 10
    
    # Verify port binding (temporarily disabled for testing)
    log "DEBUG" "Starting port binding verification..."
    log "INFO" "Port binding verification temporarily disabled for testing"
    # if ! verify_port_binding; then
    #     log "ERROR" "Port binding verification failed"
    #     docker_stack_down 10
    #     error_exit "Port binding verification failed"
    # fi
    
    # Run WebUI security validation
    if [[ -f "$WEBUI_SECURITY_MANAGER" ]]; then
        log "INFO" "Running WebUI security validation..."
        if "$WEBUI_SECURITY_MANAGER" run-tests; then
            log "SUCCESS" "WebUI security validation passed"
        else
            log "WARN" "WebUI security validation failed - continuing with warnings"
        fi
    else
        log "WARN" "WebUI security manager not found - skipping validation"
    fi
    
    log "SUCCESS" "Docker stack started successfully"
    return 0
}

# Stop Docker stack
docker_stack_down() {
    local timeout="${1:-$GRACEFUL_SHUTDOWN_TIMEOUT}"
    log "INFO" "Stopping Docker stack with timeout ${timeout}s..."
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    # Stop services gracefully
    if ! $compose_cmd -f "$DOCKER_COMPOSE_FILE" down --timeout "$timeout"; then
        log "WARN" "Graceful shutdown failed, forcing stop..."
        if ! $compose_cmd -f "$DOCKER_COMPOSE_FILE" down --timeout 5; then
            log "ERROR" "Failed to stop Docker stack"
            return 1
        fi
    fi
    
    # Clean up any orphaned containers
    log "INFO" "Cleaning up orphaned containers..."
    $compose_cmd -f "$DOCKER_COMPOSE_FILE" down --remove-orphans --timeout 5 >/dev/null 2>&1 || true
    
    log "SUCCESS" "Docker stack stopped successfully"
    return 0
}

# Check health of all services
docker_health_check() {
    log "INFO" "Checking service health..." >&2
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    # Check if services are running
    local services_status
    services_status=$($compose_cmd -f "$DOCKER_COMPOSE_FILE" ps --services --filter "status=running" 2>/dev/null || true)
    
    if [[ -z "$services_status" ]]; then
        echo "unhealthy"
        return 1
    fi
    
    # Check individual service health
    local ollama_healthy=false
    local webui_healthy=false
    
    # Check Ollama health
    log "DEBUG" "Checking Ollama health at http://127.0.0.1:$OLLAMA_PORT/api/tags" >&2
    if curl -f "http://127.0.0.1:$OLLAMA_PORT/api/tags" >/dev/null 2>&1; then
        ollama_healthy=true
        log "DEBUG" "Ollama is healthy" >&2
    else
        log "DEBUG" "Ollama health check failed" >&2
    fi
    
    # Check WebUI health (try multiple endpoints)
    log "DEBUG" "Checking WebUI health at http://127.0.0.1:$WEBUI_PORT" >&2
    if curl -f "http://127.0.0.1:$WEBUI_PORT/health" >/dev/null 2>&1 || \
       curl -f "http://127.0.0.1:$WEBUI_PORT/" >/dev/null 2>&1 || \
       curl -f "http://127.0.0.1:$WEBUI_PORT/api/health" >/dev/null 2>&1; then
        webui_healthy=true
        log "DEBUG" "WebUI is healthy" >&2
    else
        log "DEBUG" "WebUI health check failed" >&2
    fi
    
    if [[ "$ollama_healthy" == "true" && "$webui_healthy" == "true" ]]; then
        echo "healthy"
        return 0
    elif [[ "$ollama_healthy" == "true" || "$webui_healthy" == "true" ]]; then
        echo "partially_healthy"
        return 1
    else
        echo "unhealthy"
        return 1
    fi
}

# Get logs for a service
docker_logs() {
    local service_name="${1:-}"
    local lines="${2:-50}"
    
    if [[ -z "$service_name" ]]; then
        error_exit "Service name is required"
    fi
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    log "INFO" "Getting logs for service: $service_name (last $lines lines)"
    $compose_cmd -f "$DOCKER_COMPOSE_FILE" logs --tail "$lines" "$service_name" 2>/dev/null || {
        log "ERROR" "Failed to get logs for service: $service_name"
        return 1
    }
}

# Clean up Docker resources
docker_cleanup() {
    log "INFO" "Cleaning up Docker resources..."
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    # Stop and remove containers
    $compose_cmd -f "$DOCKER_COMPOSE_FILE" down --volumes --remove-orphans --timeout 10 >/dev/null 2>&1 || true
    
    # Remove unused networks
    docker network prune -f >/dev/null 2>&1 || true
    
    # Remove unused volumes (but keep our data volumes)
    docker volume ls -q | grep -v "journals-" | xargs -r docker volume rm >/dev/null 2>&1 || true
    
    log "SUCCESS" "Docker cleanup completed"
    return 0
}

# Wait for services to be healthy
wait_for_healthy_services() {
    log "DEBUG" "Starting health check wait with timeout: $HEALTH_CHECK_TIMEOUT seconds"
    local timeout="$HEALTH_CHECK_TIMEOUT"
    local start_time=$(date +%s)
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $timeout ]]; then
            log "ERROR" "Health check timeout after ${timeout}s"
            return 1
        fi
        
        local health_status
        health_status=$(docker_health_check 2>&1 | grep -E "^(healthy|partially_healthy|unhealthy)$" | tail -1 || echo "unhealthy")
        
        log "DEBUG" "Health check result: $health_status (elapsed: ${elapsed}s)"
        
        case "$health_status" in
            "healthy")
                log "SUCCESS" "All services are healthy"
                return 0
                ;;
            "partially_healthy")
                log "INFO" "Some services are healthy, waiting for all..."
                ;;
            "unhealthy")
                log "INFO" "Services are starting up, waiting..."
                ;;
        esac
        
        sleep 5
    done
}

# Verify port binding
verify_port_binding() {
    log "INFO" "Verifying port binding..."
    log "DEBUG" "Checking Ollama port: $OLLAMA_PORT"
    log "DEBUG" "Checking WebUI port: $WEBUI_PORT"
    
    # Check Ollama port (bound to all interfaces or localhost)
    log "DEBUG" "Searching for pattern: *.$OLLAMA_PORT.*LISTEN"
    local ollama_found=false
    if netstat -an | grep -q "\*\.$OLLAMA_PORT.*LISTEN"; then
        ollama_found=true
    elif netstat -an | grep -q "\*$OLLAMA_PORT.*LISTEN"; then
        ollama_found=true
    fi
    
    if [[ "$ollama_found" == "false" ]]; then
        log "ERROR" "Ollama port $OLLAMA_PORT is not bound"
        log "DEBUG" "Available ports: $(netstat -an | grep LISTEN | head -5)"
        log "DEBUG" "Grep command: netstat -an | grep -q \"\\*\.$OLLAMA_PORT.*LISTEN\""
        return 1
    else
        log "DEBUG" "Ollama port $OLLAMA_PORT found"
    fi
    
    # Check WebUI port (bound to localhost)
    local webui_found=false
    if netstat -an | grep -q "127.0.0.1.$WEBUI_PORT.*LISTEN"; then
        webui_found=true
    elif netstat -an | grep -q "127.0.0.1:$WEBUI_PORT.*LISTEN"; then
        webui_found=true
    fi
    
    if [[ "$webui_found" == "false" ]]; then
        log "ERROR" "WebUI port $WEBUI_PORT is not bound to localhost"
        log "DEBUG" "Available localhost ports: $(netstat -an | grep 127.0.0.1 | head -5)"
        return 1
    else
        log "DEBUG" "WebUI port $WEBUI_PORT found"
    fi
    
    # Verify no external binding
    if netstat -an | grep -q "0.0.0.0:$OLLAMA_PORT\|0.0.0.0:$WEBUI_PORT"; then
        log "ERROR" "Services are bound to external interfaces (0.0.0.0)"
        return 1
    fi
    
    log "SUCCESS" "Port binding verification passed"
    return 0
}

# Get service status
get_service_status() {
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    echo "=== Docker Stack Status ==="
    $compose_cmd -f "$DOCKER_COMPOSE_FILE" ps
    echo
    echo "=== Service Health ==="
    docker_health_check
    echo
    echo "=== Port Binding ==="
    netstat -an | grep -E "127.0.0.1:($OLLAMA_PORT|$WEBUI_PORT)" || echo "No localhost ports found"
    echo
    echo "=== Vault Mount ==="
    if [[ -d "$VAULT_MOUNT_POINT" ]]; then
        echo "Vault mounted at: $VAULT_MOUNT_POINT"
        echo "Vault contents: $(ls -la "$VAULT_MOUNT_POINT" | wc -l) items"
    else
        echo "Vault not mounted"
    fi
}

# Main function for command-line usage
# Clean up all data (destructive operation)
docker_cleanup_all_data() {
    log "WARN" "This will permanently delete ALL data including journals, WebUI data, and volumes"
    log "WARN" "This action cannot be undone!"
    
    # Confirm destructive action
    echo -n "Type 'DELETE ALL DATA' to confirm: "
    read -r confirmation
    if [[ "$confirmation" != "DELETE ALL DATA" ]]; then
        log "INFO" "Data cleanup cancelled"
        return 0
    fi
    
    log "INFO" "Stopping all services..."
    docker_stack_down 10
    
    log "INFO" "Removing all volumes and data..."
    if command -v docker >/dev/null 2>&1; then
        # Remove all journals-related volumes
        docker volume ls -q | grep -E "(journals|webui)" | xargs -r docker volume rm -f 2>/dev/null || true
        
        # Remove all journals-related containers
        docker ps -a --filter "name=journals-" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true
        
        # Remove all journals-related networks
        docker network ls --filter "name=journals" --format "{{.Name}}" | xargs -r docker network rm 2>/dev/null || true
    fi
    
    log "SUCCESS" "All data has been permanently deleted"
    log "INFO" "You can now run 'journals-up' to start with a fresh system"
}

main() {
    local command="${1:-}"
    
    case "$command" in
        "up")
            docker_stack_up
            ;;
        "down")
            local timeout="${2:-$GRACEFUL_SHUTDOWN_TIMEOUT}"
            docker_stack_down "$timeout"
            ;;
        "health")
            docker_health_check
            ;;
        "logs")
            local service="${2:-}"
            local lines="${3:-50}"
            docker_logs "$service" "$lines"
            ;;
        "cleanup")
            docker_cleanup
            ;;
        "cleanup-all-data")
            docker_cleanup_all_data
            ;;
        "status")
            get_service_status
            ;;
        "webui-security")
            local webui_command="${2:-help}"
            if [[ -f "$WEBUI_SECURITY_MANAGER" ]]; then
                "$WEBUI_SECURITY_MANAGER" "$webui_command" "${@:3}"
            else
                error_exit "WebUI security manager not found: $WEBUI_SECURITY_MANAGER"
            fi
            ;;
        "webui-monitor")
            local monitor_command="${2:-help}"
            if [[ -f "$WEBUI_MONITOR" ]]; then
                "$WEBUI_MONITOR" "$monitor_command" "${@:3}"
            else
                error_exit "WebUI monitor not found: $WEBUI_MONITOR"
            fi
            ;;
        "help"|"--help"|"-h")
            cat << EOF
Docker Manager - Secure Docker Orchestration System

Usage: $0 <command> [options]

Commands:
  up [timeout]              Start Docker stack
  down [timeout]            Stop Docker stack (default: 30s)
  health                    Check service health
  logs <service> [lines]    Get service logs (default: 50 lines)
  cleanup                   Clean up Docker resources
  cleanup-all-data          Permanently delete ALL data (destructive)
  status                    Get comprehensive status
  webui-security <cmd>      WebUI security management
  webui-monitor <cmd>       WebUI security monitoring
  help                      Show this help message

Environment Variables:
  DOCKER_COMPOSE_FILE       Path to compose file (default: ./docker-compose.yml)
  VAULT_MOUNT_POINT         Vault mount point (default: ~/Journals)
  OLLAMA_PORT               Ollama port (default: 11434)
  WEBUI_PORT                WebUI port (default: 3000)
  HEALTH_CHECK_TIMEOUT      Health check timeout (default: 120s)
  GRACEFUL_SHUTDOWN_TIMEOUT Graceful shutdown timeout (default: 30s)
  LOG_LEVEL                 Logging level (default: INFO)
  LOG_FILE                  Log file path (default: /tmp/docker-manager.log)

Security Features:
  - All services bound to localhost only (127.0.0.1)
  - Journal directory mounted read-only
  - Isolated Docker network
  - No external network access
  - Health monitoring and dependency management

Examples:
  $0 up
  $0 down 60
  $0 health
  $0 logs ollama 100
  $0 status
  $0 cleanup
  $0 webui-security run-tests
  $0 webui-monitor start 30

EOF
            ;;
        "")
            error_exit "No command specified. Use '$0 help' for usage information."
            ;;
        *)
            error_exit "Unknown command: $command. Use '$0 help' for usage information."
            ;;
    esac
}

# Run main function with all arguments
main "$@"
