#!/usr/bin/env bash
set -euo pipefail

LOGFILE="${LOGFILE:-/tmp/journals-start.log}"
log() { printf '[%(%F %T)T][start] %s\n' -1 "$*" >> "$LOGFILE"; }

IMAGE="${HOME}/JournalsVault.sparseimage"
MOUNTPOINT="${HOME}/Journals"

log "===== journals-start.sh begin ====="
log "Using image: ${IMAGE}"
log "Mountpoint: ${MOUNTPOINT}"

if [[ ! -f "$IMAGE" ]]; then
  log "Encrypted image not found at $IMAGE"
  echo "Create with: hdiutil create -type SPARSE -fs APFS -encryption AES-256 -volname JournalsVault -size 5g ${IMAGE}"
  exit 1
fi

mkdir -p "$MOUNTPOINT"
chmod 700 "$MOUNTPOINT"

# Detach any previous mounts of this image or mountpoint to avoid 'Resource busy'
EXISTING_DEV="$(hdiutil info | awk -v img="$IMAGE" '
  /image-path/ { ip=$3 }
  $1 ~ "^/dev/disk" { dev=$1 }
  $0 ~ img { print dev }
')"
if [[ -n "${EXISTING_DEV}" ]]; then
  log "Found existing device ${EXISTING_DEV} for image; detaching..."
  hdiutil detach "${EXISTING_DEV}" >/dev/null 2>&1 || true
fi

if mount | grep -q "on ${MOUNTPOINT} "; then
  log "Mountpoint already in use; detaching ${MOUNTPOINT}..."
  hdiutil detach "${MOUNTPOINT}" >/dev/null 2>&1 || true
fi

# Prompt for passphrase
read -s -p "Vault passphrase: " PASS; echo

log "Attaching image..."
if ! echo -n "$PASS" | hdiutil attach "$IMAGE" -stdinpass -mountpoint "$MOUNTPOINT" -nobrowse >/dev/null 2>&1; then
  log "Attach failed; attempting forced cleanup and retry..."
  DEV_NODE="$(hdiutil info | awk -v mp="${MOUNTPOINT}" '
    /Apple_APFS/ {dev=$1}
    $0 ~ mp {print dev}
  ')"
  if [[ -n "${DEV_NODE}" ]]; then
    log "Force-detaching ${DEV_NODE}..."
    hdiutil detach -force "${DEV_NODE}" >/dev/null 2>&1 || true
  fi
  log "Retrying attach..."
  echo -n "$PASS" | hdiutil attach "$IMAGE" -stdinpass -mountpoint "$MOUNTPOINT" -nobrowse >/dev/null
fi
log "Mounted at ${MOUNTPOINT}"

# Disable Spotlight indexing on mount
mdutil -i off "$MOUNTPOINT" >/dev/null 2>&1 || true

# Start Ollama if not running
if pgrep -x ollama >/dev/null; then
  log "Ollama already running."
else
  log "Starting Ollama..."
  nohup ollama serve >/tmp/ollama.log 2>&1 &
  sleep 1
  log "Ollama started (see /tmp/ollama.log)."
fi

log "===== journals-start.sh done ====="
echo "Journals mounted at ${MOUNTPOINT} and Ollama is running."

