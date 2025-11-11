#!/usr/bin/env bash
#
# Wander Dev Environment - Health Check Script
# Parallel health checks for all services
#

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
    # shellcheck disable=SC1091
    set -a
    source .env
    set +a
fi

# Configuration
readonly FRONTEND_PORT=${FRONTEND_PORT:-3000}
readonly API_PORT=${API_PORT:-8080}
readonly MAX_WAIT=${MAX_WAIT:-60}
readonly CHECK_INTERVAL=2

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Results array
declare -a results=()

# ============================================
# Health Check Functions
# ============================================

check_service() {
    local name=$1
    local url=$2
    local wait_time=0

    while [ $wait_time -lt $MAX_WAIT ]; do
        if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
            results+=("$name:SUCCESS")
            return 0
        fi
        sleep $CHECK_INTERVAL
        ((wait_time += CHECK_INTERVAL))
    done

    results+=("$name:FAILED")
    return 1
}

# ============================================
# Main Script
# ============================================

main() {
    echo ""
    echo -e "${BLUE}${BOLD}🏥 Running Health Checks${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Start all checks in parallel (background)
    check_service "API" "http://localhost:$API_PORT/health" &
    local pid_api=$!

    check_service "Frontend" "http://localhost:$FRONTEND_PORT" &
    local pid_frontend=$!

    check_service "Database" "http://localhost:$API_PORT/health/db" &
    local pid_db=$!

    check_service "Redis" "http://localhost:$API_PORT/health/redis" &
    local pid_redis=$!

    # Show progress indicator
    local spinner_pid
    (
        local spin='-\|/'
        local i=0
        while kill -0 $pid_api 2>/dev/null || kill -0 $pid_frontend 2>/dev/null || \
              kill -0 $pid_db 2>/dev/null || kill -0 $pid_redis 2>/dev/null; do
            i=$(( (i+1) % 4 ))
            printf "\r  \033[0;34mChecking services... ${spin:$i:1}\033[0m"
            sleep 0.2
        done
        printf "\r\033[K"  # Clear line
    ) &
    spinner_pid=$!

    # Wait for all checks to complete
    wait $pid_api 2>/dev/null || true
    wait $pid_frontend 2>/dev/null || true
    wait $pid_db 2>/dev/null || true
    wait $pid_redis 2>/dev/null || true

    # Stop spinner
    kill $spinner_pid 2>/dev/null || true
    wait $spinner_pid 2>/dev/null || true

    # Print results
    echo ""
    local failed=0
    for result in "${results[@]}"; do
        local service="${result%:*}"
        local status="${result#*:}"

        if [ "$status" = "SUCCESS" ]; then
            echo -e "  ${GREEN}✅ $service is healthy${NC}"
        else
            echo -e "  ${RED}❌ $service health check failed${NC}"
            ((failed++))
        fi
    done

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🎉 All services are healthy!${NC}"
        echo ""
        echo -e "${BOLD}Access Your Application:${NC}"
        echo ""
        echo -e "  ${BOLD}Frontend:${NC}  http://localhost:$FRONTEND_PORT"
        echo -e "  ${BOLD}API:${NC}       http://localhost:$API_PORT"
        echo -e "  ${BOLD}API Docs:${NC}  http://localhost:$API_PORT/api-docs"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}❌ $failed service(s) failed health checks${NC}"
        echo ""
        echo -e "${BOLD}Troubleshooting:${NC}"
        echo ""
        echo -e "  ${BLUE}•${NC} Check logs:             ${BOLD}make logs${NC}"
        echo -e "  ${BLUE}•${NC} Validate setup:         ${BOLD}make validate${NC}"
        echo -e "  ${BLUE}•${NC} Check specific service: ${BOLD}make logs-<service>${NC}"
        echo -e "  ${BLUE}•${NC} Restart services:       ${BOLD}make restart${NC}"
        echo ""
        return 1
    fi
}

main "$@"
