#!/usr/bin/env bash
set -euo pipefail

# journals-status.sh - Check Journals Infrastructure Status
# 
# This script provides comprehensive status information for the journals infrastructure
# including vault status, Docker services, health checks, and system information.
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
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Status indicators
readonly STATUS_OK="${GREEN}✓${NC}"
readonly STATUS_WARN="${YELLOW}⚠${NC}"
readonly STATUS_ERROR="${RED}✗${NC}"
readonly STATUS_INFO="${BLUE}ℹ${NC}"

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get vault status
get_vault_status() {
    echo -e "${CYAN}=== Vault Status ===${NC}"
    
    if [[ ! -f "$VAULT_MANAGER" ]]; then
        echo -e "Vault Manager: ${STATUS_ERROR} Not found"
        return 1
    fi
    
    if ! command_exists docker; then
        echo -e "Docker: ${STATUS_ERROR} Not installed"
        return 1
    fi
    
    # Check vault existence
    if "$VAULT_MANAGER" exists >/dev/null 2>&1; then
        echo -e "Vault Image: ${STATUS_OK} Exists"
        
        # Check vault status
        local vault_status
        vault_status=$("$VAULT_MANAGER" status 2>/dev/null || echo "error")
        
        case "$vault_status" in
            "mounted")
                echo -e "Vault Mount: ${STATUS_OK} Mounted"
                echo -e "Mount Point: ${STATUS_INFO} ${VAULT_MOUNT_POINT:-${HOME}/Journals}"
                
                # Check if mount point is readable
                if [[ -d "${VAULT_MOUNT_POINT:-${HOME}/Journals}" ]] && ls "${VAULT_MOUNT_POINT:-${HOME}/Journals}" >/dev/null 2>&1; then
                    echo -e "Vault Access: ${STATUS_OK} Readable"
                    local file_count
                    file_count=$(ls -1 "${VAULT_MOUNT_POINT:-${HOME}/Journals}" 2>/dev/null | wc -l)
                    echo -e "Journal Files: ${STATUS_INFO} $file_count items"
                else
                    echo -e "Vault Access: ${STATUS_ERROR} Not readable"
                fi
                ;;
            "unmounted")
                echo -e "Vault Mount: ${STATUS_WARN} Unmounted"
                ;;
            "error")
                echo -e "Vault Mount: ${STATUS_ERROR} Error checking status"
                ;;
            *)
                echo -e "Vault Mount: ${STATUS_ERROR} Unknown status: $vault_status"
                ;;
        esac
    else
        echo -e "Vault Image: ${STATUS_WARN} Does not exist"
        echo -e "Vault Mount: ${STATUS_WARN} N/A"
    fi
    
    echo
}

# Get Docker status
get_docker_status() {
    echo -e "${CYAN}=== Docker Services ===${NC}"
    
    if [[ ! -f "$DOCKER_MANAGER" ]]; then
        echo -e "Docker Manager: ${STATUS_ERROR} Not found"
        return 1
    fi
    
    if ! command_exists docker; then
        echo -e "Docker: ${STATUS_ERROR} Not installed"
        return 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        echo -e "Docker Daemon: ${STATUS_ERROR} Not running"
        return 1
    fi
    
    echo -e "Docker Daemon: ${STATUS_OK} Running"
    
    # Get service health
    local health_status
    health_status=$("$DOCKER_MANAGER" health 2>/dev/null || echo "unhealthy")
    
    case "$health_status" in
        "healthy")
            echo -e "Service Health: ${STATUS_OK} All services healthy"
            ;;
        "partially_healthy")
            echo -e "Service Health: ${STATUS_WARN} Some services healthy"
            ;;
        "unhealthy")
            echo -e "Service Health: ${STATUS_ERROR} Services unhealthy"
            ;;
        *)
            echo -e "Service Health: ${STATUS_ERROR} Unknown status: $health_status"
            ;;
    esac
    
    # Check individual services
    echo -e "\n${CYAN}=== Individual Services ===${NC}"
    
    # Check Ollama
    if curl -f "http://127.0.0.1:${OLLAMA_PORT:-11434}/api/tags" >/dev/null 2>&1; then
        echo -e "Ollama (${OLLAMA_PORT:-11434}): ${STATUS_OK} Running"
    else
        echo -e "Ollama (${OLLAMA_PORT:-11434}): ${STATUS_ERROR} Not responding"
    fi
    
    # Check WebUI
    if curl -f "http://127.0.0.1:${WEBUI_PORT:-3000}/health" >/dev/null 2>&1; then
        echo -e "WebUI (${WEBUI_PORT:-3000}): ${STATUS_OK} Running"
    else
        echo -e "WebUI (${WEBUI_PORT:-3000}): ${STATUS_ERROR} Not responding"
    fi
    
    echo
}

