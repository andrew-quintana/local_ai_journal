#!/bin/bash

# MCP Server Management Script
# 
# This script manages the MCP server for vault access integration
# with LLM agents in the journals infrastructure.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/mcp-server.conf"
LOG_DIR="$PROJECT_ROOT/logs"
PID_FILE="$PROJECT_ROOT/.mcp-server.pid"
LOG_FILE="$LOG_DIR/mcp-server.log"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if MCP server is running
mcp_server_is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Start MCP server
start_mcp_server() {
    log_info "Starting MCP server..."
    
    if mcp_server_is_running; then
        log_warning "MCP server is already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi
    
    # Check if vault is mounted
    if [[ ! -d "$VAULT_PATH" ]]; then
        log_error "Vault path not found: $VAULT_PATH"
        log_error "Please ensure the vault is mounted first"
        return 1
    fi
    
    # Check if Python MCP package is available
    if ! python3 -c "import mcp" 2>/dev/null; then
        log_info "Installing MCP package..."
        pip3 install mcp
    fi
    
    # Start MCP server
    cd "$SCRIPT_DIR"
    export VAULT_PATH="$VAULT_PATH"
    nohup python3 vault-mcp-server.py > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment and check if it started successfully
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        log_success "MCP server started successfully (PID: $pid)"
        log_info "Server logs: $LOG_FILE"
        return 0
    else
        log_error "Failed to start MCP server"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Stop MCP server
stop_mcp_server() {
    log_info "Stopping MCP server..."
    
    if ! mcp_server_is_running; then
        log_warning "MCP server is not running"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    if kill -TERM "$pid" 2>/dev/null; then
        # Wait for graceful shutdown
        local count=0
        while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
            sleep 1
            ((count++))
        done
        
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Force killing MCP server (PID: $pid)"
            kill -KILL "$pid" 2>/dev/null
        fi
        
        rm -f "$PID_FILE"
        log_success "MCP server stopped"
        return 0
    else
        log_error "Failed to stop MCP server"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Restart MCP server
restart_mcp_server() {
    log_info "Restarting MCP server..."
    stop_mcp_server
    sleep 2
    start_mcp_server
}

# Check MCP server status
check_mcp_server_status() {
    if mcp_server_is_running; then
        local pid=$(cat "$PID_FILE")
        log_success "MCP server is running (PID: $pid)"
        
        # Check if server is responding
        if command -v curl >/dev/null 2>&1; then
            if curl -s "http://127.0.0.1:$MCP_SERVER_PORT/health" >/dev/null 2>&1; then
                log_info "MCP server is responding to health checks"
            else
                log_warning "MCP server is running but not responding to health checks"
            fi
        fi
        
        return 0
    else
        log_error "MCP server is not running"
        return 1
    fi
}

# Show MCP server logs
show_mcp_server_logs() {
    local lines="${1:-50}"
    log_info "Showing last $lines lines of MCP server logs:"
    echo "----------------------------------------"
    if [[ -f "$LOG_FILE" ]]; then
        tail -n "$lines" "$LOG_FILE"
    else
        log_warning "Log file not found: $LOG_FILE"
    fi
}

# Test MCP server connection
test_mcp_server() {
    log_info "Testing MCP server connection..."
    
    if ! mcp_server_is_running; then
        log_error "MCP server is not running"
        return 1
    fi
    
    # Test basic connectivity
    if command -v curl >/dev/null 2>&1; then
        if curl -s "http://127.0.0.1:$MCP_SERVER_PORT/health" >/dev/null 2>&1; then
            log_success "MCP server is responding to HTTP requests"
        else
            log_warning "MCP server is not responding to HTTP requests"
        fi
    fi
    
    # Test vault access
    if [[ -d "$VAULT_PATH" ]]; then
        local file_count=$(find "$VAULT_PATH" -name "*.md" -type f | wc -l)
        log_info "Found $file_count markdown files in vault"
    else
        log_error "Vault path not accessible: $VAULT_PATH"
        return 1
    fi
    
    log_success "MCP server test completed"
    return 0
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

# Show help
show_help() {
    cat << EOF
MCP Server Management Script

Usage: $0 <command>

Commands:
    start       Start the MCP server
    stop        Stop the MCP server
    restart     Restart the MCP server
    status      Check MCP server status
    logs        Show MCP server logs
    test        Test MCP server connection
    install     Install MCP dependencies
    help        Show this help message

Configuration:
    Config file: $CONFIG_FILE
    Log file: $LOG_FILE
    PID file: $PID_FILE
    Vault path: $VAULT_PATH

Examples:
    $0 start          # Start the MCP server
    $0 status         # Check if server is running
    $0 logs 100       # Show last 100 log lines
    $0 test           # Test server connectivity
    $0 install        # Install dependencies

EOF
}

# Main execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        "start")
            start_mcp_server
            ;;
        "stop")
            stop_mcp_server
            ;;
        "restart")
            restart_mcp_server
            ;;
        "status")
            check_mcp_server_status
            ;;
        "logs")
            show_mcp_server_logs "${2:-50}"
            ;;
        "test")
            test_mcp_server
            ;;
        "install")
            install_mcp_dependencies
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

