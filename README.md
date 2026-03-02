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

## Setup Prompts

Start by answering all its onboarding questions: what it should call you, what it's called, what tone you prefer

```Download this skill: https://github.com/blader/humanizer. When you write content for me, whether its messages, emails, essays, or more, run the content through this skill to make it sound less AI-written.
```

```
Add this into our SKILLS.md file for all tasks:
## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution
- Use the right model for subagents: thinking and pro models tend to perform better on research tasks vs agentic models like codex or opus

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management
1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles
- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
```

## Starter Prompts
- "Help me set up google calendar access"

- "Scrape my last 500 outgoing emails/telegram messages and summarize my voice and tone habits into a prompt that you commit to your memory. Use that prompt any time you draft something that's coming from me"

- "Help me categorize all my contacts over the last 5 years into a few buckets based on email conversation history, their LinkedIn bio, and Affinity tags. Buckets are LP, Investor, Startup, Portfolio, Portfolio Support, Misc."