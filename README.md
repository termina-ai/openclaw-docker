# OpenClaw Docker

Run [OpenClaw](https://openclaw.ai/) in Docker — from zero to a running gateway in 5 steps.

## Quickstart

### 1. Install prerequisites

- [Docker](https://docs.docker.com/get-docker/) (includes Compose)
- [Git](https://git-scm.com/)

**macOS one-liner:** `brew install --cask docker && brew install git`

### 2. Clone the repo

```bash
git clone https://github.com/termina-ai/openclaw-docker.git
cd openclaw-docker
```

### 3. Initialize

```bash
make init        # creates .env and generates a gateway token
```

### 4. Add your API keys

**Already have API keys?** Edit `.env` and paste them in, then skip to step 5.

```bash
nano .env        # or use your preferred editor
```

You only need **one** of these:

- [Anthropic API key](https://console.anthropic.com/)
- [OpenAI API key](https://platform.openai.com/api-keys)

**Don't have API keys yet?** Skip this step — run `make onboard` after step 5 and follow the interactive setup wizard.

### 5. Start

```bash
make build       # build the Docker image
make up          # start the gateway
```

`make up` prints a dashboard URL with your token and instructions for first-time setup — just open the link and follow the prompt.

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

All container state is bind-mounted to your local disk — no Docker named volumes are used.

| Host path        | Container path                    | Purpose                                  |
|------------------|-----------------------------------|------------------------------------------|
| `./home/`        | `/home/openclaw`                  | Full home dir (npm globals, dotfiles, etc.) |
| `./config/`      | `/home/openclaw/.openclaw`        | OpenClaw config, credentials, memory     |
| `./workspaces/`  | `/home/openclaw/workspaces`       | Agent workspaces                         |

`./config/` and `./workspaces/` overlay their respective paths inside `./home/`. This means changes in `./config/` are what the container actually sees at `~/.openclaw`, not whatever is in `./home/.openclaw/`.

Each agent gets its own subdirectory:

```
./workspaces/
├── main/       # default agent
├── newsy/      # news agent
└── <agent-id>/ # any future agent
```

## Adding Agents

All agent workspaces live under `./workspaces/<agent-id>/` so they're accessible from the host. To add a new agent, shell into the container and update the config:

```bash
make shell
```

Then inside the container:

```bash
# Add the agent to the config
openclaw config set agents.list '[
  {"id":"main","workspace":"/home/openclaw/workspaces/main","agentDir":"/home/openclaw/.openclaw/agents/main/agent"},
  {"id":"your-agent","workspace":"/home/openclaw/workspaces/your-agent","agentDir":"/home/openclaw/.openclaw/agents/your-agent/agent"}
]'

# Create the workspace and add personality files
mkdir -p /home/openclaw/workspaces/your-agent
cat > /home/openclaw/workspaces/your-agent/SOUL.md << 'EOF'
# Your Agent Name
Description of personality and behavior...
EOF
```

Restart the gateway to pick up the new agent:

```bash
make restart
```

Talk to a specific agent:

```bash
make cmd ARGS="agent --agent your-agent -m 'hello'"
```

Or bind it to a channel (Telegram, Slack, etc.) via `bindings` in `openclaw.json`. See [multi-agent docs](https://docs.openclaw.ai/concepts/multi-agent).

## Ports

- `18789` - OpenClaw gateway (WebSocket control plane)

## Configuration

Run `make init` to create `.env` with an auto-generated gateway token, then add your API key:

- **`ANTHROPIC_API_KEY`** or **`OPENAI_API_KEY`** — at least one model provider

## Setup Prompts

Start by answering all its onboarding questions: what it should call you, what it's called, what tone you prefer

```
Download this skill: https://github.com/blader/humanizer. When you write content for me, whether its messages, emails, essays, or more, run the content through this skill to make it sound less AI-written.
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