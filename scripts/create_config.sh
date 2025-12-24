#!/bin/bash
# Script to create config file for beatportdl

CONFIG_DIR="$HOME/.config/beatportdl"
CONFIG_FILE="$CONFIG_DIR/beatportdl-config.yml"
DOWNLOADS_DIR="$HOME/Downloads/beatportdl"

mkdir -p "$CONFIG_DIR"

# Prompt for quality setting
echo "Select download quality:"
echo "  1) lossless - FLAC (requires Professional/Beatsource Pro+)"
echo "  2) medium - 128 kbps AAC (requires Advanced/Beatsource Pro+)"
echo "  3) high - 256 kbps AAC (requires Professional/Beatsource Pro+)"
echo "  4) medium-hls - 128 kbps AAC via HLS (requires Essential/Beatsource)"
read -p "Enter choice [1-4] (default: 2): " quality_choice

case "$quality_choice" in
    1)
        QUALITY="lossless"
        ;;
    3)
        QUALITY="high"
        ;;
    4)
        QUALITY="medium-hls"
        ;;
    *)
        QUALITY="medium"
        ;;
esac

cat > "$CONFIG_FILE" <<EOF
username: YOUR_BEATPORT_USERNAME
password: YOUR_BEATPORT_PASSWORD
quality: $QUALITY
downloads_directory: $DOWNLOADS_DIR
fix_tags: true
show_progress: true
max_download_workers: 15
max_global_workers: 15
track_exists: update
track_file_template: "{artists} - {name} ({mix_name})"
EOF

echo ""
echo "Config file created at: $CONFIG_FILE"
echo "Quality set to: $QUALITY"
echo "Please edit the config file and add your Beatport username and password!"

