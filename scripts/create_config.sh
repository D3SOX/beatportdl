#!/bin/bash
# Script to create config file for beatportdl

CONFIG_DIR="$HOME/.config/beatportdl"
CONFIG_FILE="$CONFIG_DIR/beatportdl-config.yml"
DOWNLOADS_DIR="$HOME/Downloads/beatportdl"

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<EOF
username: YOUR_BEATPORT_USERNAME
password: YOUR_BEATPORT_PASSWORD
quality: lossless
downloads_directory: $DOWNLOADS_DIR
fix_tags: true
show_progress: true
max_download_workers: 15
max_global_workers: 15
track_exists: update
track_file_template: "{artists} - {name} ({mix_name})"
EOF

echo "Config file created at: $CONFIG_FILE"
echo "Please edit it and add your Beatport username and password!"

