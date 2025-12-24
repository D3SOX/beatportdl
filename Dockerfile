# Multi-stage Dockerfile for BeatportDL WebUI
# Builds the Astro app with Bun and serves it behind nginx with HTTP Basic Auth

# =============================================================================
# Stage 1: Builder - Build the Astro webui with Bun
# =============================================================================
FROM oven/bun:latest AS builder

WORKDIR /app

# Copy the entire project
COPY . .

# Install dependencies and build the webui
WORKDIR /app/webui
RUN bun install --frozen-lockfile
RUN bun run build

# =============================================================================
# Stage 2: Runtime - nginx + Bun for SSR
# =============================================================================
FROM nginx:latest

# Install runtime dependencies (Debian/Ubuntu packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    apache2-utils \
    ffmpeg \
    zip \
    curl \
    netcat-openbsd \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

WORKDIR /app

# Copy the entire built project from builder
COPY --from=builder /app /app

# Ensure the binary is executable
RUN chmod +x /app/bin/beatportdl-linux-amd64 2>/dev/null || true
RUN chmod +x /app/bin/beatportdl-linux-arm64 2>/dev/null || true

# Copy static client assets to nginx web root
COPY --from=builder /app/webui/dist/client /usr/share/nginx/html

# Copy custom nginx configuration
COPY deploy/nginx.conf /etc/nginx/nginx.conf

# Copy entrypoint script
COPY deploy/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Create directories for runtime data
RUN mkdir -p /app/webui/.data

# Expose nginx port
EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]

