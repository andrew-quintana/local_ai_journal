#!/bin/bash

# Container Security Verification Module
# 
# This module provides comprehensive container security verification
# including privilege checks, resource limits, and security context validation.
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFICATION_LOG="$SCRIPT_DIR/../logs/container-security.log"
CONTAINERS=("journals-webui" "journals-ollama")

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Global variables
VERIFICATION_VIOLATIONS=0
VERIFICATION_WARNINGS=0
VERIFICATION_CHECKS=0
VERIFICATION_PASSED=0
VERIFICATION_FAILED=0

# Logging functions
verify_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[VERIFY INFO]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[VERIFY WARNING]${NC} $message"
            ((VERIFICATION_WARNINGS++))
            ;;
        "ERROR")
            echo -e "${RED}[VERIFY ERROR]${NC} $message"
            ((VERIFICATION_VIOLATIONS++))
            ;;
        "SUCCESS")
            echo -e "${GREEN}[VERIFY SUCCESS]${NC} $message"
            ;;
    esac
    
    echo "$timestamp|$level|$message" >> "$VERIFICATION_LOG"
}

# Initialize verification
init_verification() {
    mkdir -p "$(dirname "$VERIFICATION_LOG")"
    echo "=== CONTAINER SECURITY VERIFICATION STARTED ===" > "$VERIFICATION_LOG"
    echo "Timestamp: $(date)" >> "$VERIFICATION_LOG"
    echo "Containers: ${CONTAINERS[*]}" >> "$VERIFICATION_LOG"
    echo "" >> "$VERIFICATION_LOG"
    
    verify_log "INFO" "Container security verification initialized"
}

# Check if Docker is available
check_docker_availability() {
    verify_log "INFO" "Checking Docker availability..."
    
    ((VERIFICATION_CHECKS++))
    if ! command -v docker >/dev/null 2>&1; then
        verify_log "ERROR" "Docker command not found"
        ((VERIFICATION_FAILED++))
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        verify_log "ERROR" "Docker daemon not accessible"
        ((VERIFICATION_FAILED++))
        return 1
    fi
    
    verify_log "SUCCESS" "Docker is available and accessible"
    ((VERIFICATION_PASSED++))
    return 0
}

# Check container status
check_container_status() {
    verify_log "INFO" "Checking container status..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local status=$(docker ps --format "{{.Status}}" --filter "name=^$container$" 2>/dev/null || echo "not_running")
        
        if [[ "$status" == "not_running" ]]; then
            verify_log "WARNING" "Container $container is not running"
            ((VERIFICATION_FAILED++))
        else
            verify_log "SUCCESS" "Container $container is running: $status"
            ((VERIFICATION_PASSED++))
        fi
    done
}

# Check for privileged containers
check_privileged_containers() {
    verify_log "INFO" "Checking for privileged containers..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local privileged=$(docker inspect "$container" 2>/dev/null | grep -o '"Privileged":true' | wc -l)
        
        if [[ $privileged -gt 0 ]]; then
            verify_log "ERROR" "SECURITY VIOLATION: Container $container is running in privileged mode"
            ((VERIFICATION_FAILED++))
        else
            verify_log "SUCCESS" "Container $container is not privileged"
            ((VERIFICATION_PASSED++))
        fi
    done
}

# Check user execution context
check_user_execution() {
    verify_log "INFO" "Checking user execution context..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local user=$(docker inspect "$container" 2>/dev/null | grep -o '"User":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -z "$user" ]]; then
            verify_log "WARNING" "Container $container user context not specified"
            ((VERIFICATION_FAILED++))
        elif [[ "$user" == "root" ]] || [[ "$user" == "0" ]]; then
            verify_log "WARNING" "Container $container running as root user"
            ((VERIFICATION_FAILED++))
        else
            verify_log "SUCCESS" "Container $container running as non-root user: $user"
            ((VERIFICATION_PASSED++))
        fi
    done
}

