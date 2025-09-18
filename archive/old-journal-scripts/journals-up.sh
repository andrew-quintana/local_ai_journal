#!/usr/bin/env bash
set -euo pipefail

# 1) Unlock + mount your APFS vault (prompts interactively)
~/bin/journals-start.sh

# 2) Start the stack
cd "$(dirname "$0")"
docker compose up -d

# 3) Pull or ensure a model exists (first run)
if ! docker exec journals-ollama ollama list 2>/dev/null | grep -q 'llama3.1:8b'; then
  echo "Pulling llama3.1:8b into Ollama container..."
  docker exec journals-ollama ollama pull llama3.1:8b
fi

echo "Open WebUI → http://localhost:8080"
echo "Your journals are mounted read-only at /journals inside WebUI."