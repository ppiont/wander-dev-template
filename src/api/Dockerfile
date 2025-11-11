# Production Dockerfile
FROM oven/bun:1-alpine

WORKDIR /app

# Copy package files
COPY package.json bun.lockb* ./

# Install production dependencies only
RUN bun install --production

# Copy source code
COPY . .

EXPOSE 8080

# Run in production mode
CMD ["bun", "run", "src/index.ts"]