# Check security options
check_security_options() {
    verify_log "INFO" "Checking security options..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local security_opts=$(docker inspect "$container" 2>/dev/null | grep -A 10 '"SecurityOpt"' | grep -o '"[^"]*"' | tr -d '"' | tr '\n' ' ')
        
        if [[ -z "$security_opts" ]]; then
            verify_log "WARNING" "Container $container has no security options configured"
            ((VERIFICATION_FAILED++))
        else
            verify_log "INFO" "Container $container security options: $security_opts"
            
            # Check for specific security options
            if echo "$security_opts" | grep -q "no-new-privileges"; then
                verify_log "SUCCESS" "Container $container has no-new-privileges enabled"
                ((VERIFICATION_PASSED++))
            else
                verify_log "WARNING" "Container $container missing no-new-privileges option"
                ((VERIFICATION_FAILED++))
            fi
        fi
    done
}

# Check resource limits
check_resource_limits() {
    verify_log "INFO" "Checking resource limits..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local memory_limit=$(docker inspect "$container" 2>/dev/null | grep -o '"Memory":[0-9]*' | head -1 | cut -d: -f2)
        local cpu_limit=$(docker inspect "$container" 2>/dev/null | grep -o '"NanoCpus":[0-9]*' | head -1 | cut -d: -f2)
        
        if [[ -n "$memory_limit" ]] && [[ $memory_limit -gt 0 ]]; then
            local memory_mb=$((memory_limit / 1024 / 1024))
            verify_log "SUCCESS" "Container $container memory limit: ${memory_mb}MB"
            ((VERIFICATION_PASSED++))
        else
            verify_log "WARNING" "Container $container has no memory limit"
            ((VERIFICATION_FAILED++))
        fi
        
        if [[ -n "$cpu_limit" ]] && [[ $cpu_limit -gt 0 ]]; then
            local cpu_cores=$((cpu_limit / 1000000000))
            verify_log "SUCCESS" "Container $container CPU limit: ${cpu_cores} cores"
            ((VERIFICATION_PASSED++))
        else
            verify_log "WARNING" "Container $container has no CPU limit"
            ((VERIFICATION_FAILED++))
        fi
    done
}

# Check read-only filesystem
check_readonly_filesystem() {
    verify_log "INFO" "Checking read-only filesystem..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local readonly=$(docker inspect "$container" 2>/dev/null | grep -o '"ReadonlyRootfs":true' | wc -l)
        
        if [[ $readonly -gt 0 ]]; then
            verify_log "SUCCESS" "Container $container has read-only filesystem"
            ((VERIFICATION_PASSED++))
        else
            verify_log "WARNING" "Container $container does not have read-only filesystem"
            ((VERIFICATION_FAILED++))
        fi
    done
}

# Check capability restrictions
check_capability_restrictions() {
    verify_log "INFO" "Checking capability restrictions..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local cap_drop=$(docker inspect "$container" 2>/dev/null | grep -A 10 '"CapDrop"' | grep -o '"[^"]*"' | tr -d '"' | tr '\n' ' ')
        local cap_add=$(docker inspect "$container" 2>/dev/null | grep -A 10 '"CapAdd"' | grep -o '"[^"]*"' | tr -d '"' | tr '\n' ' ')
        
        if [[ -n "$cap_drop" ]]; then
            verify_log "INFO" "Container $container capabilities dropped: $cap_drop"
            
            if echo "$cap_drop" | grep -q "ALL"; then
                verify_log "SUCCESS" "Container $container drops ALL capabilities"
                ((VERIFICATION_PASSED++))
            else
                verify_log "WARNING" "Container $container does not drop ALL capabilities"
                ((VERIFICATION_FAILED++))
            fi
        else
            verify_log "WARNING" "Container $container has no capability restrictions"
            ((VERIFICATION_FAILED++))
        fi
        
        if [[ -n "$cap_add" ]]; then
            verify_log "INFO" "Container $container capabilities added: $cap_add"
        fi
    done
}

# Check network isolation
check_network_isolation() {
    verify_log "INFO" "Checking network isolation..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local network_mode=$(docker inspect "$container" 2>/dev/null | grep -o '"NetworkMode":"[^"]*"' | cut -d'"' -f4)
        
        if [[ "$network_mode" == "host" ]]; then
            verify_log "ERROR" "SECURITY VIOLATION: Container $container using host network mode"
            ((VERIFICATION_FAILED++))
        elif [[ "$network_mode" == "bridge" ]]; then
            verify_log "WARNING" "Container $container using default bridge network"
            ((VERIFICATION_FAILED++))
        else
            verify_log "SUCCESS" "Container $container using isolated network: $network_mode"
            ((VERIFICATION_PASSED++))
        fi
    done
}

# Check port bindings
check_port_bindings() {
    verify_log "INFO" "Checking port bindings..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local port_bindings=$(docker inspect "$container" 2>/dev/null | grep -A 20 '"PortBindings"' | grep -o '"[0-9]*/tcp"' | tr -d '"/tcp' | tr '\n' ' ')
        
        if [[ -n "$port_bindings" ]]; then
            verify_log "INFO" "Container $container port bindings: $port_bindings"
            
            # Check if ports are bound to localhost only
            local external_bindings=$(docker port "$container" 2>/dev/null | grep -v "127.0.0.1" | wc -l)
            if [[ $external_bindings -gt 0 ]]; then
                verify_log "ERROR" "SECURITY VIOLATION: Container $container has external port bindings"
                ((VERIFICATION_FAILED++))
            else
                verify_log "SUCCESS" "Container $container ports bound to localhost only"
                ((VERIFICATION_PASSED++))
            fi
        else
            verify_log "INFO" "Container $container has no port bindings"
            ((VERIFICATION_PASSED++))
        fi
    done
}

# Check volume mounts
check_volume_mounts() {
    verify_log "INFO" "Checking volume mounts..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local mounts=$(docker inspect "$container" 2>/dev/null | grep -A 20 '"Mounts"' | grep -o '"Source":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')
        
        if [[ -n "$mounts" ]]; then
            verify_log "INFO" "Container $container volume mounts: $mounts"
            
            # Check for sensitive directory mounts
            local sensitive_mounts=$(echo "$mounts" | grep -E "(/etc|/root|/home|/var/log)" | wc -l)
            if [[ $sensitive_mounts -gt 0 ]]; then
                verify_log "WARNING" "Container $container has sensitive directory mounts"
                ((VERIFICATION_FAILED++))
            else
                verify_log "SUCCESS" "Container $container volume mounts are secure"
                ((VERIFICATION_PASSED++))
            fi
        else
            verify_log "INFO" "Container $container has no volume mounts"
            ((VERIFICATION_PASSED++))
        fi
    done
}

# Check environment variables
check_environment_variables() {
    verify_log "INFO" "Checking environment variables..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local env_vars=$(docker inspect "$container" 2>/dev/null | grep -A 50 '"Env"' | grep -o '"[^"]*"' | tr -d '"' | tr '\n' ' ')
        
        # Check for sensitive environment variables
        local sensitive_vars=$(echo "$env_vars" | grep -E "(PASSWORD|SECRET|KEY|TOKEN)" | wc -l)
        if [[ $sensitive_vars -gt 0 ]]; then
            verify_log "WARNING" "Container $container has sensitive environment variables"
            ((VERIFICATION_FAILED++))
        else
            verify_log "SUCCESS" "Container $container environment variables are secure"
            ((VERIFICATION_PASSED++))
        fi
    done
}

# Check container health
check_container_health() {
    verify_log "INFO" "Checking container health..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local health=$(docker inspect "$container" 2>/dev/null | grep -o '"Health":{[^}]*}' | grep -o '"Status":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -z "$health" ]]; then
            verify_log "WARNING" "Container $container has no health check configured"
            ((VERIFICATION_FAILED++))
        elif [[ "$health" == "healthy" ]]; then
            verify_log "SUCCESS" "Container $container is healthy"
            ((VERIFICATION_PASSED++))
        else
            verify_log "WARNING" "Container $container health status: $health"
            ((VERIFICATION_FAILED++))
        fi
    done
}

# Check container logs
check_container_logs() {
    verify_log "INFO" "Checking container logs..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local log_driver=$(docker inspect "$container" 2>/dev/null | grep -o '"LogConfig":{[^}]*}' | grep -o '"Type":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -z "$log_driver" ]]; then
            verify_log "WARNING" "Container $container has no log driver configured"
            ((VERIFICATION_FAILED++))
        else
            verify_log "SUCCESS" "Container $container log driver: $log_driver"
            ((VERIFICATION_PASSED++))
        fi
    done
}

# Check container restart policy
check_restart_policy() {
    verify_log "INFO" "Checking restart policy..."
    
    for container in "${CONTAINERS[@]}"; do
        ((VERIFICATION_CHECKS++))
        local restart_policy=$(docker inspect "$container" 2>/dev/null | grep -o '"RestartPolicy":{[^}]*}' | grep -o '"Name":"[^"]*"' | cut -d'"' -f4)
        
        if [[ "$restart_policy" == "always" ]] || [[ "$restart_policy" == "unless-stopped" ]]; then
            verify_log "SUCCESS" "Container $container restart policy: $restart_policy"
            ((VERIFICATION_PASSED++))
        else
            verify_log "WARNING" "Container $container restart policy: $restart_policy"
            ((VERIFICATION_FAILED++))
        fi
    done
}

# Generate verification report
generate_verification_report() {
    local report_file="$SCRIPT_DIR/../security-reports/container-security-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== CONTAINER SECURITY VERIFICATION REPORT ==="
        echo "Generated: $(date)"
        echo "Containers: ${CONTAINERS[*]}"
        echo ""
        
        echo "=== VERIFICATION SUMMARY ==="
        echo "Total Checks: $VERIFICATION_CHECKS"
        echo "Passed: $VERIFICATION_PASSED"
        echo "Failed: $VERIFICATION_FAILED"
        echo "Warnings: $VERIFICATION_WARNINGS"
        echo "Violations: $VERIFICATION_VIOLATIONS"
        echo ""
        
        if [[ $VERIFICATION_VIOLATIONS -eq 0 ]]; then
            echo "VERIFICATION STATUS: ✅ PASSED"
        elif [[ $VERIFICATION_VIOLATIONS -le 2 ]]; then
            echo "VERIFICATION STATUS: ⚠️  MINOR ISSUES"
        else
            echo "VERIFICATION STATUS: ❌ FAILED"
        fi
        echo ""
        
        echo "=== CONTAINER DETAILS ==="
        for container in "${CONTAINERS[@]}"; do
            echo "Container: $container"
            echo "Status: $(docker ps --format '{{.Status}}' --filter "name=^$container$" 2>/dev/null || echo "not_running")"
            echo "Image: $(docker inspect "$container" 2>/dev/null | grep -o '"Image":"[^"]*"' | cut -d'"' -f4 || echo "unknown")"
            echo "User: $(docker inspect "$container" 2>/dev/null | grep -o '"User":"[^"]*"' | cut -d'"' -f4 || echo "unknown")"
            echo "Network: $(docker inspect "$container" 2>/dev/null | grep -o '"NetworkMode":"[^"]*"' | cut -d'"' -f4 || echo "unknown")"
            echo ""
        done
        
        echo "=== DETAILED FINDINGS ==="
        if [[ -f "$VERIFICATION_LOG" ]]; then
            cat "$VERIFICATION_LOG"
        fi
        
    } > "$report_file"
    
    verify_log "INFO" "Verification report generated: $report_file"
    echo "$report_file"
}

# Main verification function
run_container_verification() {
    verify_log "INFO" "Starting comprehensive container security verification..."
    
    init_verification
    check_docker_availability || return 1
    check_container_status
    check_privileged_containers
    check_user_execution
    check_security_options
    check_resource_limits
    check_readonly_filesystem
    check_capability_restrictions
    check_network_isolation
    check_port_bindings
    check_volume_mounts
    check_environment_variables
    check_container_health
    check_container_logs
    check_restart_policy
    
    local report_file=$(generate_verification_report)
    
    verify_log "INFO" "=== CONTAINER VERIFICATION COMPLETE ==="
    verify_log "INFO" "Total checks: $VERIFICATION_CHECKS"
    verify_log "INFO" "Passed: $VERIFICATION_PASSED"
    verify_log "INFO" "Failed: $VERIFICATION_FAILED"
    verify_log "INFO" "Warnings: $VERIFICATION_WARNINGS"
    verify_log "INFO" "Violations: $VERIFICATION_VIOLATIONS"
    verify_log "INFO" "Report: $report_file"
    
    if [[ $VERIFICATION_VIOLATIONS -eq 0 ]]; then
        verify_log "SUCCESS" "Container verification PASSED"
        return 0
    else
        verify_log "ERROR" "Container verification FAILED - $VERIFICATION_VIOLATIONS violations"
        return 1
    fi
}

# Main execution
main() {
    local command="${1:-run}"
    
    case "$command" in
        "run")
            run_container_verification
            ;;
        "status")
            init_verification
            check_docker_availability
            check_container_status
            ;;
        "privileges")
            init_verification
            check_docker_availability
            check_privileged_containers
            ;;
        "user")
            init_verification
            check_docker_availability
            check_user_execution
            ;;
        "security")
            init_verification
            check_docker_availability
            check_security_options
            ;;
        "resources")
            init_verification
            check_docker_availability
            check_resource_limits
            ;;
        "filesystem")
            init_verification
            check_docker_availability
            check_readonly_filesystem
            ;;
        "capabilities")
            init_verification
            check_docker_availability
            check_capability_restrictions
            ;;
        "network")
            init_verification
            check_docker_availability
            check_network_isolation
            ;;
        "ports")
            init_verification
            check_docker_availability
            check_port_bindings
            ;;
        "volumes")
            init_verification
            check_docker_availability
            check_volume_mounts
            ;;
        "environment")
            init_verification
            check_docker_availability
            check_environment_variables
            ;;
        "health")
            init_verification
            check_docker_availability
            check_container_health
            ;;
        "logs")
            init_verification
            check_docker_availability
            check_container_logs
            ;;
        "restart")
            init_verification
            check_docker_availability
            check_restart_policy
            ;;
        "help"|"-h"|"--help")
            echo "Container Security Verification Module"
            echo ""
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  run         Run complete container verification (default)"
            echo "  status      Check container status"
            echo "  privileges  Check for privileged containers"
            echo "  user        Check user execution context"
            echo "  security    Check security options"
            echo "  resources   Check resource limits"
            echo "  filesystem  Check read-only filesystem"
            echo "  capabilities Check capability restrictions"
            echo "  network     Check network isolation"
            echo "  ports       Check port bindings"
            echo "  volumes     Check volume mounts"
            echo "  environment Check environment variables"
            echo "  health      Check container health"
            echo "  logs        Check container logs"
            echo "  restart     Check restart policy"
            echo "  help        Show this help message"
            ;;
        *)
            verify_log "ERROR" "Unknown command: $command"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
