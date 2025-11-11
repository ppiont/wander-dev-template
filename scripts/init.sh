#!/usr/bin/env bash
#
# Wander Dev Environment Initialization Script
# Bash-only implementation - zero Python dependency
#

set -euo pipefail
shopt -s inherit_errexit nullglob

# ============================================
# Configuration
# ============================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly ENV_FILE="$PROJECT_ROOT/.env"
readonly ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

# ============================================
# Colors & Styling
# ============================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# ============================================
# Logging Functions
# ============================================

log_step() {
    echo -e "${CYAN}${BOLD}▶ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

# ============================================
# Error Handling
# ============================================

error_handler() {
    local exit_code=$1
    local line_num=$2

    echo ""
    log_error "Error occurred in script at line $line_num (exit code: $exit_code)"
    log_info "Run '$0 --help' for usage information"
    echo ""

    exit "$exit_code"
}

trap 'error_handler $? $LINENO' ERR

# ============================================
# Dependency Checks
# ============================================

check_dependencies() {
    log_step "Step 1/7: Checking dependencies"

    local missing_deps=()

    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("Docker")
    else
        log_success "Docker found: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    fi

    # Check Docker Compose (v2 or standalone)
    if ! docker compose version &> /dev/null 2>&1 && ! command -v docker-compose &> /dev/null; then
        missing_deps+=("Docker Compose")
    else
        if docker compose version &> /dev/null 2>&1; then
            log_success "Docker Compose found: $(docker compose version --short 2>/dev/null || echo 'v2')"
        else
            log_success "Docker Compose found: $(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)"
        fi
    fi

    # Check Make
    if ! command -v make &> /dev/null; then
        missing_deps+=("Make")
    else
        log_success "Make found: $(make --version | head -n1 | cut -d' ' -f3)"
    fi

    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        log_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  ${BOLD}Docker:${NC} https://docs.docker.com/get-docker/"
        echo "  ${BOLD}Make:${NC} Usually available via package manager"
        echo "    - macOS: brew install make"
        echo "    - Ubuntu/Debian: sudo apt-get install build-essential"
        echo "    - CentOS/RHEL: sudo yum install make"
        echo ""
        return 1
    fi

    echo ""
}

# ============================================
# Docker Daemon Check
# ============================================

check_docker_daemon() {
    log_step "Step 2/7: Checking Docker daemon"

    if ! docker info >/dev/null 2>&1; then
        echo ""
        log_error "Docker daemon is not running"
        echo ""
        echo "Solutions:"
        echo "  - ${BOLD}macOS/Windows:${NC} Start Docker Desktop"
        echo "  - ${BOLD}Linux:${NC} sudo systemctl start docker"
        echo ""
        return 1
    fi

    log_success "Docker daemon is running"
    echo ""
}

# ============================================
# Environment Setup
# ============================================

setup_env_file() {
    log_step "Step 3/5: Setting up environment configuration"

    if [ -f "$ENV_FILE" ]; then
        log_warning ".env file already exists"
        echo -n "  Overwrite? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Keeping existing .env file"
            echo ""
            return 0
        fi
    fi

    if [ ! -f "$ENV_EXAMPLE" ]; then
        log_error ".env.example not found in project root"
        return 1
    fi

    cp "$ENV_EXAMPLE" "$ENV_FILE"
    log_success "Created .env from .env.example"
    log_info "Review and customize $ENV_FILE as needed"
    echo ""
}

# ============================================
# Pre-commit Hooks Setup
# ============================================

setup_precommit_hooks() {
    log_step "Step 4/5: Setting up pre-commit hooks"

    # Check if pre-commit is installed
    if ! command -v pre-commit &> /dev/null; then
        log_info "pre-commit not found, attempting to install..."

        if command -v pip3 &> /dev/null; then
            pip3 install --user pre-commit >/dev/null 2>&1 || python3 -m pip install --user pre-commit >/dev/null 2>&1
        elif command -v pip &> /dev/null; then
            pip install --user pre-commit >/dev/null 2>&1
        else
            log_warning "Could not install pre-commit (pip not found)"
            log_info "Install manually: pip install pre-commit"
            echo ""
            return 0
        fi

        # Check if installation succeeded
        if ! command -v pre-commit &> /dev/null; then
            log_warning "pre-commit installation failed"
            log_info "Install manually: pip install pre-commit"
            echo ""
            return 0
        fi
    fi

    # Install hooks
    cd "$PROJECT_ROOT"
    if [ -f ".pre-commit-config.yaml" ]; then
        pre-commit install >/dev/null 2>&1 || true
        pre-commit install --hook-type commit-msg >/dev/null 2>&1 || true
        log_success "Pre-commit hooks installed"
    else
        log_info "No .pre-commit-config.yaml found (skipping)"
    fi

    echo ""
}

# ============================================
# Port Availability Check
# ============================================

check_port_availability() {
    log_step "Step 5/5: Checking port availability"

    # Source .env to get port values
    if [ -f "$ENV_FILE" ]; then
        # shellcheck disable=SC1090
        set -a
        source "$ENV_FILE"
        set +a
    fi

    local ports_to_check=(
        "${FRONTEND_PORT:-3000}:Frontend"
        "${API_PORT:-8080}:API"
        "${DB_PORT:-5432}:PostgreSQL"
        "${REDIS_PORT:-6379}:Redis"
    )

    local conflicts=()

    for port_service in "${ports_to_check[@]}"; do
        local port="${port_service%%:*}"
        local service="${port_service##*:}"

        if lsof -Pi ":$port" -sTCP:LISTEN -t >/dev/null 2>&1 || \
           netstat -an 2>/dev/null | grep -q ":$port.*LISTEN" 2>/dev/null; then
            conflicts+=("$port ($service)")
            log_warning "Port $port ($service) is already in use"
        else
            log_success "Port $port ($service) is available"
        fi
    done

    echo ""

    if [ ${#conflicts[@]} -gt 0 ]; then
        log_warning "Some ports are in use: ${conflicts[*]}"
        echo ""
        echo "Solutions:"
        echo "  1. Stop services using these ports"
        echo "  2. Change ports in .env file"
        echo "  3. Continue anyway (services may fail to start)"
        echo ""
        echo -n "Continue? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Initialization cancelled"
            return 1
        fi
        echo ""
    fi
}

# ============================================
# Completion Message
# ============================================

show_completion_message() {
    echo ""
    echo "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  ✨ Initialization Complete! ✨${NC}"
    echo "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "${BOLD}Next Steps:${NC}"
    echo ""
    echo "  ${CYAN}1.${NC} Review and customize ${BOLD}.env${NC} if needed"
    echo "  ${CYAN}2.${NC} Start development environment:"
    echo ""
    echo "     ${BOLD}make dev${NC}          # All services with hot reload"
    echo ""
    echo "  ${CYAN}3.${NC} Access your application:"
    echo ""

    # Source .env to get port values
    if [ -f "$ENV_FILE" ]; then
        # shellcheck disable=SC1090
        set -a
        source "$ENV_FILE"
        set +a
    fi

    echo "     ${BOLD}Frontend:${NC} http://localhost:${FRONTEND_PORT:-3000}"
    echo "     ${BOLD}API:${NC}      http://localhost:${API_PORT:-8080}"
    echo "     ${BOLD}Health:${NC}   http://localhost:${API_PORT:-8080}/health"
    echo ""
    echo "${BOLD}Need Help?${NC}"
    echo ""
    echo "  ${BOLD}make help${NC}      # Show all commands"
    echo "  ${BOLD}make validate${NC}  # Check system requirements"
    echo ""
    echo "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ============================================
# Help Message
# ============================================

show_help() {
    cat << EOF
${BOLD}Wander Dev Environment - Initialization Script${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help      Show this help message
    -f, --force     Skip confirmation prompts

${BOLD}DESCRIPTION:${NC}
    Initializes the Wander development environment by:
    1. Checking required dependencies (Docker, Make, etc.)
    2. Verifying Docker daemon is running
    3. Creating .env file from .env.example
    4. Installing pre-commit hooks (auto)
    5. Checking port availability

${BOLD}EXAMPLES:${NC}
    $0              # Interactive initialization
    $0 --force      # Non-interactive (skip prompts)

${BOLD}AFTER INITIALIZATION:${NC}
    make dev        # Start all services
    make help       # Show all available commands

EOF
}

# ============================================
# Main Script
# ============================================

main() {
    # Parse arguments
    local force_mode=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                force_mode=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done

    # Change to project root
    cd "$PROJECT_ROOT"

    # Header
    echo ""
    echo "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo "${CYAN}${BOLD}║                                                ║${NC}"
    echo "${CYAN}${BOLD}║   🚀 Wander Dev Environment Initialization   ║${NC}"
    echo "${CYAN}${BOLD}║                                                ║${NC}"
    echo "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # Run initialization steps
    check_dependencies
    check_docker_daemon
    setup_env_file
    setup_precommit_hooks
    check_port_availability

    # Show completion message
    show_completion_message

    return 0
}

# Run main function
main "$@"
