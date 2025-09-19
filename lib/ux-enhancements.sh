#!/bin/bash

# UX Enhancements Library for Journals Infrastructure
# Provides colorized output, progress indicators, and user experience improvements

# Color codes
UX_RED='\033[0;31m'
UX_GREEN='\033[0;32m'
UX_YELLOW='\033[1;33m'
UX_BLUE='\033[0;34m'
UX_PURPLE='\033[0;35m'
UX_CYAN='\033[0;36m'
UX_WHITE='\033[1;37m'
UX_NC='\033[0m' # No Color
UX_BOLD='\033[1m'
UX_UNDERLINE='\033[4m'

# Status indicators
UX_SUCCESS="✓"
UX_ERROR="✗"
UX_WARNING="⚠"
UX_INFO="ℹ"
UX_STEP="▶"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")
            echo -e "${UX_RED}[ERROR]${UX_NC} $message" >&2
            ;;
        "WARN")
            echo -e "${UX_YELLOW}[WARN]${UX_NC} $message" >&2
            ;;
        "INFO")
            echo -e "${UX_BLUE}[INFO]${UX_NC} $message"
            ;;
        "SUCCESS")
            echo -e "${UX_GREEN}[SUCCESS]${UX_NC} $message"
            ;;
        "STEP")
            echo -e "${UX_CYAN}[STEP]${UX_NC} $message"
            ;;
        "DEBUG")
            if [[ "${LOG_LEVEL:-}" == "DEBUG" ]]; then
                echo -e "${UX_PURPLE}[DEBUG]${UX_NC} $message"
            fi
            ;;
    esac
}

# Show banner
show_banner() {
    local title="$1"
    local version="$2"
    
    echo -e "${UX_CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║  $title"
    echo "║  Version: $version"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${UX_NC}"
}

# Error handling
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    log "ERROR" "$message"
    exit "$exit_code"
}

# Progress indicator
show_progress() {
    local message="$1"
    local duration="${2:-3}"
    
    echo -n "$message"
    for i in $(seq 1 "$duration"); do
        echo -n "."
        sleep 1
    done
    echo " Done!"
}

# Success message
show_success() {
    local message="$1"
    echo -e "${UX_GREEN}${UX_SUCCESS}${UX_NC} $message"
}

# Error message
show_error() {
    local message="$1"
    echo -e "${UX_RED}${UX_ERROR}${UX_NC} $message"
}

# Warning message
show_warning() {
    local message="$1"
    echo -e "${UX_YELLOW}${UX_WARNING}${UX_NC} $message"
}

# Info message
show_info() {
    local message="$1"
    echo -e "${UX_BLUE}${UX_INFO}${UX_NC} $message"
}

# Function to display completion message
show_completion() {
    local title="$1"
    local duration="$2"
    local line="═"
    local padding_length=$(( (58 - ${#title} - ${#duration} - 9) / 2 )) # 9 for " in " and spaces
    local padding=$(printf '%*s' "$padding_length" '' | tr ' ' "$line")

    echo -e "${UX_GREEN}${UX_BOLD}"
    echo "╔$(printf '%*s' 60 '' | tr ' ' "$line")╗"
    echo "║$(printf '%*s' 60 '')║"
    echo "║  ${title}${UX_NC}${UX_GREEN} completed in ${duration}$(printf '%*s' $((60 - ${#title} - ${#duration} - 15)) '')║"
    echo "║$(printf '%*s' 60 '')║"
    echo "╚$(printf '%*s' 60 '' | tr ' ' "$line")╝"
    echo -e "${UX_NC}"
}