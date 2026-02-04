#!/bin/bash
# OneClaw startup script
# Waits for config file and runs doctor --fix in background

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
OPENCLAW_CMD="node /usr/local/lib/node_modules/openclaw/dist/entry.js"

# Background task: wait for config and run doctor --fix
(
  echo "[start.sh] Waiting for config file to be created..."

  # Wait up to 60 seconds for config file
  for i in {1..60}; do
    if [ -f "$CONFIG_FILE" ]; then
      echo "[start.sh] Config file found, waiting 5s for completion..."
      sleep 5

      echo "[start.sh] Running openclaw doctor --fix..."
      $OPENCLAW_CMD doctor --fix
      echo "[start.sh] doctor --fix completed with exit code: $?"

      break
    fi
    sleep 1
  done
) &

# Start the main server (foreground)
echo "[start.sh] Starting server..."
exec node src/server.js
