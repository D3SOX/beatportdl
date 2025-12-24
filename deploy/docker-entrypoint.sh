#!/bin/bash
set -e

# =============================================================================
# BeatportDL WebUI Docker Entrypoint
# Generates htpasswd from env vars and starts both Astro server (Bun) and nginx
# =============================================================================

# Check required environment variables
if [ -z "$BASIC_AUTH_USER" ]; then
    echo "ERROR: BASIC_AUTH_USER environment variable is not set"
    exit 1
fi

if [ -z "$BASIC_AUTH_PASSWORD" ]; then
    echo "ERROR: BASIC_AUTH_PASSWORD environment variable is not set"
    exit 1
fi

# Generate htpasswd file for nginx Basic Auth
echo "Generating htpasswd file..."
htpasswd -bc /etc/nginx/.htpasswd "$BASIC_AUTH_USER" "$BASIC_AUTH_PASSWORD"
echo "Basic Auth configured for user: $BASIC_AUTH_USER"

# Set default port for Astro server
PORT="${PORT:-3000}"

# Create beatportdl config directory if it doesn't exist
mkdir -p /root/.config/beatportdl

# Start the Astro server with Bun in the background
echo "Starting Astro server on port $PORT..."
cd /app/webui
PORT=$PORT bun ./dist/server/entry.mjs &

# Wait a moment for the Astro server to start
sleep 2

# Start nginx in the foreground
echo "Starting nginx..."
exec nginx -g 'daemon off;'

