#!/usr/bin/env bash
set -euo pipefail

# Load UX enhancements
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UX_LIB="$PROJECT_ROOT/lib/ux-enhancements.sh"

if [[ -f "$UX_LIB" ]]; then
    source "$UX_LIB"
else
    # Fallback logging if UX library not available
    log() { printf '[%(%F %T)T][start] %s\n' -1 "$*" >> "${LOGFILE:-/tmp/journals-start.log}"; }
fi

LOGFILE="${LOGFILE:-/tmp/journals-start.log}"

IMAGE="${HOME}/JournalsVault.sparseimage"
MOUNTPOINT="${HOME}/Journals"

# Display banner
show_banner "Journals Startup" "1.0"

ux_log "$LOG_INFO" "Starting journals system..."
ux_log "$LOG_INFO" "Using image: ${IMAGE}"
ux_log "$LOG_INFO" "Mountpoint: ${MOUNTPOINT}"

if [[ ! -f "$IMAGE" ]]; then
  show_error "Encrypted image not found at $IMAGE"
  detect_and_recover "vault_not_found"
  exit 1
fi

show_progress_indicator "Preparing vault mount point..."
mkdir -p "$MOUNTPOINT"
chmod 700 "$MOUNTPOINT"
show_success "Mount point prepared: $MOUNTPOINT"

# Detach any previous mounts of this image or mountpoint to avoid 'Resource busy'
show_progress_indicator "Checking for existing mounts..."
EXISTING_DEV="$(hdiutil info | awk -v img="$IMAGE" '
  /image-path/ { ip=$3 }
  $1 ~ "^/dev/disk" { dev=$1 }
  $0 ~ img { print dev }
')"
if [[ -n "${EXISTING_DEV}" ]]; then
  show_warning "Found existing device ${EXISTING_DEV} for image; detaching..."
  hdiutil detach "${EXISTING_DEV}" >/dev/null 2>&1 || true
  show_success "Existing device detached"
fi

if mount | grep -q "on ${MOUNTPOINT} "; then
  show_warning "Mountpoint already in use; detaching ${MOUNTPOINT}..."
  hdiutil detach "${MOUNTPOINT}" >/dev/null 2>&1 || true
  show_success "Existing mount detached"
fi

# Prompt for passphrase
show_question "Enter vault passphrase:"
read -s -p "Vault passphrase: " PASS; echo

show_progress_indicator "Attaching encrypted vault..."
if ! echo -n "$PASS" | hdiutil attach "$IMAGE" -stdinpass -mountpoint "$MOUNTPOINT" -nobrowse >/dev/null 2>&1; then
  show_warning "Attach failed; attempting forced cleanup and retry..."
  DEV_NODE="$(hdiutil info | awk -v mp="${MOUNTPOINT}" '
    /Apple_APFS/ {dev=$1}
    $0 ~ mp {print dev}
  ')"
  if [[ -n "${DEV_NODE}" ]]; then
    show_progress_indicator "Force-detaching ${DEV_NODE}..."
    hdiutil detach -force "${DEV_NODE}" >/dev/null 2>&1 || true
  fi
  show_progress_indicator "Retrying vault attach..."
  echo -n "$PASS" | hdiutil attach "$IMAGE" -stdinpass -mountpoint "$MOUNTPOINT" -nobrowse >/dev/null
fi
show_success "Vault mounted at ${MOUNTPOINT}"

# Disable Spotlight indexing on mount
show_progress_indicator "Disabling Spotlight indexing on vault..."
mdutil -i off "$MOUNTPOINT" >/dev/null 2>&1 || true
show_success "Spotlight indexing disabled"

# Start Ollama if not running
show_progress_indicator "Checking Ollama status..."
if pgrep -x ollama >/dev/null; then
  show_success "Ollama already running"
else
  show_progress_indicator "Starting Ollama service..."
  nohup ollama serve >/tmp/ollama.log 2>&1 &
  sleep 1
  show_success "Ollama started (see /tmp/ollama.log)"
fi

ux_log "$LOG_SUCCESS" "Journals startup completed successfully"
show_completion "Journals System Startup" "Vault mounted and Ollama running"

