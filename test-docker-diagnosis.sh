#!/bin/bash

# test-docker-diagnosis.sh - Docker Hang Issues Diagnosis
# 
# This script provides a systematic approach to diagnose Docker hang issues
# without relying on Docker being fully functional.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIAGNOSIS_LOG="${SCRIPT_DIR}/docker-diagnosis.log"
readonly TIMEOUT=10  # 10 second timeout for commands

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

# Timeout wrapper for commands
run_with_timeout() {
    local timeout="$1"
    shift
    local command="$*"
    
    log "INFO" "Running: $command (timeout: ${timeout}s)"
    
    if timeout "$timeout" bash -c "$command" 2>&1; then
        log "SUCCESS" "Command completed: $command"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log "ERROR" "Command timed out: $command"
        else
            log "ERROR" "Command failed (exit code: $exit_code): $command"
        fi
        return $exit_code
    fi
}

# System Information Collection
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
    run_with_timeout 5 "df -h" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    run_with_timeout 5 "ps aux | head -20" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
}

# Docker Process Analysis
analyze_docker_processes() {
    log "INFO" "=== Analyzing Docker Processes ==="
    
    echo "=== Docker Processes ===" >> "$DIAGNOSIS_LOG"
    
    # Check for Docker processes
    log "INFO" "Checking for Docker processes..."
    run_with_timeout 5 "ps aux | grep -i docker" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check for Docker Desktop
    log "INFO" "Checking for Docker Desktop..."
    run_with_timeout 5 "ps aux | grep -i 'docker desktop'" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check for Docker daemon
    log "INFO" "Checking for Docker daemon..."
    run_with_timeout 5 "ps aux | grep -i dockerd" >> "$DIAGNOSIS_LOG" 2>&1 || true
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
        run_with_timeout 5 "ls -la /var/run/docker.sock" >> "$DIAGNOSIS_LOG" 2>&1 || true
    else
        log "WARN" "Docker socket not found: /var/run/docker.sock"
    fi
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check Docker Desktop socket
    log "INFO" "Checking Docker Desktop socket..."
    if [[ -S ~/Library/Containers/com.docker.docker/Data/docker.sock ]]; then
        log "SUCCESS" "Docker Desktop socket exists"
        run_with_timeout 5 "ls -la ~/Library/Containers/com.docker.docker/Data/docker.sock" >> "$DIAGNOSIS_LOG" 2>&1 || true
    else
        log "WARN" "Docker Desktop socket not found"
    fi
    echo "" >> "$DIAGNOSIS_LOG"
}

# Docker Command Testing
test_docker_commands() {
    log "INFO" "=== Testing Docker Commands ==="
    
    echo "=== Docker Command Tests ===" >> "$DIAGNOSIS_LOG"
    
    # Test basic Docker commands with timeout
    local commands=(
        "docker --version"
        "docker info"
        "docker ps"
        "docker images"
        "docker network ls"
        "docker volume ls"
    )
    
    for cmd in "${commands[@]}"; do
        log "INFO" "Testing: $cmd"
        if run_with_timeout "$TIMEOUT" "$cmd" >> "$DIAGNOSIS_LOG" 2>&1; then
            log "SUCCESS" "Command succeeded: $cmd"
        else
            log "ERROR" "Command failed or timed out: $cmd"
        fi
        echo "---" >> "$DIAGNOSIS_LOG"
    done
}

# Docker Compose Testing
test_docker_compose() {
    log "INFO" "=== Testing Docker Compose ==="
    
    echo "=== Docker Compose Tests ===" >> "$DIAGNOSIS_LOG"
    
    # Test Docker Compose commands
    local compose_commands=(
        "docker-compose --version"
        "docker compose version"
    )
    
    for cmd in "${compose_commands[@]}"; do
        log "INFO" "Testing: $cmd"
        if run_with_timeout "$TIMEOUT" "$cmd" >> "$DIAGNOSIS_LOG" 2>&1; then
            log "SUCCESS" "Command succeeded: $cmd"
        else
            log "ERROR" "Command failed or timed out: $cmd"
        fi
        echo "---" >> "$DIAGNOSIS_LOG"
    done
    
    # Test Docker Compose configuration
    if [[ -f "src/docker/docker-compose.yml" ]]; then
        log "INFO" "Testing Docker Compose configuration..."
        if run_with_timeout "$TIMEOUT" "docker-compose -f src/docker/docker-compose.yml config" >> "$DIAGNOSIS_LOG" 2>&1; then
            log "SUCCESS" "Docker Compose configuration is valid"
        else
            log "ERROR" "Docker Compose configuration has issues"
        fi
    fi
}

# Network Analysis
analyze_network() {
    log "INFO" "=== Analyzing Network ==="
    
    echo "=== Network Analysis ===" >> "$DIAGNOSIS_LOG"
    
    # Check network interfaces
    log "INFO" "Checking network interfaces..."
    run_with_timeout 5 "ifconfig" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check listening ports
    log "INFO" "Checking listening ports..."
    run_with_timeout 5 "netstat -an | grep LISTEN" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Check for port conflicts
    log "INFO" "Checking for port conflicts..."
    run_with_timeout 5 "lsof -i :3000" >> "$DIAGNOSIS_LOG" 2>&1 || true
    run_with_timeout 5 "lsof -i :11434" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
}

# Resource Analysis
analyze_resources() {
    log "INFO" "=== Analyzing System Resources ==="
    
    echo "=== Resource Analysis ===" >> "$DIAGNOSIS_LOG"
    
    # Memory usage
    log "INFO" "Checking memory usage..."
    run_with_timeout 5 "vm_stat" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # CPU usage
    log "INFO" "Checking CPU usage..."
    run_with_timeout 5 "top -l 1 | head -10" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
    
    # Disk usage
    log "INFO" "Checking disk usage..."
    run_with_timeout 5 "du -sh ~/Library/Containers/com.docker.docker 2>/dev/null || echo 'Docker Desktop not found'" >> "$DIAGNOSIS_LOG" 2>&1 || true
    echo "" >> "$DIAGNOSIS_LOG"
}

# Generate Diagnosis Report
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
    log "INFO" "Starting Docker hang diagnosis..."
    
    # Initialize log file
    echo "Docker Hang Diagnosis - $(date)" > "$DIAGNOSIS_LOG"
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

