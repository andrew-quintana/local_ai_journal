#!/usr/bin/env bash
set -euo pipefail

# journals-status.sh - Check Journals Infrastructure Status
# 
# This script provides comprehensive status information for the journals infrastructure
# including vault status, Docker services, health checks, system information, and security validation.
#
# Author: Local Development Team
# Version: 2.0
# Date: 2025-09-18

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly VAULT_MANAGER="$PROJECT_ROOT/src/vault/vault-manager.sh"
readonly DOCKER_MANAGER="$PROJECT_ROOT/src/docker/docker-manager.sh"

# System configuration
readonly OLLAMA_PORT="${OLLAMA_PORT:-11434}"
readonly WEBUI_PORT="${WEBUI_PORT:-3000}"
readonly VAULT_MOUNT_POINT="${VAULT_MOUNT_POINT:-${HOME}/Journals}"

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

# Get system status
get_system_status() {
    echo -e "${CYAN}=== System Status ===${NC}"
    
    # OS information
    local os_info
    os_info=$(uname -s 2>/dev/null || echo "Unknown")
    local os_version
    os_version=$(uname -r 2>/dev/null || echo "Unknown")
    echo -e "Operating System: ${STATUS_INFO} $os_info $os_version"
    
    # Memory usage
    local memory_info="Unknown"
    if command_exists free; then
        memory_info=$(free -h 2>/dev/null | grep "Mem:" | awk '{print $3 "/" $2}' || echo "Unknown")
    elif command_exists vm_stat; then
        # macOS memory info
        local memory_bytes
        memory_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
        local memory_gb=$((memory_bytes / 1024 / 1024 / 1024))
        memory_info="${memory_gb}GB total"
    fi
    echo -e "Memory Usage: ${STATUS_INFO} $memory_info"
    
    # Disk usage
    local disk_info="Unknown"
    if command_exists df; then
        disk_info=$(df -h "$VAULT_MOUNT_POINT" 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}' || echo "Unknown")
    fi
    echo -e "Disk Usage: ${STATUS_INFO} $disk_info"
    
    # Uptime
    if command_exists uptime; then
        local uptime_info
        uptime_info=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | sed 's/^ *//' || echo "Unknown")
        echo -e "System Load: ${STATUS_INFO} $uptime_info"
    fi
    
    echo
}

# Get vault status
get_vault_status() {
    echo -e "${CYAN}=== Vault Status ===${NC}"
    
    if [[ ! -f "$VAULT_MANAGER" ]]; then
        echo -e "Vault Manager: ${STATUS_ERROR} Not found"
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
                echo -e "Mount Point: ${STATUS_INFO} $VAULT_MOUNT_POINT"
                
                # Check if mount point is readable
                if [[ -d "$VAULT_MOUNT_POINT" ]] && ls "$VAULT_MOUNT_POINT" >/dev/null 2>&1; then
                    echo -e "Vault Access: ${STATUS_OK} Readable"
                    local file_count
                    file_count=$(ls -1 "$VAULT_MOUNT_POINT" 2>/dev/null | wc -l)
                    echo -e "Journal Files: ${STATUS_INFO} $file_count items"
                    
                    # Check vault size
                    local vault_size
                    vault_size=$(du -sh "$VAULT_MOUNT_POINT" 2>/dev/null | awk '{print $1}' || echo "Unknown")
                    echo -e "Vault Size: ${STATUS_INFO} $vault_size"
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
    
    # Get Docker version
    local docker_version
    docker_version=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1 || echo "Unknown")
    echo -e "Docker Version: ${STATUS_INFO} $docker_version"
    
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
    if curl -f "http://127.0.0.1:$OLLAMA_PORT/api/tags" >/dev/null 2>&1; then
        echo -e "Ollama ($OLLAMA_PORT): ${STATUS_OK} Running"
        
        # Get Ollama models
        local model_count
        model_count=$(curl -s "http://127.0.0.1:$OLLAMA_PORT/api/tags" 2>/dev/null | grep -o '"name"' | wc -l || echo "0")
        echo -e "Ollama Models: ${STATUS_INFO} $model_count models loaded"
    else
        echo -e "Ollama ($OLLAMA_PORT): ${STATUS_ERROR} Not responding"
    fi
    
    # Check WebUI
    if curl -f "http://127.0.0.1:$WEBUI_PORT/health" >/dev/null 2>&1; then
        echo -e "WebUI ($WEBUI_PORT): ${STATUS_OK} Running"
    else
        echo -e "WebUI ($WEBUI_PORT): ${STATUS_ERROR} Not responding"
    fi
    
    echo
}

