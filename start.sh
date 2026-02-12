#!/bin/bash
# OneClaw startup script
# Waits for config file and runs doctor --fix in background
# NOTE: Skip doctor --fix when auto-config env vars are present,
# because server.js auto-config handles doctor --fix itself.
# Running both concurrently causes a race condition where
# concurrent writes to openclaw.json corrupt the config.

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
OPENCLAW_CMD="node /usr/local/lib/node_modules/openclaw/dist/entry.js"

# Configure browser automation: use openclaw's managed browser profile
# This avoids Chrome Relay dependency and provides a fully controlled headless browser
configure_browser() {
  echo "[start.sh] Configuring browser: defaultProfile=openclaw"
  $OPENCLAW_CMD config set browser.defaultProfile openclaw 2>/dev/null || true
}

# Check if auto-config will handle doctor --fix
# Auto-config runs when ANY AI API key env var is set
HAS_AUTO_CONFIG_KEYS=false
if [ -n "$ANTHROPIC_API_KEY" ] || [ -n "$OPENAI_API_KEY" ] || [ -n "$GOOGLE_GENERATIVE_AI_API_KEY" ] || [ -n "$DEEPSEEK_API_KEY" ] || [ -n "$OPENROUTER_API_KEY" ]; then
  HAS_AUTO_CONFIG_KEYS=true
fi

# Background task: wait for config and run doctor --fix
# Only for existing instances (no auto-config env vars) or pre-configured instances
if [ "$HAS_AUTO_CONFIG_KEYS" = "false" ]; then
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

        configure_browser
        break
      fi
      sleep 1
    done
  ) &
else
  echo "[start.sh] Auto-config env vars detected, skipping background doctor --fix (server.js handles it)"
  # Configure browser after a delay to let auto-config create the config file first
  (
    sleep 15
    configure_browser
  ) &
fi

# Start the main server (foreground)
echo "[start.sh] Starting server..."
exec node src/server.js