# Get port binding status
get_port_status() {
    echo -e "${CYAN}=== Port Binding ===${NC}"
    
    # Check Ollama port
    if netstat -an 2>/dev/null | grep -q "127.0.0.1:${OLLAMA_PORT:-11434}"; then
        echo -e "Ollama Port: ${STATUS_OK} Bound to localhost only"
    else
        echo -e "Ollama Port: ${STATUS_ERROR} Not bound to localhost"
    fi
    
    # Check WebUI port
    if netstat -an 2>/dev/null | grep -q "127.0.0.1:${WEBUI_PORT:-3000}"; then
        echo -e "WebUI Port: ${STATUS_OK} Bound to localhost only"
    else
        echo -e "WebUI Port: ${STATUS_ERROR} Not bound to localhost"
    fi
    
    # Check for external binding (security check)
    if netstat -an 2>/dev/null | grep -q "0.0.0.0:${OLLAMA_PORT:-11434}\|0.0.0.0:${WEBUI_PORT:-3000}"; then
        echo -e "Security: ${STATUS_ERROR} Services bound to external interfaces!"
    else
        echo -e "Security: ${STATUS_OK} No external binding detected"
    fi
    
    echo
}

# Get system information
get_system_info() {
    echo -e "${CYAN}=== System Information ===${NC}"
    
    # OS information
    echo -e "Operating System: ${STATUS_INFO} $(uname -s) $(uname -r)"
    
    # Docker version
    if command_exists docker; then
        local docker_version
        docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
        echo -e "Docker Version: ${STATUS_INFO} $docker_version"
    fi
    
    # Docker Compose version
    if command_exists docker-compose; then
        local compose_version
        compose_version=$(docker-compose --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
        echo -e "Docker Compose: ${STATUS_INFO} $compose_version"
    elif docker compose version >/dev/null 2>&1; then
        local compose_version
        compose_version=$(docker compose version 2>/dev/null | cut -d' ' -f4 | cut -d',' -f1)
        echo -e "Docker Compose: ${STATUS_INFO} $compose_version (plugin)"
    fi
    
    # Memory usage
    if command_exists free; then
        local memory_info
        memory_info=$(free -h 2>/dev/null | grep "Mem:" | awk '{print $3 "/" $2}' || echo "Unknown")
        echo -e "Memory Usage: ${STATUS_INFO} $memory_info"
    elif command_exists vm_stat; then
        # macOS memory info
        local memory_info
        memory_info=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//' | awk '{print ($1 * 4096) / 1024 / 1024 / 1024 " GB"}' || echo "Unknown")
        echo -e "Memory Usage: ${STATUS_INFO} $memory_info active"
    fi
    
    # Disk usage
    if command_exists df; then
        local disk_info
        disk_info=$(df -h "${VAULT_MOUNT_POINT:-${HOME}/Journals}" 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}' || echo "Unknown")
        echo -e "Disk Usage: ${STATUS_INFO} $disk_info"
    fi
    
    echo
}

# Get service URLs
get_service_urls() {
    echo -e "${CYAN}=== Service URLs ===${NC}"
    
    echo -e "Open WebUI: ${STATUS_INFO} http://127.0.0.1:${WEBUI_PORT:-3000}"
    echo -e "Ollama API: ${STATUS_INFO} http://127.0.0.1:${OLLAMA_PORT:-11434}"
    echo -e "Ollama Models: ${STATUS_INFO} http://127.0.0.1:${OLLAMA_PORT:-11434}/api/tags"
    
    echo
}

# Get management commands
get_management_commands() {
    echo -e "${CYAN}=== Management Commands ===${NC}"
    
    echo -e "Start System: ${STATUS_INFO} $0 up"
    echo -e "Stop System: ${STATUS_INFO} $0 down"
    echo -e "Check Status: ${STATUS_INFO} $0 status"
    echo -e "View Logs: ${STATUS_INFO} $0 logs [service]"
    echo -e "Docker Logs: ${STATUS_INFO} $PROJECT_ROOT/src/docker/docker-manager.sh logs [service]"
    echo -e "Vault Status: ${STATUS_INFO} $PROJECT_ROOT/src/vault/vault-manager.sh status"
    
    echo
}

# Main function
main() {
    local command="${1:-}"
    
    case "$command" in
        "vault")
            get_vault_status
            ;;
        "docker")
            get_docker_status
            ;;
        "ports")
            get_port_status
            ;;
        "system")
            get_system_info
            ;;
        "urls")
            get_service_urls
            ;;
        "commands")
            get_management_commands
            ;;
        "help"|"--help"|"-h")
            cat << EOF
Journals Status - Infrastructure Status Checker

Usage: $0 [command]

Commands:
  (no command)    Show complete status report
  vault           Show vault status only
  docker          Show Docker services status only
  ports           Show port binding status only
  system          Show system information only
  urls            Show service URLs only
  commands        Show management commands only
  help            Show this help message

Examples:
  $0              # Complete status report
  $0 vault        # Vault status only
  $0 docker       # Docker services only
  $0 ports        # Port binding only

EOF
            ;;
        "")
            # Show complete status report
            echo -e "${CYAN}=== Journals Infrastructure Status ===${NC}"
            echo
            get_vault_status
            get_docker_status
            get_port_status
            get_system_info
            get_service_urls
            get_management_commands
            ;;
        *)
            log "ERROR" "Unknown command: $command. Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
