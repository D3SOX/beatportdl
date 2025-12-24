#!/bin/bash
# Convert FLAC/AAC files to MP3 while preserving metadata
# FLAC → 320 kbps MP3 (lossless source)
# AAC → V2 MP3 (~190 kbps, equivalent quality without upsampling)

DOWNLOADS_DIR="${1:-$HOME/Downloads/beatportdl}"

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed. Please install it first." >&2
    exit 1
fi

if [ ! -d "$DOWNLOADS_DIR" ]; then
    echo "Error: Downloads directory does not exist: $DOWNLOADS_DIR" >&2
    exit 1
fi

echo "Converting audio files to MP3 in: $DOWNLOADS_DIR"
echo ""

converted=0
skipped=0
failed=0

# Function to convert a single audio file to MP3
convert_to_mp3() {
    local input_file="$1"
    local extension="$2"
    
    # Get directory and filename without extension
    dir=$(dirname "$input_file")
    filename=$(basename "$input_file" "$extension")
    
    # Remove track number prefix (e.g., "01. ", "02. ", etc.) from the beginning
    # Pattern matches: one or two digits followed by ". " at the start
    filename=$(echo "$filename" | sed -E 's/^[0-9]{1,2}\. //')
    
    mp3_file="$dir/$filename.mp3"
    
    # Skip if MP3 already exists
    if [ -f "$mp3_file" ]; then
        echo "Skipping (MP3 exists): $input_file"
        ((skipped++))
        return 0
    fi
    
    # Determine quality settings based on source format
    if [ "$extension" = ".flac" ]; then
        # FLAC is lossless, convert to high quality 320 kbps MP3
        quality_setting="-b:a 320k"
        quality_desc="320 kbps"
    else
        # AAC/M4A is lossy, use V2 (~190 kbps average) to avoid pointless upsampling
        # V2 is roughly equivalent to 128 kbps AAC in quality
        quality_setting="-q:a 2"
        quality_desc="V2 (~190 kbps)"
    fi
    
    echo "Converting: $input_file → $quality_desc MP3"
    
    # Convert to MP3 with metadata preservation
    # -nostdin: prevent ffmpeg from reading stdin (required when in a loop)
    # -i: input file
    # -codec:a libmp3lame: use LAME MP3 encoder
    # -b:a 320k (FLAC) or -q:a 2 (AAC): quality setting
    # -map_metadata 0: copy all metadata from input
    # -id3v2_version 3: use ID3v2.3 tags (better compatibility)
    # -write_id3v1 1: also write ID3v1 tags
    # -y: overwrite output file if exists
    # -loglevel error: only show errors
    if ffmpeg -nostdin -i "$input_file" \
        -codec:a libmp3lame \
        $quality_setting \
        -map_metadata 0 \
        -id3v2_version 3 \
        -write_id3v1 1 \
        -y \
        -loglevel error \
        "$mp3_file" 2>&1; then
        echo "  ✓ Converted to: $mp3_file"
        ((converted++))
    else
        echo "  ✗ Error converting: $input_file" >&2
        ((failed++))
    fi
}

# Find and convert all FLAC files
while IFS= read -r -d '' flac_file; do
    convert_to_mp3 "$flac_file" ".flac"
done < <(find "$DOWNLOADS_DIR" -type f -name "*.flac" -print0)

# Find and convert all M4A files (AAC)
while IFS= read -r -d '' m4a_file; do
    convert_to_mp3 "$m4a_file" ".m4a"
done < <(find "$DOWNLOADS_DIR" -type f -name "*.m4a" -print0)

echo ""
echo "Conversion complete!"
echo "  Converted: $converted"
echo "  Skipped: $skipped"
if [ "$failed" -gt 0 ]; then
    echo "  Failed: $failed" >&2
fi

