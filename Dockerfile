FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash openclaw

# Install OpenClaw beta (tolerate post-install interactive onboarding failure)
RUN curl -fsSL https://openclaw.ai/install.sh | bash -s -- --beta || true

ENV PATH="/usr/local/bin:/home/openclaw/.local/bin:/home/openclaw/.openclaw/bin:${PATH}"

RUN openclaw --version

# Set up directories and ownership
RUN mkdir -p /home/openclaw/.openclaw /home/openclaw/workspace \
    && chown -R openclaw:openclaw /home/openclaw

# Copy entrypoint (runs as root, fixes permissions, then drops to openclaw user)
COPY --chmod=755 entrypoint.sh /opt/openclaw/entrypoint.sh
# Strip Windows line endings if present (fixes "no such file or directory" exec errors)
RUN sed -i 's/\r$//' /opt/openclaw/entrypoint.sh

USER openclaw
WORKDIR /home/openclaw

# Run non-interactive onboarding to generate a complete, schema-valid config.
# NO secrets here — only structural/non-sensitive settings.
# The entrypoint injects secrets from env vars on every container start.
RUN openclaw onboard --non-interactive \
    --accept-risk \
    --mode local \
    --gateway-port 18789 \
    --gateway-bind lan \
    --gateway-auth token \
    --gateway-token onboard-placeholder \
    --auth-choice skip \
    --workspace /home/openclaw/workspace \
    --no-install-daemon \
    --skip-channels \
    --skip-skills \
    --skip-health \
    --skip-ui

# Docker-specific: allow token auth over plain HTTP from Docker's network
RUN openclaw config set gateway.controlUi.enabled true \
    && openclaw config set gateway.controlUi.allowInsecureAuth true

# Fix permissions and create credentials dir
RUN chmod 700 /home/openclaw/.openclaw \
    && mkdir -p /home/openclaw/.openclaw/credentials

# Run doctor to fix any remaining issues
RUN openclaw doctor --non-interactive --repair || true

# Save baked config as a seed — bind mounts shadow .openclaw with an empty dir,
# so the entrypoint copies this seed on first run.
RUN cp -a /home/openclaw/.openclaw /home/openclaw/.openclaw-seed

# Switch back to root — entrypoint fixes bind mount permissions then drops to openclaw via gosu
USER root

EXPOSE 18789

ENTRYPOINT ["/opt/openclaw/entrypoint.sh"]
CMD ["openclaw", "gateway", "run", "--port", "18789"]
