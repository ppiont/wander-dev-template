#!/usr/bin/env bash

# init-api.sh - Initialize Express + TypeScript API with bun
# Usage: ./scripts/init-api.sh

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Error handling
trap 'echo -e "${RED}Error on line $LINENO${NC}" >&2' ERR

# Get project root (parent of scripts directory)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="${PROJECT_ROOT}/src/api"

echo -e "${BLUE}${BOLD}🚀 Initializing API (Express + TypeScript)${NC}"
echo ""

# Check if API already exists
if [ -f "${API_DIR}/package.json" ]; then
    echo -e "${YELLOW}⚠️  API already exists at ${API_DIR}${NC}"
    echo -e "${YELLOW}Remove it first if you want to reinitialize.${NC}"
    exit 1
fi

# Create src/api directory
mkdir -p "${API_DIR}/src"

# Remove .gitkeep if it exists
if [ -f "${API_DIR}/.gitkeep" ]; then
    rm "${API_DIR}/.gitkeep"
fi

# Navigate to api directory
cd "${API_DIR}"

echo -e "${BLUE}📦 Initializing package.json...${NC}"
cat > package.json << 'EOF'
{
  "name": "wander-api",
  "version": "1.0.0",
  "description": "Wander API - Node.js + Express + TypeScript",
  "main": "dist/index.js",
  "type": "module",
  "scripts": {
    "dev": "bun --watch src/index.ts",
    "build": "bun build src/index.ts --outdir=dist --target=bun",
    "start": "bun dist/index.js",
    "test": "echo \"No tests yet\" && exit 0"
  },
  "keywords": ["express", "typescript", "api"],
  "author": "",
  "license": "MIT"
}
EOF

echo ""
echo -e "${BLUE}📦 Installing dependencies with bun...${NC}"
bun add express cors pg redis
bun add -D @types/express @types/node @types/pg @types/cors typescript

echo ""
echo -e "${BLUE}⚙️  Creating TypeScript configuration...${NC}"
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "node",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

echo ""
echo -e "${BLUE}📝 Creating Express server with health endpoints...${NC}"
cat > src/index.ts << 'EOF'
import express from 'express'
import cors from 'cors'
import { Pool } from 'pg'
import { createClient } from 'redis'

const app = express()
const PORT = process.env.PORT || 8080

// Middleware
app.use(cors())
app.use(express.json())

// Database connection
const db = new Pool({
  connectionString: process.env.DATABASE_URL,
})

// Redis connection
const redis = createClient({
  url: process.env.REDIS_URL,
})

redis.on('error', (err) => console.error('Redis Client Error', err))

// Connect to Redis
;(async () => {
  try {
    await redis.connect()
    console.log('✅ Connected to Redis')
  } catch (err) {
    console.error('❌ Failed to connect to Redis:', err)
  }
})()

// Health check endpoints
app.get('/health', async (req, res) => {
  try {
    // Check database
    const dbResult = await db.query('SELECT 1')
    const dbHealthy = dbResult.rowCount === 1

    // Check Redis
    const redisHealthy = redis.isOpen

    const healthy = dbHealthy && redisHealthy

    res.status(healthy ? 200 : 503).json({
      status: healthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      services: {
        database: dbHealthy ? 'healthy' : 'unhealthy',
        redis: redisHealthy ? 'healthy' : 'unhealthy',
      },
    })
  } catch (error) {
    console.error('Health check failed:', error)
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

app.get('/health/db', async (req, res) => {
  try {
    const result = await db.query('SELECT 1')
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

app.get('/health/redis', async (req, res) => {
  try {
    const isHealthy = redis.isOpen
    res.status(isHealthy ? 200 : 503).json({
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Wander API',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      healthDb: '/health/db',
      healthRedis: '/health/redis',
    },
  })
})

// Start server
app.listen(PORT, () => {
  console.log(`🚀 API server running on http://localhost:${PORT}`)
})

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM signal received: closing HTTP server')
  await redis.quit()
  await db.end()
  process.exit(0)
})
EOF

echo ""
echo -e "${BLUE}🐳 Creating Dockerfile...${NC}"
cat > Dockerfile << 'EOF'
# API Dockerfile - Node.js + Express + TypeScript

FROM oven/bun:1-alpine

WORKDIR /app

# Install dependencies first (better caching)
COPY package.json bun.lockb* ./
RUN bun install

# Copy source code
COPY . .

# Expose port
EXPOSE 8080

# Development mode with hot reload
CMD ["bun", "run", "dev"]
EOF

echo ""
echo -e "${BLUE}📝 Creating .dockerignore...${NC}"
cat > .dockerignore << 'EOF'
node_modules
dist
.git
.env
.vscode
*.log
EOF

echo ""
echo -e "${GREEN}${BOLD}✅ API initialized successfully!${NC}"
echo ""
echo -e "${BLUE}Location:${NC} ${API_DIR}"
echo -e "${BLUE}Tech Stack:${NC} Express + TypeScript + PostgreSQL + Redis"
echo -e "${BLUE}Package Manager:${NC} Bun"
echo ""
echo -e "${BLUE}Health Endpoints:${NC}"
echo -e "  • ${BLUE}/health${NC}       - Overall health + services"
echo -e "  • ${BLUE}/health/db${NC}    - Database only"
echo -e "  • ${BLUE}/health/redis${NC} - Redis only"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Start services: ${BLUE}make dev${NC}"
echo -e "  2. Access API: ${BLUE}http://localhost:8080${NC}"
echo -e "  3. Check health: ${BLUE}curl http://localhost:8080/health${NC}"
echo -e "  4. View logs: ${BLUE}make logs-api${NC}"
echo ""
