#!/bin/bash
# Download best audio: prefer native Opus, otherwise convert to Opus
# Saves hierarchically: extractor / channel / [playlist] / title
# Metadata files (JSON, thumbnails) can be stored in a separate directory
set -euo pipefail

OPTS=(
    --format 'bestaudio[ext=opus]/bestaudio'
    --extract-audio
    --audio-format opus
    --output '%(extractor_key)s/%(channel)s/%(playlist_title)s/%(title)s.%(ext)s'
    --output-na-placeholder ''
    --embed-metadata
)

# Sidecar metadata
if [[ "${OPUS_WRITE_INFO:-1}" == "1" ]]; then
    OPTS+=(--write-info-json --write-thumbnail)
fi

# Alpine/musl workarounds
if [[ "${LIBC:-}" == "musl" ]]; then
    OPTS+=(
        --postprocessor-args "ThumbnailsConvertor:-threads 1"
    )
fi

# Optional separate metadata directory
if [[ -n "${OPUS_METADATA_DIR:-}" ]]; then
    METADATA_DIR="${OPUS_METADATA_DIR}"
    # Create a temporary marker to identify newly created files
    MARKER=$(mktemp)
    trap 'rm -f "$MARKER"' EXIT
    touch "$MARKER"
fi

# Run yt-dlp
yt-dlp "${OPTS[@]}" "${@}"

# If metadata directory is set, move new metadata files there
if [[ -n "${METADATA_DIR:-}" ]]; then
    find "$OUTPUT_DIR" -newer "$MARKER" \( -name "*.info.json" -o -name "*.webp" -o -name "*.png" -o -name "*.jpg" \) -exec sh -c '
    for f; do
      rel="${f#$OUTPUT_DIR/}"
      mkdir -p "$0/${rel%/*}"
      mv "$f" "$0/$rel"
    done
  ' "$METADATA_DIR" {} +
fi
