#!/usr/bin/env bash
#
# Wander Dev Environment - Pre-flight Validation
# Comprehensive checks before starting services
#

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Requirements
readonly REQUIRED_DISK_MB=5000
readonly MIN_DOCKER_VERSION="20.10.0"

# Counters
errors=0
warnings=0

# ============================================
# Logging Functions
# ============================================

log_check() {
    echo -e "${BLUE}🔍 Checking: $1${NC}"
}

log_success() {
    echo -e "${GREEN}  ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}  ⚠️  $1${NC}"
    ((warnings++))
}

log_error() {
    echo -e "${RED}  ❌ $1${NC}"
    ((errors++))
}

# ============================================
# Validation Functions
# ============================================

check_docker_daemon() {
    log_check "Docker daemon status"

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        echo -e "${BLUE}     💡 Start Docker Desktop or run: sudo systemctl start docker${NC}"
        return 1
    fi

    log_success "Docker daemon is running"
}

check_docker_version() {
    log_check "Docker version"

    local version
    version=$(docker version --format '{{.Server.Version}}' 2>/dev/null | cut -d'-' -f1 || echo "")

    if [ -z "$version" ]; then
        log_warning "Could not determine Docker version"
        return 0
    fi

    log_success "Docker version: $version"

    # Simple version comparison
    local required_major required_minor
    required_major=$(echo "$MIN_DOCKER_VERSION" | cut -d'.' -f1)
    required_minor=$(echo "$MIN_DOCKER_VERSION" | cut -d'.' -f2)

    local current_major current_minor
    current_major=$(echo "$version" | cut -d'.' -f1)
    current_minor=$(echo "$version" | cut -d'.' -f2)

    if [ "$current_major" -lt "$required_major" ] || \
       { [ "$current_major" -eq "$required_major" ] && [ "$current_minor" -lt "$required_minor" ]; }; then
        log_warning "Docker version $version is older than recommended $MIN_DOCKER_VERSION"
    fi
}

check_disk_space() {
    log_check "Available disk space"

    local available_mb
    if command -v df &> /dev/null; then
        available_mb=$(df -m . 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")

        if [ "$available_mb" -eq 0 ]; then
            log_warning "Could not determine disk space"
            return 0
        fi

        if [ "$available_mb" -lt "$REQUIRED_DISK_MB" ]; then
            log_warning "Low disk space: ${available_mb}MB available (${REQUIRED_DISK_MB}MB recommended)"
        else
            log_success "Sufficient disk space: ${available_mb}MB available"
        fi
    else
        log_warning "Cannot check disk space (df command not available)"
    fi
}

check_docker_compose() {
    log_check "Docker Compose"

    if docker compose version &> /dev/null 2>&1; then
        local version
        version=$(docker compose version --short 2>/dev/null || echo "v2")
        log_success "Docker Compose (Plugin): $version"
    elif command -v docker-compose &> /dev/null; then
        local version
        version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log_success "Docker Compose (Standalone): $version"
    else
        log_error "Docker Compose not found"
        echo -e "${BLUE}     💡 Install: https://docs.docker.com/compose/install/${NC}"
        return 1
    fi
}

check_network() {
    log_check "Docker networking"

    if ! docker network ls | grep -q bridge; then
        log_error "Docker bridge network not found"
        return 1
    fi

    log_success "Docker networking is configured"
}

check_env_file() {
    log_check "Environment configuration"

    if [ ! -f .env ]; then
        log_error ".env file not found"
        echo -e "${BLUE}     💡 Run: make init${NC}"
        return 1
    fi

    log_success ".env file exists"

    # Check for required variables
    local required_vars=("PROJECT_NAME" "FRONTEND_PORT" "API_PORT" "DB_PORT" "REDIS_PORT")
    local missing_vars=()

    # shellcheck disable=SC1091
    set -a
    source .env 2>/dev/null || true
    set +a

    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_warning "Missing variables in .env: ${missing_vars[*]}"
    fi
}

check_port_conflicts() {
    log_check "Port availability"

    # shellcheck disable=SC1091
    set -a
    source .env 2>/dev/null || true
    set +a

    local ports_to_check=(
        "${FRONTEND_PORT:-3000}:Frontend"
        "${API_PORT:-8080}:API"
        "${DB_PORT:-5432}:Database"
        "${REDIS_PORT:-6379}:Redis"
    )

    local conflicts=0

    for port_service in "${ports_to_check[@]}"; do
        local port="${port_service%%:*}"
        local service="${port_service##*:}"

        if lsof -Pi ":$port" -sTCP:LISTEN -t >/dev/null 2>&1 || \
           netstat -an 2>/dev/null | grep -q ":$port.*LISTEN" 2>/dev/null; then
            log_warning "Port $port ($service) is in use"
            ((conflicts++))
        fi
    done

    if [ $conflicts -eq 0 ]; then
        log_success "All required ports are available"
    fi
}

check_docker_resources() {
    log_check "Docker resource limits"

    # Check Docker memory limit
    if docker info 2>/dev/null | grep -q "Total Memory"; then
        local total_mem
        total_mem=$(docker info 2>/dev/null | grep "Total Memory" | awk '{print $3}')
        log_success "Docker memory: ${total_mem}GiB"

        # Warn if less than 4GB
        local mem_value
        mem_value=$(echo "$total_mem" | sed 's/GiB//')
        if (( $(echo "$mem_value < 4" | bc -l 2>/dev/null || echo "0") )); then
            log_warning "Docker has less than 4GB memory (recommended: 4GB+)"
        fi
    fi
}

# ============================================
# Main Script
# ============================================

main() {
    echo ""
    echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║                                                ║${NC}"
    echo -e "${BLUE}${BOLD}║   🔍 Pre-flight Validation                    ║${NC}"
    echo -e "${BLUE}${BOLD}║                                                ║${NC}"
    echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # Run all checks
    check_docker_daemon
    check_docker_version
    check_docker_compose
    check_network
    check_docker_resources
    check_disk_space
    check_env_file
    check_port_conflicts

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Summary
    if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✅ All validations passed!${NC}"
        echo ""
        echo "Your environment is ready. Run: ${BOLD}make dev${NC}"
    elif [ $errors -eq 0 ]; then
        echo -e "${YELLOW}${BOLD}⚠️  Validation completed with $warnings warning(s)${NC}"
        echo ""
        echo "You can proceed, but review warnings above."
        echo "Run: ${BOLD}make dev${NC}"
    else
        echo -e "${RED}${BOLD}❌ Validation failed with $errors error(s) and $warnings warning(s)${NC}"
        echo ""
        echo "Fix errors above before running ${BOLD}make dev${NC}"
        return 1
    fi

    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    return 0
}

main "$@"
