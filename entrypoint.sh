#!/bin/bash
set -e

CONFIG="/home/openclaw/.openclaw/openclaw.json"

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
    fs.writeFileSync('$CONFIG', JSON.stringify(cfg, null, 2) + '\n');
  "
fi

# Drop to openclaw user and exec the CMD
exec gosu openclaw "$@"
