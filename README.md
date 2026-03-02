# OpenClaw Docker

Run [OpenClaw](https://openclaw.ai/) in a Docker container with isolated persistent storage.

## Features

- OpenClaw runs completely containerized
- Persistent storage via Docker named volumes (isolated from host filesystem)
- Makefile targets for easy management
- Beta version installed via official installer

## Prerequisites

- Docker
- Docker Compose

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

All OpenClaw data is stored in Docker named volumes:

- `openclaw_state` - Configuration, memory, and credentials (`~/.openclaw` inside container)
- `openclaw_workspace` - Workspace files (`~/workspace` inside container)

These volumes are completely isolated from your host filesystem. OpenClaw cannot access any files outside its container.

To backup your OpenClaw data:

```bash
docker run --rm -v openclaw_state:/data -v $(pwd):/backup alpine tar czf /backup/openclaw_state.tar.gz -C /data .
docker run --rm -v openclaw_workspace:/data -v $(pwd):/backup alpine tar czf /backup/openclaw_workspace.tar.gz -C /data .
```

To restore:

```bash
docker run --rm -v openclaw_state:/data -v $(pwd):/backup alpine tar xzf /backup/openclaw_state.tar.gz -C /data
docker run --rm -v openclaw_workspace:/data -v $(pwd):/backup alpine tar xzf /backup/openclaw_workspace.tar.gz -C /data
```

## Ports

- `18789` - OpenClaw gateway (WebSocket control plane)

## Configuration

Environment variables can be added to `docker-compose.yml` under the `environment` section.
