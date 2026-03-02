#!/bin/bash
set -e

CONFIG="/home/openclaw/.openclaw/openclaw.json"
SEED="/home/openclaw/.openclaw-seed"

# --- Match host UID/GID ---
# Remap the openclaw user to the host user's UID/GID so bind-mounted files
# are owned by the same user on both sides.
HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"
if [ "$(id -u openclaw)" != "$HOST_UID" ] || [ "$(id -g openclaw)" != "$HOST_GID" ]; then
  groupmod -o -g "$HOST_GID" openclaw 2>/dev/null || true
  usermod -o -u "$HOST_UID" -g "$HOST_GID" openclaw
  chown -R "$HOST_UID:$HOST_GID" /home/openclaw
fi

# --- First-run seed ---
# Bind mounts start empty; copy the baked config from the image seed.
if [ ! -f "$CONFIG" ] && [ -d "$SEED" ]; then
  cp -a "$SEED"/. /home/openclaw/.openclaw/
  chown -R "$HOST_UID:$HOST_GID" /home/openclaw/.openclaw
fi

# --- Patch config on every start ---
if [ -f "$CONFIG" ]; then
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('$CONFIG', 'utf8'));
    // Inject gateway token from env
    if (process.env.OPENCLAW_GATEWAY_TOKEN) {
      cfg.gateway.auth.token = process.env.OPENCLAW_GATEWAY_TOKEN;
    }
    // Trust Docker NAT ranges so allowInsecureAuth can bypass device pairing
    // See: https://github.com/openclaw/openclaw/issues/6959
    cfg.gateway.trustedProxies = ['192.168.65.0/24', '172.16.0.0/12', '10.0.0.0/8'];
    fs.writeFileSync('$CONFIG', JSON.stringify(cfg, null, 2) + '\n');
  "
fi

# API keys (ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.) are picked up
# directly from the environment by the provider SDKs. No patching needed.

# Drop to openclaw user and exec the CMD
exec gosu openclaw "$@"
