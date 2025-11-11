#!/usr/bin/env bash
# ============================================
# Database Seeding Script
# ============================================
# Seeds the PostgreSQL database with sample data
# Usage: ./scripts/seed-db.sh [seed-file]

set -euo pipefail

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SEED_FILE="${1:-scripts/seeds/initial.sql}"
CONTAINER_NAME="${PROJECT_NAME:-wander}-db"
DB_NAME="${DB_NAME:-app_db}"
DB_USER="${DB_USER:-postgres}"

# ============================================
# Functions
# ============================================

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
  echo -e "${RED}❌ $1${NC}"
}

# ============================================
# Pre-flight Checks
# ============================================

# Check if seed file exists
if [ ! -f "$SEED_FILE" ]; then
  log_error "Seed file not found: $SEED_FILE"
  echo ""
  echo "Usage: $0 [seed-file]"
  echo "Example: $0 scripts/seeds/initial.sql"
  echo ""
  exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  log_error "Docker daemon is not running"
  echo "Please start Docker and try again"
  exit 1
fi

# Check if database container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log_error "Database container is not running: $CONTAINER_NAME"
  echo ""
  echo "Start the database with: make dev"
  echo ""
  exit 1
fi

# ============================================
# Seeding Process
# ============================================

echo ""
log_info "Database Seeding Script"
echo ""
log_info "Seed file: $SEED_FILE"
log_info "Container: $CONTAINER_NAME"
log_info "Database: $DB_NAME"
echo ""

# Confirm action
read -p "$(echo -e ${YELLOW}⚠️  This will modify the database. Continue? [y/N]: ${NC})" -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  log_warning "Seeding cancelled"
  exit 0
fi

echo ""
log_info "Executing seed file..."

# Execute the seed file
if cat "$SEED_FILE" | docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1; then
  log_success "Database seeded successfully!"
else
  log_error "Seeding failed"
  echo ""
  echo "Trying again with verbose output..."
  cat "$SEED_FILE" | docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME"
  exit 1
fi

# ============================================
# Verification
# ============================================

echo ""
log_info "Verifying database..."

# Get table counts
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
  SELECT
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM posts) as posts,
    (SELECT COUNT(*) FROM comments) as comments;
" 2>/dev/null || log_warning "Could not verify table counts (tables may not exist yet)"

echo ""
log_success "Seeding complete!"
echo ""
log_info "Next steps:"
echo "  - View data: make shell-db"
echo "  - Test API: curl http://localhost:8080/health"
echo ""
