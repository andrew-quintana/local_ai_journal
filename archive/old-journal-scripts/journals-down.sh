#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="$HOME/journals-docker/docker-compose.yml"

if [[ -f "$COMPOSE_FILE" ]]; then
  docker compose -f "$COMPOSE_FILE" down
else
  echo "Compose file not found at $COMPOSE_FILE — skipping docker down"
fi

# Lock the vault
exec "$HOME/bin/journals-stop.sh"