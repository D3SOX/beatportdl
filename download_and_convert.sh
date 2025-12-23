#!/bin/bash
# Complete workflow: Download FLAC from Beatport and convert to 320 MP3

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.config/beatportdl/beatportdl-config.yml"
URLS_FILE="$SCRIPT_DIR/urls.txt"
BINARY="$SCRIPT_DIR/bin/beatportdl-linux-amd64"

# Check if config file exists and has credentials
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    echo "Please create it first with your Beatport credentials."
    exit 1
fi

if grep -q "YOUR_BEATPORT_USERNAME\|YOUR_BEATPORT_PASSWORD" "$CONFIG_FILE"; then
    echo "Error: Please edit $CONFIG_FILE and add your Beatport username and password"
    exit 1
fi

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    echo "Please build it first with: make linux-amd64"
    exit 1
fi

# Check if urls.txt exists
if [ ! -f "$URLS_FILE" ]; then
    echo "Error: urls.txt not found at $URLS_FILE"
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first."
    exit 1
fi

echo "=========================================="
echo "Step 1: Downloading tracks as FLAC..."
echo "=========================================="
"$BINARY" -q "$URLS_FILE"

echo ""
echo "=========================================="
echo "Step 2: Converting FLAC to 320 kbps MP3..."
echo "=========================================="

# Get downloads directory from config
DOWNLOADS_DIR=$(grep "downloads_directory:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

if [ -z "$DOWNLOADS_DIR" ]; then
    DOWNLOADS_DIR="$HOME/Downloads/beatportdl"
fi

# Convert FLAC files to MP3
"$SCRIPT_DIR/convert_to_mp3.sh" "$DOWNLOADS_DIR"

echo ""
echo "=========================================="
echo "Done! Your tracks are ready as 320 kbps MP3"
echo "Location: $DOWNLOADS_DIR"
echo "=========================================="

