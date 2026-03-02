#!/bin/bash
set -e

CONFIG="/home/openclaw/.openclaw/openclaw.json"

# --- Fix volume ownership ---
# Ensure the openclaw user owns everything in its home directory.
# The workspace bind mount may be owned by the host user's UID,
# and the state volume may have files created by root.
chown -R openclaw:openclaw /home/openclaw/.openclaw /home/openclaw/workspace

# --- Gateway token ---
# Workaround for https://github.com/openclaw/openclaw/issues/2205
if [ -n "$OPENCLAW_GATEWAY_TOKEN" ] && [ -f "$CONFIG" ]; then
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('$CONFIG', 'utf8'));
    cfg.gateway.auth.token = process.env.OPENCLAW_GATEWAY_TOKEN;
    fs.writeFileSync('$CONFIG', JSON.stringify(cfg, null, 2) + '\n');
  "
fi

# API keys (ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.) are picked up
# directly from the environment by the provider SDKs. No patching needed.

# Drop to openclaw user and exec the CMD
exec gosu openclaw "$@"
