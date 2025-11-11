#!/usr/bin/env bash
#
# Validate environment variables
#

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ENV_FILE="$PROJECT_ROOT/.env"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Required variables
readonly REQUIRED_VARS=(
  "PROJECT_NAME"
  "NODE_ENV"
  "DB_NAME"
  "DB_USER"
  "DB_PASSWORD"
)

main() {
  cd "$PROJECT_ROOT"

  # Check .env exists
  if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo "Create one: cp .env.example .env"
    exit 1
  fi

  # Load .env
  set -a
  source "$ENV_FILE"
  set +a

  # Check required vars
  local missing=()
  for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
      missing+=("$var")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing required variables:${NC}"
    printf '  %s\n' "${missing[@]}"
    exit 1
  fi

  echo -e "${GREEN}✅ Environment validation passed${NC}"
}

main "$@"
