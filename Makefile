.PHONY: help dev down logs logs-% clean init-frontend init-api services

COMPOSE_CMD := docker compose
ENV_FILE := .env
MISE := $(shell command -v mise 2> /dev/null)

# Load .env if it exists
ifneq (,$(wildcard $(ENV_FILE)))
    include $(ENV_FILE)
    export
endif

.DEFAULT_GOAL := help

help: ## Show available commands
	@echo ""
	@echo "Wander Dev Environment"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""

dev: ## Start all services
	@[ -f $(ENV_FILE) ] || { echo "Creating .env..."; ./scripts/init.sh; }
	@$(COMPOSE_CMD) up -d db redis
	@[ -f src/api/package.json ] && $(COMPOSE_CMD) --profile app up -d api || true
	@[ -f src/frontend/package.json ] && $(COMPOSE_CMD) --profile app up -d frontend || true
	@echo ""
	@echo "Services started. Use 'make logs' to view output."
	@echo ""

down: ## Stop all services
	@$(COMPOSE_CMD) --profile app down

logs: ## Show logs (all services)
	@$(COMPOSE_CMD) logs -f

logs-%: ## Show logs for specific service (e.g., make logs-api)
	@$(COMPOSE_CMD) logs -f $*

clean: ## Remove all data (destructive!)
	@echo "WARNING: This deletes all data!"
	@read -p "Continue? [y/N]: " ans && [ "$$ans" = "y" ] || exit 1
	@$(COMPOSE_CMD) --profile app down -v
	@echo "Cleanup complete"

services: ## Start only db + redis (for local dev)
	@[ -f $(ENV_FILE) ] || { echo "Creating .env..."; ./scripts/init.sh; }
	@$(COMPOSE_CMD) up -d db redis
	@echo ""
	@echo "Services started. To develop locally:"
	@echo "  cd src/frontend && bun install && bun run dev"
	@echo "  cd src/api && bun install && bun run dev"
	@echo ""

init-frontend: ## Initialize React + Vite + Tailwind frontend
	@[ -n "$(MISE)" ] || { echo "Installing mise..."; curl -fsSL https://mise.jdx.dev/install.sh | sh; exit 1; }
	@mise install
	@./scripts/init-frontend.sh

init-api: ## Initialize Express + TypeScript API
	@[ -n "$(MISE)" ] || { echo "Installing mise..."; curl -fsSL https://mise.jdx.dev/install.sh | sh; exit 1; }
	@mise install
	@./scripts/init-api.sh
