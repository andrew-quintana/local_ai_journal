#!/usr/bin/env bash
set -euo pipefail

# Load UX enhancements
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UX_LIB="$PROJECT_ROOT/lib/ux-enhancements.sh"

if [[ -f "$UX_LIB" ]]; then
    source "$UX_LIB"
fi

MOUNTPOINT="${HOME}/Journals"

# Display banner
show_banner "Journals Shutdown" "1.0"

if mount | grep -q "on ${MOUNTPOINT} "; then
  show_progress_indicator "Detaching journals vault..."
  
  # Try a normal detach first
  if hdiutil detach "${MOUNTPOINT}" >/dev/null 2>&1; then
    show_success "Vault detached successfully"
    show_completion "Journals Shutdown" "Vault unmounted"
    exit 0
  fi

  show_warning "Normal detach failed; attempting forced detach..."

  # If normal detach fails (resource busy), try to find and force-detach the device
  DEV_NODE="$(hdiutil info | awk -v mp="${MOUNTPOINT}" '
    /Apple_APFS/ {dev=$1}
    $0 ~ mp {print dev}
  ')"

  if [[ -n "${DEV_NODE}" ]]; then
    show_progress_indicator "Force-detaching device ${DEV_NODE}..."
    if hdiutil detach -force "${DEV_NODE}" >/dev/null 2>&1; then
      show_success "Vault detached (forced)"
      show_completion "Journals Shutdown" "Vault unmounted (forced)"
      exit 0
    fi
  fi

  # Fallback: force detach by mountpoint
  show_progress_indicator "Force-detaching by mountpoint..."
  if hdiutil detach -force "${MOUNTPOINT}" >/dev/null 2>&1; then
    show_success "Vault detached (forced by mountpoint)"
    show_completion "Journals Shutdown" "Vault unmounted (forced)"
    exit 0
  fi

  show_error "Could not detach ${MOUNTPOINT}"
  show_info "Close any apps using it (Finder, editors, terminals) and try again"
  show_help "shutdown"
  exit 1
else
  show_info "Vault not mounted"
  show_completion "Journals Shutdown" "No action needed"
fi