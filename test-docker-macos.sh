#!/bin/bash

# test-docker-macos.sh - macOS-Compatible Docker Diagnosis
# 
# This script provides Docker diagnosis for macOS without using timeout command
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIAGNOSIS_LOG="${SCRIPT_DIR}/docker-macos-diagnosis.log"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging
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
    esac
    
    echo "[$timestamp] [$level] $message" >> "$DIAGNOSIS_LOG"
}

# Test command with background process and kill
test_command() {
    local cmd="$1"
    local description="$2"
    
    log "INFO" "Testing: $description"
    echo "=== $description ===" >> "$DIAGNOSIS_LOG"
    
    # Run command in background
    eval "$cmd" >> "$DIAGNOSIS_LOG" 2>&1 &
    local pid=$!
    
    # Wait for 5 seconds
    sleep 5
    
    # Check if process is still running
    if kill -0 "$pid" 2>/dev/null; then
        log "ERROR" "Command timed out: $description"
        kill "$pid" 2>/dev/null || true
        echo "TIMEOUT after 5 seconds" >> "$DIAGNOSIS_LOG"
        return 1
    else
        wait "$pid"
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            log "SUCCESS" "Command succeeded: $description"
        else
            log "ERROR" "Command failed (exit code: $exit_code): $description"
        fi
        return $exit_code
    fi
}

# System Information
collect_system_info() {
    log "INFO" "=== Collecting System Information ==="
    
    echo "=== System Information ===" >> "$DIAGNOSIS_LOG"
    echo "Date: $(date)" >> "$DIAGNOSIS_LOG"
    echo "OS: $(uname -a)" >> "$DIAGNOSIS_LOG"
    echo "Shell: $SHELL" >> "$DIAGNOSIS_LOG"
    echo "User: $USER" >> "$DIAGNOSIS_LOG"
    echo "Working Directory: $(pwd)" >> "$DIAGNOSIS_LOG"
    echo "" >> "$DIAGNOSIS_LOG"
    
    # System resources
    log "INFO" "Checking system resources..."
    echo "=== System Resources ===" >> "$DIAGNOSIS_LOG"
    df -h >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    ps aux | head -20 >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
}

# Docker Process Analysis
analyze_docker_processes() {
    log "INFO" "=== Analyzing Docker Processes ==="
    
    echo "=== Docker Processes ===" >> "$DIAGNOSIS_LOG"
    
    # Check for Docker processes
    log "INFO" "Checking for Docker processes..."
    ps aux | grep -i docker >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check for Docker Desktop
    log "INFO" "Checking for Docker Desktop..."
    ps aux | grep -i "docker desktop" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check for Docker daemon
    log "INFO" "Checking for Docker daemon..."
    ps aux | grep -i dockerd >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
}

# Docker Socket Analysis
analyze_docker_socket() {
    log "INFO" "=== Analyzing Docker Socket ==="
    
    echo "=== Docker Socket Analysis ===" >> "$DIAGNOSIS_LOG"
    
    # Check Docker socket
    log "INFO" "Checking Docker socket..."
    if [[ -S /var/run/docker.sock ]]; then
        log "SUCCESS" "Docker socket exists: /var/run/docker.sock"
        ls -la /var/run/docker.sock >> "$DIAGNOSIS_LOG" 2>&1 || true
    else
        log "WARN" "Docker socket not found: /var/run/docker.sock"
    fi
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check Docker Desktop socket
    log "INFO" "Checking Docker Desktop socket..."
    if [[ -S ~/Library/Containers/com.docker.docker/Data/docker.sock ]]; then
        log "SUCCESS" "Docker Desktop socket exists"
        ls -la ~/Library/Containers/com.docker.docker/Data/docker.sock >> "$DIAGNOSIS_LOG" 2>&1 || true
    else
        log "WARN" "Docker Desktop socket not found"
    fi
    echo "" >> "$DIAGNOSIS_LOG"
}

# Test Docker Commands
test_docker_commands() {
    log "INFO" "=== Testing Docker Commands ==="
    
    echo "=== Docker Command Tests ===" >> "$DIAGNOSIS_LOG"
    
    # Test basic Docker commands
    test_command "docker --version" "Docker version"
    test_command "docker info" "Docker info"
    test_command "docker ps" "Docker ps"
    test_command "docker images" "Docker images"
    test_command "docker network ls" "Docker networks"
    test_command "docker volume ls" "Docker volumes"
}

# Test Docker Compose
test_docker_compose() {
    log "INFO" "=== Testing Docker Compose ==="
    
    echo "=== Docker Compose Tests ===" >> "$DIAGNOSIS_LOG"
    
    # Test Docker Compose commands
    test_command "docker-compose --version" "Docker Compose version"
    test_command "docker compose version" "Docker Compose (new syntax)"
    
    # Test Docker Compose configuration
    if [[ -f "src/docker/docker-compose.yml" ]]; then
        log "INFO" "Testing Docker Compose configuration..."
        test_command "docker-compose -f src/docker/docker-compose.yml config" "Docker Compose config validation"
    fi
}

# Network Analysis
analyze_network() {
    log "INFO" "=== Analyzing Network ==="
    
    echo "=== Network Analysis ===" >> "$DIAGNOSIS_LOG"
    
    # Check network interfaces
    log "INFO" "Checking network interfaces..."
    ifconfig >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check listening ports
    log "INFO" "Checking listening ports..."
    netstat -an | grep LISTEN >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check for port conflicts
    log "INFO" "Checking for port conflicts..."
    lsof -i :3000 >> "$DIAGNOSIS_LOG" 2>&1 || true
    lsof -i :11434 >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
}

# Resource Analysis
analyze_resources() {
    log "INFO" "=== Analyzing System Resources ==="
    
    echo "=== Resource Analysis ===" >> "$DIAGNOSIS_LOG"
    
    # Memory usage
    log "INFO" "Checking memory usage..."
    vm_stat >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # CPU usage
    log "INFO" "Checking CPU usage..."
    top -l 1 | head -10 >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Disk usage
    log "INFO" "Checking disk usage..."
    du -sh ~/Library/Containers/com.docker.docker 2>/dev/null || echo "Docker Desktop not found" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
}

# Generate Report
generate_report() {
    log "INFO" "=== Generating Diagnosis Report ==="
    
    echo "=== DIAGNOSIS REPORT ===" >> "$DIAGNOSIS_LOG"
    echo "Generated: $(date)" >> "$DIAGNOSIS_LOG"
    echo "Log file: $DIAGNOSIS_LOG" >> "$DIAGNOSIS_LOG"
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Summary
    log "INFO" "Diagnosis complete. Check log file: $DIAGNOSIS_LOG"
    
    # Show summary
    echo
    log "INFO" "=== DIAGNOSIS SUMMARY ==="
    echo "Log file: $DIAGNOSIS_LOG"
    echo "File size: $(wc -l < "$DIAGNOSIS_LOG" 2>/dev/null || echo "unknown") lines"
    echo
    log "INFO" "Key findings will be analyzed and documented in FRACAS-001"
}

# Main execution
main() {
    log "INFO" "Starting macOS-compatible Docker diagnosis..."
    
    # Initialize log file
    echo "Docker macOS Diagnosis - $(date)" > "$DIAGNOSIS_LOG"
    echo "========================================" >> "$DIAGNOSIS_LOG"
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Run diagnosis steps
    collect_system_info
    analyze_docker_processes
    analyze_docker_socket
    test_docker_commands
    test_docker_compose
    analyze_network
    analyze_resources
    generate_report
    
    log "SUCCESS" "Docker diagnosis completed"
}

# Run main function
main "$@"

