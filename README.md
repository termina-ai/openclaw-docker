# OpenClaw Docker

Run [OpenClaw](https://openclaw.ai/) in a Docker container with isolated persistent storage.

## Features

- OpenClaw runs completely containerized
- Persistent storage via Docker named volumes (isolated from host filesystem)
- Makefile targets for easy management
- Beta version installed via official installer

## Prerequisites

- **Docker Engine** (v20.10+)
- **Docker Buildx** — required for `COPY --chmod`. Install via `docker buildx install` or see [docs](https://docs.docker.com/build/buildx/install/)
- **Docker BuildKit** — must be enabled. Set `export DOCKER_BUILDKIT=1` or add `{ "features": { "buildkit": true } }` to your Docker daemon config. See [docs](https://docs.docker.com/go/buildkit/)
- **Docker Compose** (v2 recommended, v1 works)
- **Make** (optional — you can run the `docker compose` commands directly)
- An API key for at least one supported model provider (Anthropic, OpenAI, or OpenRouter)

## Quick Start

```bash
# Build the image
make build

# Run onboarding wizard (first time setup)
make onboard

# Start the gateway
make up

# Check status
make status
```

## Usage

### Starting and Stopping

```bash
make up          # Start in background
make up-fg       # Start in foreground (see logs)
make down        # Stop
make restart     # Restart
```

### Interacting with OpenClaw

```bash
make cli         # Interactive CLI session
make onboard     # Run onboarding wizard
make status      # Check status
make doctor      # Run diagnostics
make dashboard   # Get dashboard URL
```

### Running Arbitrary Commands

```bash
make cmd ARGS="chat"
make cmd ARGS="config show"
```

### Logs and Debugging

```bash
make logs        # Follow logs
make logs-tail   # Last 100 lines
make shell       # Bash shell in container
```

### Cleanup

```bash
make clean       # Remove containers and volumes (destroys data)
make clean-all   # Also remove Docker images
```

## Storage

All OpenClaw data is bind-mounted from `./openclaw-data/` on the host to `~/.openclaw` inside the container. This single directory contains everything:

- `openclaw.json` — central configuration
- `workspace/` — shared workspace root
- `workspace/agents-workspaces/<id>/` — per-agent workspaces
- `memory/` — LanceDB memory database
- `credentials/` — stored credentials
- `skills/` — installed skills

Because it's a bind mount, you can browse and back up agent workspaces directly from the host:

```bash
ls ./openclaw-data/workspace/agents-workspaces/
```

## Ports

- `18789` - OpenClaw gateway (WebSocket control plane)

## Configuration

Copy `.env.example` to `.env` and fill in your API keys:

```bash
cp .env.example .env
```
