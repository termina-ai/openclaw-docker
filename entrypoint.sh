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
    // Ensure gateway and gateway.auth exist (openclaw doctor/update can drop them)
    if (!cfg.gateway) cfg.gateway = {};
    if (!cfg.gateway.auth) cfg.gateway.auth = {};
    if (process.env.OPENCLAW_GATEWAY_TOKEN) {
      cfg.gateway.auth.mode = 'token';
      cfg.gateway.auth.token = process.env.OPENCLAW_GATEWAY_TOKEN;
    }
    // Docker NAT rewrites the source IP, so the gateway sees connections from
    // Docker's internal network instead of 127.0.0.1. Trust these ranges so
    // the gateway treats them as local.
    cfg.gateway.trustedProxies = ['192.168.65.0/24', '172.16.0.0/12', '10.0.0.0/8'];
    // Device pairing requires the connection to come from localhost, which is
    // impossible through Docker's NAT. Disable it — token auth still applies,
    // and the port is bound to 127.0.0.1 so only this machine can connect.
    if (!cfg.gateway.controlUi) cfg.gateway.controlUi = {};
    cfg.gateway.controlUi.dangerouslyDisableDeviceAuth = true;
    // Onboarding defaults to "messaging" profile which only allows chat.
    // Override to "full" so the agent can edit files, run commands, etc.
    if (!cfg.tools) cfg.tools = {};
    cfg.tools.profile = 'full';
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

# --- Ensure npm global prefix dir exists ---
mkdir -p /home/openclaw/.npm-global

# --- Fix ownership after all root-level modifications ---
# Must run after config patching (which runs as root) so files end up
# owned by the openclaw user, not root. Critical on macOS where
# HOST_UID != 1000 and Docker Desktop's VirtioFS is in play.
chown -R "$HOST_UID:$HOST_GID" /home/openclaw

# --- Browser-extension relay (port 18792) ---
# The browser control server hardcodes its bind to 127.0.0.1, which makes it
# unreachable via Docker's port-forwarding (connections arrive from the bridge
# IP, not loopback). We run a socat relay on an adjacent port (18794) bound to
# 0.0.0.0 that forwards into the loopback listener. docker-compose maps
# host 18792 → container 18794 → socat → 127.0.0.1:18792.
RELAY_PORT="${OPENCLAW_RELAY_PORT:-18792}"
SOCAT_PORT="$((RELAY_PORT + 2))"
gosu openclaw socat \
  TCP-LISTEN:"$SOCAT_PORT",fork,bind=0.0.0.0,reuseaddr \
  TCP:127.0.0.1:"$RELAY_PORT" &

# Drop to openclaw user and exec the CMD
exec gosu openclaw "$@"
