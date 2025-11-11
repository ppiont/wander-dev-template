#!/usr/bin/env bash

# init-frontend.sh - Initialize React + Vite + Tailwind frontend with bun
# Usage: ./scripts/init-frontend.sh

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
FRONTEND_DIR="${PROJECT_ROOT}/src/frontend"

echo -e "${BLUE}${BOLD}🎨 Initializing Frontend (React + Vite + Tailwind + TypeScript)${NC}"
echo ""

# Check if frontend already exists
if [ -f "${FRONTEND_DIR}/package.json" ]; then
    echo -e "${YELLOW}⚠️  Frontend already exists at ${FRONTEND_DIR}${NC}"
    echo -e "${YELLOW}Remove it first if you want to reinitialize.${NC}"
    exit 1
fi

# Create src directory if it doesn't exist
mkdir -p "${PROJECT_ROOT}/src"

# Remove .gitkeep if it exists (prevents Vite prompt about non-empty directory)
if [ -f "${FRONTEND_DIR}/.gitkeep" ]; then
    rm "${FRONTEND_DIR}/.gitkeep"
fi

# Navigate to src directory
cd "${PROJECT_ROOT}/src"

echo -e "${BLUE}📦 Creating Vite project with React + TypeScript...${NC}"
# Use bun create vite with explicit template, non-interactive mode, and stable bundler
bun create vite frontend --template react-ts --no-interactive --no-rolldown

# Navigate into frontend directory
cd frontend

echo ""
echo -e "${BLUE}📦 Installing dependencies with bun...${NC}"
bun install

echo ""
echo -e "${BLUE}🎨 Adding Tailwind CSS v4...${NC}"
bun add -D tailwindcss@next @tailwindcss/vite@next

# Update CSS with Tailwind v4 import
echo -e "${BLUE}⚙️  Configuring Tailwind CSS...${NC}"
cat > src/index.css << 'EOF'
@import "tailwindcss";
EOF

# Configure Vite for Docker with Tailwind v4
echo -e "${BLUE}⚙️  Configuring Vite for Docker...${NC}"
cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: '0.0.0.0', // Required for Docker container access
    port: 3000,
    watch: {
      usePolling: true, // Required for hot reload in Docker
    },
  },
})
EOF

# Create App.tsx with health check dashboard
echo -e "${BLUE}📝 Creating App component with health dashboard...${NC}"
cat > src/App.tsx << 'EOF'
import { useState, useEffect } from 'react'

interface HealthStatus {
  status: string
  timestamp: string
  services?: {
    database: string
    redis: string
  }
  error?: string
}

