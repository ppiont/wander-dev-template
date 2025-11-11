# Multi-stage production Dockerfile
# Stage 1: Build static assets
FROM oven/bun:1-alpine AS builder

WORKDIR /app

# Accept API URL as build argument
ARG VITE_API_URL=/api
ENV VITE_API_URL=$VITE_API_URL

# Install dependencies
COPY package.json bun.lockb* ./
RUN bun install

# Copy source code
COPY . .

# Build static assets (Vite embeds VITE_API_URL at build time)
RUN bun run build

# Stage 2: Serve with nginx
FROM nginx:alpine

# Copy built assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Create nginx config for SPA
RUN cat > /etc/nginx/conf.d/default.conf << 'NGINX_EOF'
server {
    listen 3000;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # SPA routing - serve index.html for all routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_EOF

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
