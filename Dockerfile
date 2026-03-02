FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    gosu \
    jq \
    wget \
    unzip \
    zip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    sed \
    gawk \
    grep \
    findutils \
    coreutils \
    diffutils \
    patch \
    less \
    tree \
    file \
    bc \
    vim-tiny \
    nano \
    openssh-client \
    rsync \
    httpie \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 (required by OpenClaw)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash openclaw

# Install OpenClaw via npm (bypasses openclaw.ai install script)
RUN npm install -g openclaw@latest

ENV HOME=/home/openclaw
ENV PATH="/usr/local/bin:/home/openclaw/.local/bin:/home/openclaw/.openclaw/bin:${PATH}"

RUN openclaw --version

# Set up directories and ownership
RUN mkdir -p /home/openclaw/.openclaw /home/openclaw/workspaces/main \
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
    --workspace /home/openclaw/workspaces/main \
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

# Save baked config as seed — bind mount starts empty, entrypoint copies on first run
RUN cp -a /home/openclaw/.openclaw /home/openclaw/.openclaw-seed

# Switch back to root — entrypoint fixes bind mount permissions then drops to openclaw via gosu
USER root

EXPOSE 18789

ENTRYPOINT ["/opt/openclaw/entrypoint.sh"]
CMD ["openclaw", "gateway", "run", "--port", "18789"]