function App() {
  const [apiHealth, setApiHealth] = useState<HealthStatus | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const checkHealth = async () => {
      try {
        const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:8080'
        const response = await fetch(`${apiUrl}/health`)
        const data = await response.json()
        setApiHealth(data)
      } catch (error) {
        console.error('Failed to fetch health:', error)
        setApiHealth({
          status: 'error',
          error: 'Failed to connect to API',
          timestamp: new Date().toISOString()
        })
      } finally {
        setLoading(false)
      }
    }

    checkHealth()
    const interval = setInterval(checkHealth, 5000) // Poll every 5 seconds
    return () => clearInterval(interval)
  }, [])

  const getStatusColor = (status?: string) => {
    if (!status) return 'bg-gray-200 text-gray-600'
    switch (status.toLowerCase()) {
      case 'healthy':
        return 'bg-green-100 text-green-800'
      case 'unhealthy':
        return 'bg-red-100 text-red-800'
      default:
        return 'bg-yellow-100 text-yellow-800'
    }
  }

  const getStatusIcon = (status?: string) => {
    if (!status) return '⏺'
    switch (status.toLowerCase()) {
      case 'healthy':
        return '✓'
      case 'unhealthy':
        return '✗'
      default:
        return '⚠'
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="container mx-auto px-4 py-16">
        <div className="max-w-4xl mx-auto">
          {/* Header */}
          <div className="text-center mb-12">
            <h1 className="text-5xl font-bold text-gray-900 mb-4">
              🚀 Wander Dev Template
            </h1>
            <p className="text-xl text-gray-600">
              Zero-to-Running Developer Environment
            </p>
            <p className="text-sm text-gray-500 mt-2">
              React + Vite + Tailwind + TypeScript
            </p>
          </div>

          {/* Status Card */}
          <div className="bg-white rounded-lg shadow-xl p-8 mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-6">
              System Health
            </h2>

            {loading ? (
              <div className="flex items-center justify-center py-8">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
              </div>
            ) : (
              <div className="space-y-4">
                {/* Overall Status */}
                <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <span className="font-semibold text-gray-700">Overall Status</span>
                  <span className={`px-4 py-2 rounded-full font-semibold ${getStatusColor(apiHealth?.status)}`}>
                    {getStatusIcon(apiHealth?.status)} {apiHealth?.status || 'unknown'}
                  </span>
                </div>

                {/* Services */}
                {apiHealth?.services && (
                  <>
                    <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                      <span className="font-semibold text-gray-700">PostgreSQL</span>
                      <span className={`px-4 py-2 rounded-full font-semibold ${getStatusColor(apiHealth.services.database)}`}>
                        {getStatusIcon(apiHealth.services.database)} {apiHealth.services.database}
                      </span>
                    </div>
                    <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                      <span className="font-semibold text-gray-700">Redis</span>
                      <span className={`px-4 py-2 rounded-full font-semibold ${getStatusColor(apiHealth.services.redis)}`}>
                        {getStatusIcon(apiHealth.services.redis)} {apiHealth.services.redis}
                      </span>
                    </div>
                  </>
                )}

                {/* Error Message */}
                {apiHealth?.error && (
                  <div className="p-4 bg-red-50 border-l-4 border-red-500 rounded">
                    <p className="text-red-700">
                      <strong>Error:</strong> {apiHealth.error}
                    </p>
                    <p className="text-sm text-red-600 mt-2">
                      Make sure the API server is running at{' '}
                      <code className="bg-red-100 px-1 rounded">
                        {import.meta.env.VITE_API_URL || 'http://localhost:8080'}
                      </code>
                    </p>
                  </div>
                )}

                {/* Timestamp */}
                {apiHealth?.timestamp && (
                  <p className="text-xs text-gray-500 text-right">
                    Last checked: {new Date(apiHealth.timestamp).toLocaleTimeString()}
                  </p>
                )}
              </div>
            )}
          </div>

          {/* Tech Stack */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-white rounded-lg shadow-lg p-6">
              <h3 className="text-xl font-bold text-gray-900 mb-4">Frontend</h3>
              <ul className="space-y-2 text-gray-700">
                <li>⚛️ React 18</li>
                <li>⚡ Vite</li>
                <li>🎨 Tailwind CSS</li>
                <li>📘 TypeScript</li>
              </ul>
            </div>
            <div className="bg-white rounded-lg shadow-lg p-6">
              <h3 className="text-xl font-bold text-gray-900 mb-4">Backend</h3>
              <ul className="space-y-2 text-gray-700">
                <li>🟢 Node.js + Express</li>
                <li>🐘 PostgreSQL</li>
                <li>🔴 Redis</li>
                <li>📘 TypeScript</li>
              </ul>
            </div>
          </div>

          {/* Quick Start */}
          <div className="mt-8 bg-blue-50 border-l-4 border-blue-500 p-6 rounded">
            <h3 className="text-lg font-bold text-blue-900 mb-2">
              🚀 Quick Start
            </h3>
            <code className="text-sm text-blue-800">
              make dev  # Start all services<br />
              make logs # View logs<br />
              make health # Check service health
            </code>
          </div>
        </div>
      </div>
    </div>
  )
}

export default App
EOF

# Create Dockerfile
echo -e "${BLUE}🐳 Creating Dockerfile...${NC}"
cat > Dockerfile << 'EOF'
# Frontend Dockerfile - React + TypeScript + Vite + Tailwind

FROM oven/bun:1-alpine

WORKDIR /app

# Install dependencies first (better caching)
COPY package.json bun.lockb* ./
RUN bun install

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Development mode with hot reload
CMD ["bun", "run", "dev"]
EOF

# Create .dockerignore
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
echo -e "${GREEN}${BOLD}✅ Frontend initialized successfully!${NC}"
echo ""
echo -e "${BLUE}Location:${NC} ${FRONTEND_DIR}"
echo -e "${BLUE}Tech Stack:${NC} React 18 + Vite + Tailwind CSS + TypeScript"
echo -e "${BLUE}Package Manager:${NC} Bun"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Start services: ${BLUE}make dev${NC}"
echo -e "  2. Access frontend: ${BLUE}http://localhost:3000${NC}"
echo -e "  3. View logs: ${BLUE}make logs-frontend${NC}"
echo ""