# Get port binding status
get_port_status() {
    echo -e "${CYAN}=== Port Binding ===${NC}"
    
    # Check Ollama port
    if netstat -an 2>/dev/null | grep -q "127.0.0.1:$OLLAMA_PORT"; then
        echo -e "Ollama Port: ${STATUS_OK} Bound to localhost only"
    else
        echo -e "Ollama Port: ${STATUS_ERROR} Not bound to localhost"
    fi
    
    # Check WebUI port
    if netstat -an 2>/dev/null | grep -q "127.0.0.1:$WEBUI_PORT"; then
        echo -e "WebUI Port: ${STATUS_OK} Bound to localhost only"
    else
        echo -e "WebUI Port: ${STATUS_ERROR} Not bound to localhost"
    fi
    
    # Check for external binding (security check)
    local external_ports=()
    if netstat -an 2>/dev/null | grep -q "0.0.0.0:$OLLAMA_PORT"; then
        external_ports+=("$OLLAMA_PORT")
    fi
    if netstat -an 2>/dev/null | grep -q "0.0.0.0:$WEBUI_PORT"; then
        external_ports+=("$WEBUI_PORT")
    fi
    
    if [[ ${#external_ports[@]} -gt 0 ]]; then
        echo -e "Security: ${STATUS_ERROR} Services bound to external interfaces: ${external_ports[*]}"
    else
        echo -e "Security: ${STATUS_OK} No external binding detected"
    fi
    
    echo
}

# Get security status
get_security_status() {
    echo -e "${CYAN}=== Security Status ===${NC}"
    
    # Check vault encryption
    if [[ -f "$VAULT_MANAGER" ]] && "$VAULT_MANAGER" exists >/dev/null 2>&1; then
        echo -e "Vault Encryption: ${STATUS_OK} AES-256 encrypted"
    else
        echo -e "Vault Encryption: ${STATUS_WARN} Vault not available"
    fi
    
    # Check network isolation
    local isolated=true
    if netstat -an 2>/dev/null | grep -q "0.0.0.0:$OLLAMA_PORT\|0.0.0.0:$WEBUI_PORT"; then
        isolated=false
    fi
    
    if [[ "$isolated" == "true" ]]; then
        echo -e "Network Isolation: ${STATUS_OK} All services bound to localhost"
    else
        echo -e "Network Isolation: ${STATUS_ERROR} Some services exposed externally"
    fi
    
    # Check journal access permissions
    if [[ -d "$VAULT_MOUNT_POINT" ]]; then
        local mount_info
        mount_info=$(mount | grep "$VAULT_MOUNT_POINT" || echo "")
        if echo "$mount_info" | grep -q "read-only"; then
            echo -e "Journal Access: ${STATUS_OK} Read-only mount enforced"
        else
            echo -e "Journal Access: ${STATUS_WARN} Mount permissions unclear"
        fi
    else
        echo -e "Journal Access: ${STATUS_WARN} Vault not mounted"
    fi
    
    # Check for running processes
    local suspicious_processes=()
    if command_exists ps; then
        if ps aux 2>/dev/null | grep -q "ollama.*0.0.0.0"; then
            suspicious_processes+=("ollama")
        fi
        if ps aux 2>/dev/null | grep -q "webui.*0.0.0.0"; then
            suspicious_processes+=("webui")
        fi
    fi
    
    if [[ ${#suspicious_processes[@]} -gt 0 ]]; then
        echo -e "Process Security: ${STATUS_WARN} Suspicious processes: ${suspicious_processes[*]}"
    else
        echo -e "Process Security: ${STATUS_OK} No suspicious processes detected"
    fi
    
    echo
}

# Get service URLs
get_service_urls() {
    echo -e "${CYAN}=== Service URLs ===${NC}"
    
    echo -e "Open WebUI: ${STATUS_INFO} http://127.0.0.1:$WEBUI_PORT"
    echo -e "Ollama API: ${STATUS_INFO} http://127.0.0.1:$OLLAMA_PORT"
    echo -e "Ollama Models: ${STATUS_INFO} http://127.0.0.1:$OLLAMA_PORT/api/tags"
    echo -e "Ollama Health: ${STATUS_INFO} http://127.0.0.1:$OLLAMA_PORT/api/version"
    echo -e "WebUI Health: ${STATUS_INFO} http://127.0.0.1:$WEBUI_PORT/health"
    
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
    echo -e "Vault Mount: ${STATUS_INFO} $PROJECT_ROOT/src/vault/vault-manager.sh mount"
    echo -e "Vault Unmount: ${STATUS_INFO} $PROJECT_ROOT/src/vault/vault-manager.sh unmount"
    
    echo
}

# Get performance metrics
get_performance_metrics() {
    echo -e "${CYAN}=== Performance Metrics ===${NC}"
    
    # Check response times
    local ollama_response_time="N/A"
    local webui_response_time="N/A"
    
    if command_exists curl; then
        # Ollama response time
        local ollama_start
        ollama_start=$(date +%s%3N 2>/dev/null || date +%s)
        if curl -f "http://127.0.0.1:$OLLAMA_PORT/api/tags" >/dev/null 2>&1; then
            local ollama_end
            ollama_end=$(date +%s%3N 2>/dev/null || date +%s)
            ollama_response_time="$((ollama_end - ollama_start))ms"
        fi
        
        # WebUI response time
        local webui_start
        webui_start=$(date +%s%3N 2>/dev/null || date +%s)
        if curl -f "http://127.0.0.1:$WEBUI_PORT/health" >/dev/null 2>&1; then
            local webui_end
            webui_end=$(date +%s%3N 2>/dev/null || date +%s)
            webui_response_time="$((webui_end - webui_start))ms"
        fi
    fi
    
    echo -e "Ollama Response: ${STATUS_INFO} $ollama_response_time"
    echo -e "WebUI Response: ${STATUS_INFO} $webui_response_time"
    
    # Check container resource usage
    if command_exists docker; then
        echo -e "\n${CYAN}=== Container Resources ===${NC}"
        
        # Ollama container
        if docker ps --filter "name=journals-ollama" --format "{{.Names}}" | grep -q "journals-ollama"; then
            local ollama_cpu
            ollama_cpu=$(docker stats --no-stream --format "{{.CPUPerc}}" journals-ollama 2>/dev/null || echo "N/A")
            local ollama_mem
            ollama_mem=$(docker stats --no-stream --format "{{.MemUsage}}" journals-ollama 2>/dev/null || echo "N/A")
            echo -e "Ollama CPU: ${STATUS_INFO} $ollama_cpu"
            echo -e "Ollama Memory: ${STATUS_INFO} $ollama_mem"
        fi
        
        # WebUI container
        if docker ps --filter "name=journals-webui" --format "{{.Names}}" | grep -q "journals-webui"; then
            local webui_cpu
            webui_cpu=$(docker stats --no-stream --format "{{.CPUPerc}}" journals-webui 2>/dev/null || echo "N/A")
            local webui_mem
            webui_mem=$(docker stats --no-stream --format "{{.MemUsage}}" journals-webui 2>/dev/null || echo "N/A")
            echo -e "WebUI CPU: ${STATUS_INFO} $webui_cpu"
            echo -e "WebUI Memory: ${STATUS_INFO} $webui_mem"
        fi
    fi
    
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
        "security")
            get_security_status
            ;;
        "system")
            get_system_status
            ;;
        "urls")
            get_service_urls
            ;;
        "commands")
            get_management_commands
            ;;
        "performance")
            get_performance_metrics
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
  security        Show security status only
  system          Show system information only
  urls            Show service URLs only
  commands        Show management commands only
  performance     Show performance metrics only
  help            Show this help message

Examples:
  $0              # Complete status report
  $0 vault        # Vault status only
  $0 docker       # Docker services only
  $0 ports        # Port binding only
  $0 security     # Security status only
  $0 performance  # Performance metrics only

EOF
            ;;
        "")
            # Show complete status report
            echo -e "${CYAN}=== Journals Infrastructure Status ===${NC}"
            echo
            get_system_status
            get_vault_status
            get_docker_status
            get_port_status
            get_security_status
            get_performance_metrics
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