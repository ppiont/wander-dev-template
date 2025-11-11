.PHONY: help init dev down logs logs-% clean services

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

init: ## Create .env file from template
	@./scripts/init.sh

dev: ## Start all services with hot reload
	@[ -f $(ENV_FILE) ] || { echo "Creating .env..."; ./scripts/init.sh; }
	@$(COMPOSE_CMD) up -d --build
	@echo ""
	@echo "✅ All services started. Use 'make logs' to view output."
	@echo ""
	@echo "Access:"
	@echo "  Frontend: http://localhost:3000"
	@echo "  API:      http://localhost:8080/health"
	@echo ""

down: ## Stop all services
	@$(COMPOSE_CMD) down

logs: ## Show logs (all services)
	@$(COMPOSE_CMD) logs -f

logs-%: ## Show logs for specific service (e.g., make logs-api)
	@$(COMPOSE_CMD) logs -f $*

clean: ## Remove all data (destructive!)
	@echo "WARNING: This deletes all data!"
	@read -p "Continue? [y/N]: " ans && [ "$$ans" = "y" ] || exit 1
	@$(COMPOSE_CMD) down -v
	@echo "Cleanup complete"

services: ## Start only db + redis (for local dev with mise)
	@[ -f $(ENV_FILE) ] || { echo "Creating .env..."; ./scripts/init.sh; }
	@$(COMPOSE_CMD) up -d db redis
	@echo ""
	@echo "✅ Services started (db + redis)."
	@echo ""
	@echo "To develop locally with mise:"
	@echo "  cd src/frontend && bun install && bun run dev"
	@echo "  cd src/api && bun install && bun run dev"
	@echo ""
