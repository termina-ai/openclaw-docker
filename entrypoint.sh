#!/bin/bash
set -e

CONFIG="/home/openclaw/.openclaw/openclaw.json"
SEED="/home/openclaw/.openclaw-seed"

# --- First-run seed ---
# Bind mount starts empty; copy baked config from the image.
if [ ! -f "$CONFIG" ] && [ -d "$SEED" ]; then
  cp -a "$SEED"/. /home/openclaw/.openclaw/
fi

# --- Match host UID/GID ---
# Remap the openclaw user to the host user's UID/GID so bind-mounted
# workspace files are owned by the same user on both sides.
HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"
if [ "$(id -u openclaw)" != "$HOST_UID" ] || [ "$(id -g openclaw)" != "$HOST_GID" ]; then
  groupmod -o -g "$HOST_GID" openclaw 2>/dev/null || true
  usermod -o -u "$HOST_UID" -g "$HOST_GID" openclaw
  chown -R "$HOST_UID:$HOST_GID" /home/openclaw
fi

# --- Auto-detect model from available API keys ---
# If OPENCLAW_MODEL is not explicitly set, pick based on which provider key exists.
if [ -z "$OPENCLAW_MODEL" ]; then
  if [ -n "$ANTHROPIC_API_KEY" ]; then
    OPENCLAW_MODEL="${ANTHROPIC_DEFAULT_MODEL:-anthropic/claude-opus-4-6}"
  elif [ -n "$OPENAI_API_KEY" ]; then
    OPENCLAW_MODEL="${OPENAI_DEFAULT_MODEL:-openai/gpt-5.2}"
  fi
fi

# --- Patch config on every start ---
if [ -f "$CONFIG" ]; then
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('$CONFIG', 'utf8'));
    if (process.env.OPENCLAW_GATEWAY_TOKEN) {
      cfg.gateway.auth.token = process.env.OPENCLAW_GATEWAY_TOKEN;
    }
    // Docker: skip device pairing — browser connects from bridge IP, not loopback
    if (!cfg.gateway.controlUi) cfg.gateway.controlUi = {};
    cfg.gateway.controlUi.dangerouslyDisableDeviceAuth = true;
    // Allow both http and https origins (macOS browsers may auto-upgrade to https)
    const port = (cfg.gateway && cfg.gateway.port) || 18789;
    cfg.gateway.controlUi.allowedOrigins = [
      'http://localhost:' + port,
      'http://127.0.0.1:' + port,
      'https://localhost:' + port,
      'https://127.0.0.1:' + port,
    ];
    // Enable reasoning/thinking by default for all models that support it
    if (!cfg.agents) cfg.agents = {};
    if (!cfg.agents.defaults) cfg.agents.defaults = {};
    cfg.agents.defaults.thinkingDefault = process.env.OPENCLAW_THINKING_DEFAULT || 'adaptive';
    fs.writeFileSync('$CONFIG', JSON.stringify(cfg, null, 2) + '\n');
  "
fi

# --- Set default model via CLI ---
if [ -n "$OPENCLAW_MODEL" ]; then
  gosu openclaw openclaw models set "$OPENCLAW_MODEL" 2>/dev/null || true
fi

# Drop to openclaw user and exec the CMD
exec gosu openclaw "$@"
