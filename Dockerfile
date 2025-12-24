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

# Install runtime dependencies and build tools for TagLib 2
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    apache2-utils \
    ffmpeg \
    zip \
    unzip \
    curl \
    netcat-openbsd \
    ca-certificates \
    build-essential \
    cmake \
    zlib1g-dev \
    libutfcpp-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Build and install TagLib 2
RUN cd /tmp && \
    git clone --branch v2.1.1 --depth 1 https://github.com/taglib/taglib.git && \
    cd taglib && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON . && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/taglib

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

