.PHONY: init build up down start stop restart logs shell cli onboard status clean help

# Default target
.DEFAULT_GOAL := help

# Derive host UID/GID from the calling user's session
export HOST_UID := $(shell id -u)
export HOST_GID := $(shell id -g)

# Initialize .env from .env.example and generate a gateway token
init:
	@if [ -f .env ]; then \
		echo "Error: .env already exists. Remove it first if you want to re-initialize."; \
		exit 1; \
	fi
	cp .env.example .env
	@TOKEN=$$(openssl rand -hex 32); \
	sed -i.bak "s/OPENCLAW_GATEWAY_TOKEN=__GENERATED_BY_MAKE_INIT__/OPENCLAW_GATEWAY_TOKEN=$$TOKEN/" .env && rm -f .env.bak; \
	echo ""; \
	echo "Created .env with auto-generated gateway token."; \
	echo ""; \
	echo "Next step: edit .env and add your API key (Anthropic or OpenAI)."; \
	echo "  $${EDITOR:-nano} .env"; \
	echo ""

# Build the Docker image
build:
	docker compose build

# Start the OpenClaw gateway in the background
up:
	docker compose up -d
	@TOKEN=$$(grep OPENCLAW_GATEWAY_TOKEN .env 2>/dev/null | cut -d= -f2); \
	echo ""; \
	echo "OpenClaw is running."; \
	echo ""; \
	echo "  Dashboard: http://localhost:18789/?token=$$TOKEN"; \
	echo ""; \
	echo "First time? Paste this token into the OpenClaw UI settings when prompted:"; \
	echo "  $$TOKEN"; \
	echo ""

# Start the OpenClaw gateway in the foreground (with logs)
up-fg:
	docker compose up

# Stop the OpenClaw gateway
down:
	docker compose down

# Aliases for up/down
start: up
stop: down

# Restart the gateway
restart:
	docker compose restart

# View logs (follow mode)
logs:
	docker compose logs -f openclaw

# View recent logs (last 100 lines)
logs-tail:
	docker compose logs --tail=100 openclaw

# Open an interactive shell in the running container
shell:
	docker compose exec openclaw bash

# Run an interactive OpenClaw CLI session
cli:
	docker compose run --rm cli

# Run the OpenClaw onboarding wizard
onboard:
	docker compose run --rm cli onboard

# Check OpenClaw status
status:
	docker compose run --rm cli status

# Run openclaw doctor to check configuration
doctor:
	docker compose run --rm cli doctor

# Open the dashboard (prints tokenized URL)
dashboard:
	@echo "http://localhost:18789/?token=$$(grep OPENCLAW_GATEWAY_TOKEN .env | cut -d= -f2)"

# Run any openclaw command (usage: make cmd ARGS="your command here")
cmd:
	docker compose run --rm cli $(ARGS)

# Remove containers (WARNING: add -v to also destroy internal state)
clean:
	docker compose down

# Remove everything including the image
clean-all: clean
	docker rmi -f openclaw-docker-openclaw 2>/dev/null || true
	docker rmi -f openclaw-docker-cli 2>/dev/null || true

# Show help
help:
	@echo "OpenClaw Docker Management"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  init       Create .env and generate gateway token"
	@echo "  build      Build the Docker image"
	@echo "  up         Start the gateway in the background"
	@echo "  up-fg      Start the gateway in the foreground"
	@echo "  down       Stop the gateway"
	@echo "  start      Alias for 'up'"
	@echo "  stop       Alias for 'down'"
	@echo "  restart    Restart the gateway"
	@echo "  logs       Follow the gateway logs"
	@echo "  logs-tail  Show last 100 lines of logs"
	@echo "  shell      Open a bash shell in the container"
	@echo "  cli        Run interactive OpenClaw CLI"
	@echo "  onboard    Run the onboarding wizard"
	@echo "  status     Check OpenClaw status"
	@echo "  doctor     Run openclaw doctor"
	@echo "  dashboard  Get dashboard URL"
	@echo "  cmd        Run any openclaw command (ARGS=\"...\")"
	@echo "  clean      Remove containers and volumes"
	@echo "  clean-all  Remove containers, volumes, and images"
	@echo "  help       Show this help message"
