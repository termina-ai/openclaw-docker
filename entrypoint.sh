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

# --- Patch config on every start ---
if [ -f "$CONFIG" ]; then
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('$CONFIG', 'utf8'));
    if (process.env.OPENCLAW_GATEWAY_TOKEN) {
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
    cfg.gateway.controlUi.allowedOrigins = ['http://localhost:18789', 'http://127.0.0.1:18789'];
    // Onboarding defaults to "messaging" profile which only allows chat.
    // Override to "full" so the agent can edit files, run commands, etc.
    if (!cfg.tools) cfg.tools = {};
    cfg.tools.profile = 'full';
    fs.writeFileSync('$CONFIG', JSON.stringify(cfg, null, 2) + '\n');
  "
fi

# Drop to openclaw user and exec the CMD
exec gosu openclaw "$@"
