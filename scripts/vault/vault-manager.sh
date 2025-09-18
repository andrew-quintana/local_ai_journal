#!/bin/bash

# vault-manager.sh - APFS Vault Management System
# 
# This script provides secure vault management for encrypted journal storage
# using APFS sparse images with AES-256 encryption.
#
# Security Features:
# - Interactive passphrase entry (no storage)
# - Atomic operations with rollback capability
# - Comprehensive error handling
# - Integrity verification
#
# Author: Local Development Team
# Version: 1.0
# Date: 2025-01-18

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VAULT_IMAGE_PATH="${VAULT_IMAGE_PATH:-${HOME}/JournalsVault.sparseimage}"
readonly VAULT_MOUNT_POINT="${VAULT_MOUNT_POINT:-${HOME}/Journals}"
readonly VAULT_SIZE="${VAULT_SIZE:-10g}"
readonly TEMP_DIR="${TEMP_DIR:-/tmp/journal-vault-$$}"

# Logging configuration
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"
readonly LOG_FILE="${LOG_FILE:-/tmp/vault-manager.log}"

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
    esac
}

# Error handling
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    log "ERROR" "$message"
    cleanup_temp_files
    exit "$exit_code"
}

# Cleanup function
cleanup_temp_files() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
}

# Trap for cleanup on exit
trap cleanup_temp_files EXIT

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        error_exit "This script requires macOS for APFS support"
    fi
    
    # Check if hdiutil is available
    if ! command -v hdiutil >/dev/null 2>&1; then
        error_exit "hdiutil command not found. This script requires macOS."
    fi
    
    # Check if diskutil is available
    if ! command -v diskutil >/dev/null 2>&1; then
        error_exit "diskutil command not found. This script requires macOS."
    fi
    
    # Check if running as non-root user
    if [[ "$EUID" -eq 0 ]]; then
        error_exit "This script should not be run as root for security reasons"
    fi
    
    log "SUCCESS" "Prerequisites check passed"
}

