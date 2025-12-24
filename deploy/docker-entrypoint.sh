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
# Bind to 0.0.0.0 to allow nginx to connect, and use HTTP
echo "Starting Astro server on port $PORT..."
cd /app/webui

# Run server in background and capture output
HOSTNAME=0.0.0.0 PORT=$PORT bun ./dist/server/entry.mjs > /tmp/astro-server.log 2>&1 &
ASTRO_PID=$!

# Wait for the Astro server to start (check if port is listening)
echo "Waiting for Astro server to be ready..."
for i in {1..30}; do
  if nc -z 127.0.0.1 $PORT 2>/dev/null; then
    echo "Astro server is ready on port $PORT!"
    break
  fi
  # Check if process is still running
  if ! kill -0 $ASTRO_PID 2>/dev/null; then
    echo "ERROR: Astro server process died. Last 20 lines of log:"
    tail -20 /tmp/astro-server.log
    exit 1
  fi
  if [ $i -eq 30 ]; then
    echo "WARNING: Astro server may not have started properly. Last 20 lines of log:"
    tail -20 /tmp/astro-server.log
  fi
  sleep 1
done

# Start nginx in the foreground
echo "Starting nginx..."
exec nginx -g 'daemon off;'

