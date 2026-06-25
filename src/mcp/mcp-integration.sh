#!/bin/bash

# MCP Integration Script for Journals Infrastructure
# 
# This script sets up MCP server integration with Open WebUI
# to enable LLM agents to access vault data through MCP calls.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MCP_SERVER_SCRIPT="$SCRIPT_DIR/mcp-server.sh"
DOCKER_COMPOSE_FILE="$PROJECT_ROOT/src/docker/docker-compose.yml"
WEBUI_DATA_DIR="$PROJECT_ROOT/webui-data"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    log_info "Docker is running"
}

# Check if vault is mounted
check_vault() {
    local vault_path="/journals"
    if [[ ! -d "$vault_path" ]]; then
        log_error "Vault is not mounted at $vault_path"
        log_error "Please run './bin/journals-up.sh' first to mount the vault"
        exit 1
    fi
    log_info "Vault is mounted at $vault_path"
}

# Install MCP dependencies
install_mcp_dependencies() {
    log_info "Installing MCP server dependencies..."
    
    # Install Python MCP package
    if ! python3 -c "import mcp" 2>/dev/null; then
        log_info "Installing MCP package..."
        pip3 install mcp
    else
        log_info "MCP package already installed"
    fi
    
    # Install other dependencies
    pip3 install asyncio pathlib mimetypes
    
    log_success "MCP dependencies installed"
}

# Start MCP server
start_mcp_server() {
    log_info "Starting MCP server..."
    
    if [[ -f "$MCP_SERVER_SCRIPT" ]]; then
        "$MCP_SERVER_SCRIPT" start
    else
        log_error "MCP server script not found: $MCP_SERVER_SCRIPT"
        exit 1
    fi
}

# Start Docker services with MCP server
start_docker_services() {
    log_info "Starting Docker services with MCP server..."
    
    cd "$(dirname "$DOCKER_COMPOSE_FILE")"
    
    # Start all services including MCP server
    docker-compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be healthy..."
    sleep 10
    
    # Check service status
    docker-compose ps
}

# Configure Open WebUI for MCP integration
configure_webui_mcp() {
    log_info "Configuring Open WebUI for MCP integration..."
    
    # Create MCP configuration directory
    local mcp_config_dir="$WEBUI_DATA_DIR/mcp"
    mkdir -p "$mcp_config_dir"
    
    # Copy MCP client configuration
    cp "$SCRIPT_DIR/mcp-client-config.json" "$mcp_config_dir/"
    
    # Create MCP server startup script
    cat > "$mcp_config_dir/start-mcp-server.sh" << 'EOF'
#!/bin/bash
# Start MCP server for vault access
cd /app
python3 vault-mcp-server.py &
echo $! > /tmp/mcp-server.pid
EOF
    
    chmod +x "$mcp_config_dir/start-mcp-server.sh"
    
    log_success "Open WebUI MCP configuration created"
}

# Test MCP server connection
test_mcp_connection() {
    log_info "Testing MCP server connection..."
    
    # Wait for MCP server to start
    sleep 5
    
    # Test HTTP connection
    if command -v curl >/dev/null 2>&1; then
        if curl -s "http://127.0.0.1:8082/health" >/dev/null 2>&1; then
            log_success "MCP server is responding to HTTP requests"
        else
            log_warning "MCP server is not responding to HTTP requests"
        fi
    fi
    
    # Test vault access
    if [[ -d "/journals" ]]; then
        local file_count=$(find "/journals" -name "*.md" -type f | wc -l)
        log_info "Found $file_count markdown files in vault"
    else
        log_error "Vault path not accessible: /journals"
        return 1
    fi
    
    log_success "MCP server connection test completed"
}

# Show MCP server status
show_mcp_status() {
    log_info "MCP Server Status:"
    echo "----------------------------------------"
    
    # Check if MCP server is running
    if docker ps | grep -q "journals-mcp-server"; then
        log_success "MCP server container is running"
    else
        log_error "MCP server container is not running"
    fi
    
    # Check MCP server logs
    log_info "Recent MCP server logs:"
    docker logs journals-mcp-server --tail 10 2>/dev/null || log_warning "Could not retrieve MCP server logs"
    
    # Check vault access
    if [[ -d "/journals" ]]; then
        local file_count=$(find "/journals" -name "*.md" -type f | wc -l)
        log_info "Vault contains $file_count markdown files"
    else
        log_error "Vault is not accessible"
    fi
}

# Stop MCP server and services
stop_mcp_services() {
    log_info "Stopping MCP server and services..."
    
    # Stop Docker services
    cd "$(dirname "$DOCKER_COMPOSE_FILE")"
    docker-compose down
    
    # Stop local MCP server if running
    if [[ -f "$MCP_SERVER_SCRIPT" ]]; then
        "$MCP_SERVER_SCRIPT" stop
    fi
    
    log_success "MCP server and services stopped"
}

# Show help
show_help() {
    cat << EOF
MCP Integration Script for Journals Infrastructure

Usage: $0 <command>

Commands:
    install     Install MCP dependencies
    start       Start MCP server and Docker services
    stop        Stop MCP server and Docker services
    restart     Restart MCP server and Docker services
    status      Show MCP server status
    test        Test MCP server connection
    configure   Configure Open WebUI for MCP integration
    help        Show this help message

Examples:
    $0 install      # Install MCP dependencies
    $0 start        # Start MCP server and services
    $0 status       # Check MCP server status
    $0 test         # Test MCP server connection

Prerequisites:
    - Docker must be running
    - Vault must be mounted (run ./bin/journals-up.sh first)
    - Python 3.11+ must be available

EOF
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        "install")
            check_docker
            install_mcp_dependencies
            ;;
        "start")
            check_docker
            check_vault
            start_mcp_server
            start_docker_services
            configure_webui_mcp
            test_mcp_connection
            ;;
        "stop")
            stop_mcp_services
            ;;
        "restart")
            stop_mcp_services
            sleep 2
            main start
            ;;
        "status")
            show_mcp_status
            ;;
        "test")
            test_mcp_connection
            ;;
        "configure")
            configure_webui_mcp
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

