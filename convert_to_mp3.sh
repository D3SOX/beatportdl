#!/bin/bash
# Convert FLAC files to 320 kbps MP3 while preserving metadata

DOWNLOADS_DIR="${1:-$HOME/Downloads/beatportdl}"

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first." >&2
    exit 1
fi

if [ ! -d "$DOWNLOADS_DIR" ]; then
    echo "Error: Downloads directory does not exist: $DOWNLOADS_DIR" >&2
    exit 1
fi

echo "Converting FLAC files to 320 kbps MP3 in: $DOWNLOADS_DIR"
echo ""

converted=0
skipped=0
failed=0

# Find all FLAC files recursively (using null-terminated strings to handle special characters)
# Use process substitution to avoid subshell issues with variable modifications
while IFS= read -r -d '' flac_file; do
    # Get directory and filename without extension
    dir=$(dirname "$flac_file")
    filename=$(basename "$flac_file" .flac)
    
    # Remove track number prefix (e.g., "01. ", "02. ", etc.) from the beginning
    # Pattern matches: one or two digits followed by ". " at the start
    filename=$(echo "$filename" | sed -E 's/^[0-9]{1,2}\. //')
    
    mp3_file="$dir/$filename.mp3"
    
    # Skip if MP3 already exists
    if [ -f "$mp3_file" ]; then
        echo "Skipping (MP3 exists): $flac_file"
        ((skipped++))
        continue
    fi
    
    echo "Converting: $flac_file"
    
    # Convert FLAC to 320 kbps MP3 with metadata preservation
    # -nostdin: prevent ffmpeg from reading stdin (required when in a loop)
    # -i: input file
    # -b:a 320k: audio bitrate 320 kbps
    # -map_metadata 0: copy all metadata from input
    # -id3v2_version 3: use ID3v2.3 tags (better compatibility)
    # -write_id3v1 1: also write ID3v1 tags
    # -y: overwrite output file if exists
    # -loglevel error: only show errors
    if ffmpeg -nostdin -i "$flac_file" \
        -codec:a libmp3lame \
        -b:a 320k \
        -map_metadata 0 \
        -id3v2_version 3 \
        -write_id3v1 1 \
        -y \
        -loglevel error \
        "$mp3_file" 2>&1; then
        echo "  ✓ Converted to: $mp3_file"
        ((converted++))
    else
        echo "  ✗ Error converting: $flac_file" >&2
        ((failed++))
    fi
done < <(find "$DOWNLOADS_DIR" -type f -name "*.flac" -print0)

echo ""
echo "Conversion complete!"
echo "  Converted: $converted"
echo "  Skipped: $skipped"
if [ "$failed" -gt 0 ]; then
    echo "  Failed: $failed" >&2
fi

