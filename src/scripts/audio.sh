#!/bin/bash
# Download best audio: prefer native Opus, otherwise convert to Opus
set -euo pipefail

OPTS=(
    --format 'bestaudio[ext=opus]/bestaudio'
    --extract-audio
    --audio-format opus
    --output '%(extractor_key)s/%(channel)s/%(playlist_title)s/%(title)s.%(ext)s'
    --output-na-placeholder ''
    --embed-metadata
)

# Alpine/musl workarounds
if [[ "${LIBC:-}" == "musl" ]]; then
    OPTS+=(
        --postprocessor-args "ThumbnailsConvertor:-threads 1"
        # --no-embed-thumbnail
        # --postprocessor-args "ffmpeg:-threads 1"
    )
fi

exec yt-dlp "${OPTS[@]}" "${@}"
