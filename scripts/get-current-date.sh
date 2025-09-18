#!/usr/bin/env bash
# get-current-date.sh - Get current date in various formats
# 
# This script demonstrates the rule: Always use CLI to get the current date
# instead of hardcoding date values in scripts and documentation.
#
# Usage: ./get-current-date.sh [format]
# Formats: iso, short, long, timestamp, year, month, day

# Get current date from CLI
CURRENT_DATE=$(date '+%Y-%m-%d')
CURRENT_YEAR=$(date '+%Y')
CURRENT_MONTH=$(date '+%m')
CURRENT_DAY=$(date '+%d')
CURRENT_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Function to show different date formats
show_date() {
    local format="${1:-iso}"
    
    case "$format" in
        "iso")
            echo "$CURRENT_DATE"
            ;;
        "short")
            date '+%m/%d/%Y'
            ;;
        "long")
            date '+%B %d, %Y'
            ;;
        "timestamp")
            echo "$CURRENT_TIMESTAMP"
            ;;
        "year")
            echo "$CURRENT_YEAR"
            ;;
        "month")
            echo "$CURRENT_MONTH"
            ;;
        "day")
            echo "$CURRENT_DAY"
            ;;
        *)
            echo "Usage: $0 [iso|short|long|timestamp|year|month|day]"
            echo "Current date (ISO): $CURRENT_DATE"
            ;;
    esac
}

# Show current date information
echo "=== Current Date Information ==="
echo "ISO Format: $CURRENT_DATE"
echo "Short Format: $(date '+%m/%d/%Y')"
echo "Long Format: $(date '+%B %d, %Y')"
echo "Timestamp: $CURRENT_TIMESTAMP"
echo "Year: $CURRENT_YEAR"
echo "Month: $CURRENT_MONTH"
echo "Day: $CURRENT_DAY"
echo
echo "=== Rule: Always use CLI for dates ==="
echo "❌ Don't hardcode: Date: 2025-01-18"
echo "✅ Use CLI: Date: \$(date '+%Y-%m-%d')"
echo "✅ Result: Date: $CURRENT_DATE"

# Show requested format if provided
if [[ $# -gt 0 ]]; then
    echo
    echo "Requested format ($1): $(show_date "$1")"
fi
