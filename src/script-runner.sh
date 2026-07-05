#!/bin/bash
set -euo pipefail

# Detect C library
detect_libc() {
    if [[ -f /etc/alpine-release ]]; then
        echo "musl"
    else
        echo "gnu"
    fi
}

LIBC=$(detect_libc)
export LIBC

CMD="${1:-}"
shift || true

SCRIPTS_DIR="/opt/yt-dlp-jailed/scripts"
EXTERNAL_DIR="/opt/yt-dlp-jailed/scripts-external"

source /opt/yt-dlp-jailed/lib/plugins.sh

# Built-in scripts
if script_path=$(find_plugin "${CMD}" "${SCRIPTS_DIR}"); then
    execute_plugin "${script_path}" "${@}"
fi

# External scripts
if [ -d "${EXTERNAL_DIR}" ]; then
    if script_path=$(find_plugin "${CMD}" "${EXTERNAL_DIR}"); then
        execute_plugin "${script_path}" "${@}"
    fi
fi

# Fallback to yt-dlp
set -- "${CMD}" "${@}"
exec yt-dlp "${@}"