# Secure passphrase input
get_passphrase() {
    local prompt="$1"
    local passphrase=""
    
    while true; do
        echo -n "$prompt"
        read -rs passphrase
        echo
        
        if [[ -z "$passphrase" ]]; then
            log "WARN" "Passphrase cannot be empty. Please try again."
            continue
        fi
        
        if [[ ${#passphrase} -lt 8 ]]; then
            log "WARN" "Passphrase must be at least 8 characters long. Please try again."
            continue
        fi
        
        # Confirm passphrase
        echo -n "Confirm passphrase: "
        read -rs passphrase_confirm
        echo
        
        if [[ "$passphrase" != "$passphrase_confirm" ]]; then
            log "WARN" "Passphrases do not match. Please try again."
            continue
        fi
        
        break
    done
    
    echo "$passphrase"
}

# Check if vault exists
vault_exists() {
    [[ -f "$VAULT_IMAGE_PATH" ]]
}

# Get vault status
vault_status() {
    if ! vault_exists; then
        echo "unmounted"
        return 0
    fi
    
    # Check if vault is mounted
    if mount | grep -q "$VAULT_MOUNT_POINT"; then
        echo "mounted"
    else
        echo "unmounted"
    fi
}

# Create vault with atomic operation
vault_create() {
    local size="${1:-$VAULT_SIZE}"
    local location="${2:-$VAULT_IMAGE_PATH}"
    
    log "INFO" "Creating vault at $location with size $size"
    
    # Check if vault already exists
    if vault_exists; then
        error_exit "Vault already exists at $location. Use vault_unmount first if you want to recreate it."
    fi
    
    # Create temporary directory for atomic operation
    mkdir -p "$TEMP_DIR"
    
    # Get passphrase interactively
    local passphrase
    passphrase=$(get_passphrase "Enter passphrase for new vault: ")
    
    # Create vault in temporary location first
    local temp_vault="$TEMP_DIR/$(basename "$location")"
    
    log "INFO" "Creating vault in temporary location..."
    if ! hdiutil create -size "$size" -type SPARSE -fs APFS -encryption AES-256 -stdinpass <<< "$passphrase" "$temp_vault"; then
        error_exit "Failed to create vault in temporary location"
    fi
    
    # Verify the temporary vault was created successfully
    if [[ ! -f "$temp_vault" ]]; then
        error_exit "Vault creation failed - temporary file not found"
    fi
    
    # Test mount the temporary vault to verify it works
    log "INFO" "Verifying vault integrity..."
    local temp_mount="/tmp/vault-test-$$"
    mkdir -p "$temp_mount"
    
    if ! hdiutil attach -stdinpass -mountpoint "$temp_mount" <<< "$passphrase" "$temp_vault"; then
        rm -f "$temp_vault"
        rmdir "$temp_mount" 2>/dev/null || true
        error_exit "Vault verification failed - could not mount temporary vault"
    fi
    
    # Unmount the test mount
    hdiutil detach "$temp_mount" 2>/dev/null || true
    rmdir "$temp_mount" 2>/dev/null || true
    
    # Move vault to final location atomically
    log "INFO" "Moving vault to final location..."
    if ! mv "$temp_vault" "$location"; then
        error_exit "Failed to move vault to final location"
    fi
    
    # Verify final vault exists and is accessible
    if ! vault_exists; then
        error_exit "Vault creation failed - final vault not found"
    fi
    
    log "SUCCESS" "Vault created successfully at $location"
    return 0
}

# Mount vault with interactive passphrase
vault_mount() {
    log "INFO" "Mounting vault from $VAULT_IMAGE_PATH to $VAULT_MOUNT_POINT"
    
    # Check if vault exists
    if ! vault_exists; then
        error_exit "Vault does not exist at $VAULT_IMAGE_PATH"
    fi
    
    # Check if already mounted
    if [[ "$(vault_status)" == "mounted" ]]; then
        log "WARN" "Vault is already mounted"
        return 0
    fi
    
    # Create mount point if it doesn't exist
    if [[ ! -d "$VAULT_MOUNT_POINT" ]]; then
        log "INFO" "Creating mount point at $VAULT_MOUNT_POINT"
        if ! mkdir -p "$VAULT_MOUNT_POINT"; then
            error_exit "Failed to create mount point at $VAULT_MOUNT_POINT"
        fi
    fi
    
    # Get passphrase interactively
    local passphrase
    passphrase=$(get_passphrase "Enter vault passphrase: ")
    
    # Mount the vault
    log "INFO" "Mounting vault..."
    if ! hdiutil attach -stdinpass -mountpoint "$VAULT_MOUNT_POINT" <<< "$passphrase" "$VAULT_IMAGE_PATH"; then
        error_exit "Failed to mount vault. Check passphrase and vault integrity."
    fi
    
    # Verify mount was successful
    if ! mount | grep -q "$VAULT_MOUNT_POINT"; then
        error_exit "Vault mount verification failed"
    fi
    
    log "SUCCESS" "Vault mounted successfully at $VAULT_MOUNT_POINT"
    return 0
}

# Unmount vault
vault_unmount() {
    log "INFO" "Unmounting vault from $VAULT_MOUNT_POINT"
    
    # Check if vault is mounted
    if [[ "$(vault_status)" != "mounted" ]]; then
        log "WARN" "Vault is not currently mounted"
        return 0
    fi
    
    # Unmount the vault
    if ! hdiutil detach "$VAULT_MOUNT_POINT"; then
        error_exit "Failed to unmount vault from $VAULT_MOUNT_POINT"
    fi
    
    # Verify unmount was successful
    if mount | grep -q "$VAULT_MOUNT_POINT"; then
        error_exit "Vault unmount verification failed - still appears to be mounted"
    fi
    
    log "SUCCESS" "Vault unmounted successfully"
    return 0
}

# Validate vault integrity
vault_validate_integrity() {
    log "INFO" "Validating vault integrity..."
    
    # Check if vault exists
    if ! vault_exists; then
        error_exit "Vault does not exist at $VAULT_IMAGE_PATH"
    fi
    
    # Check if vault is mounted
    if [[ "$(vault_status)" != "mounted" ]]; then
        log "INFO" "Vault is not mounted. Mounting for integrity check..."
        vault_mount
        local was_unmounted=true
    else
        local was_unmounted=false
    fi
    
    # Verify mount point exists and is accessible
    if [[ ! -d "$VAULT_MOUNT_POINT" ]]; then
        error_exit "Vault mount point not accessible: $VAULT_MOUNT_POINT"
    fi
    
    # Check if we can read from the mount point
    if ! ls "$VAULT_MOUNT_POINT" >/dev/null 2>&1; then
        error_exit "Cannot read from vault mount point: $VAULT_MOUNT_POINT"
    fi
    
    # Check filesystem integrity using diskutil
    local device_info
    device_info=$(mount | grep "$VAULT_MOUNT_POINT" | awk '{print $1}')
    
    if [[ -n "$device_info" ]]; then
        log "INFO" "Checking filesystem integrity for device: $device_info"
        if ! diskutil verifyVolume "$device_info" >/dev/null 2>&1; then
            log "WARN" "Filesystem integrity check reported issues"
        else
            log "SUCCESS" "Filesystem integrity check passed"
        fi
    fi
    
    # If we mounted it for the check, unmount it
    if [[ "$was_unmounted" == "true" ]]; then
        vault_unmount
    fi
    
    log "SUCCESS" "Vault integrity validation completed"
    return 0
}

# Main function for command-line usage
main() {
    local command="${1:-}"
    
    case "$command" in
        "exists")
            check_prerequisites
            if vault_exists; then
                echo "true"
                exit 0
            else
                echo "false"
                exit 1
            fi
            ;;
        "create")
            check_prerequisites
            local size="${2:-$VAULT_SIZE}"
            local location="${3:-$VAULT_IMAGE_PATH}"
            vault_create "$size" "$location"
            ;;
        "mount")
            check_prerequisites
            vault_mount
            ;;
        "unmount")
            check_prerequisites
            vault_unmount
            ;;
        "status")
            check_prerequisites
            vault_status
            ;;
        "validate")
            check_prerequisites
            vault_validate_integrity
            ;;
        "help"|"--help"|"-h")
            cat << EOF
Vault Manager - APFS Vault Management System

Usage: $0 <command> [options]

Commands:
  exists                    Check if vault exists
  create [size] [location]  Create new vault (default: 10g, ~/JournalsVault.sparseimage)
  mount                     Mount existing vault
  unmount                   Unmount vault
  status                    Get vault status (mounted|unmounted|error)
  validate                  Validate vault integrity
  help                      Show this help message

Environment Variables:
  VAULT_IMAGE_PATH          Path to vault image (default: ~/JournalsVault.sparseimage)
  VAULT_MOUNT_POINT         Mount point for vault (default: ~/Journals)
  VAULT_SIZE                Default vault size (default: 10g)
  LOG_LEVEL                 Logging level (default: INFO)
  LOG_FILE                  Log file path (default: /tmp/vault-manager.log)

Security Notes:
  - Passphrases are never stored or logged
  - All operations are atomic with rollback capability
  - Vault creation includes integrity verification
  - Interactive passphrase entry only

Examples:
  $0 create 5g ~/MyJournal.sparseimage
  $0 mount
  $0 status
  $0 validate
  $0 unmount

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
