#!/bin/bash
# yt-dlp-jailed — Secure, isolated yt-dlp launcher
# =================================================
# Usage:
#   ./yt-dlp.sh [command] [arguments...]
#
# Environment variables (optional):
#   IMAGE_NAME  Docker image to use (default: ghcr.io/avalak/yt-dlp-jailed:latest)
#   OUTPUT_DIR  Directory for downloaded files (default: ~/YouTube)
#   SCRIPTS_DIR External scripts directory (default: ~/.config/yt-dlp-jailed/extra)
#
#   MEMORY      Memory limit, e.g. "4096m" (default: 4096m; set to "0" to disable)
#   CPU_LIMIT   CPU limit, e.g. "2" (default: no limit; set to "0" to disable)
#   PIDS_LIMIT  Process limit (default: 64; set to "0" to disable)
#
#   USE_CACHE   Enable persistent cache: "1", "true", or "yes"
#   CACHE_DIR   Cache directory (default: ~/.cache/yt-dlp-jailed/yt-dlp)
#
# Examples:
#   ./yt-dlp.sh info "https://www.youtube.com/watch?v=..."
#   ./yt-dlp.sh opus "https://www.youtube.com/watch?v=..."
#   CPU_LIMIT=2 ./yt-dlp.sh "https://..."
set -euo pipefail
#set -x

# Prevent execution as root
if [[ "$(id -u)" == "0" ]]; then
    echo "ERROR: This script must not be run as root." >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker not found" >&2
    exit 1
fi

# Load user configuration if present
CONFIG_FILE="${HOME}/.config/yt-dlp-jailed/config"
if [[ -f "${CONFIG_FILE}" ]]; then
    while IFS='=' read -r key value; do
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        [[ -z "${key}" || "${key}" == \#* ]] && continue

        value="${value%%#*}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        # strip quotes (once per type)
        if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
            value="${value%\"}"
            value="${value#\"}"
        elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
            value="${value%\'}"
            value="${value#\'}"
        fi
        value="${value/#~\//${HOME}/}"
        case "${key}" in
            OUTPUT_DIR) OUTPUT_DIR="${value}" ;;
            SCRIPTS_DIR) SCRIPTS_DIR="${value}" ;;
            MEMORY) MEMORY="${value}" ;;
            CPU_LIMIT) CPU_LIMIT="${value}" ;;
            USE_CACHE) USE_CACHE="${value}" ;;
            CACHE_DIR) CACHE_DIR="${value}" ;;
            PIDS_LIMIT) PIDS_LIMIT="${value}" ;;
            IMAGE_NAME) IMAGE_NAME="${value}" ;;
        esac
    done <"${CONFIG_FILE}"
fi

# Validate memory format (scheme: <digits>[b|k|m|g])
if [[ -n "${MEMORY:-}" && "${MEMORY}" != "0" && ! "${MEMORY}" =~ ^[0-9]+[bBkKmMgG]?$ ]]; then
    echo "ERROR: Invalid MEMORY format: ${MEMORY}" >&2
    exit 1
fi

# Validate CPU limit (scheme: <digits> or <digits>.<digits>)
if [[ -n "${CPU_LIMIT:-}" && "${CPU_LIMIT}" != "0" && ! "${CPU_LIMIT}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "ERROR: Invalid CPU_LIMIT format: ${CPU_LIMIT}" >&2
    exit 1
fi

# Validate PIDs limit (scheme: <digits>)
if [[ -n "${PIDS_LIMIT:-}" && "${PIDS_LIMIT}" != "0" && ! "${PIDS_LIMIT}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid PIDS_LIMIT format: ${PIDS_LIMIT}" >&2
    exit 1
fi

# Default settings
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/avalak/yt-dlp-jailed:latest}"
SCRIPTS_DIR="${SCRIPTS_DIR:-${HOME}/.config/yt-dlp-jailed/extra}"
USER_CONF="${HOME}/.config/yt-dlp-jailed/yt-dlp.conf"
OUTPUT_DIR="${OUTPUT_DIR:-${HOME}/YouTube}"

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# Mounts
extra_mounts=()

# Mount extra scripts directory if it exists and NOT a symlink
if [[ -d "${SCRIPTS_DIR}" && ! -L "${SCRIPTS_DIR}" ]]; then
    extra_mounts+=(--mount "type=bind,src=${SCRIPTS_DIR},dst=/opt/yt-dlp-jailed/scripts-external,ro")
fi

# Mount user's yt-dlp.conf if present (overrides /etc/yt-dlp.conf)
if [[ -f "${USER_CONF}" && ! -L "${USER_CONF}" ]]; then
    extra_mounts+=(--mount "type=bind,src=${USER_CONF},dst=/etc/yt-dlp.conf,ro")
fi

# Persistent cache (opt-in)
CACHE_ENABLED=false
if [[ "${USE_CACHE,,}" =~ ^(1|true|yes|on)$ ]]; then
    CACHE_ENABLED=true
fi
if $CACHE_ENABLED; then
    CACHE_HOST_DIR="${CACHE_DIR:-${HOME}/.cache/yt-dlp-jailed/yt-dlp}"
    mkdir -p "${CACHE_HOST_DIR}"
    extra_mounts+=(--mount "type=bind,src=${CACHE_HOST_DIR},dst=/cache")
fi

# --- Build docker run options ---

# TTY mode: keep stdin open so the container can receive signals (Ctrl+C).
# If a terminal is attached, also allocate a pseudo-TTY for interactive output.
tty_mode=(-i)
if [[ -t 0 ]]; then
    tty_mode+=(-t)
fi
# 1. Sandbox (always applied)
docker_opts=(
    --rm
    "${tty_mode[@]}"
    --read-only
    --cap-drop=ALL
    --security-opt=no-new-privileges:true
    --user "$(id -u):$(id -g)"
)

# 2. Resource limits (with sensible defaults, can be disabled by setting to 0)
# Memory: default 4096m, disable with MEMORY=0
MEMORY="${MEMORY:-4096m}"
if [[ "${MEMORY}" != "0" ]]; then
    docker_opts+=(--memory "${MEMORY}")
fi

# CPU: no default limit, set CPU_LIMIT to e.g. "2" to enable
if [[ -n "${CPU_LIMIT:-}" && "${CPU_LIMIT}" != "0" ]]; then
    docker_opts+=(--cpus "${CPU_LIMIT}")
fi

# PIDs: default 64, disable with PIDS_LIMIT=0
PIDS_LIMIT="${PIDS_LIMIT:-64}"
if [[ "${PIDS_LIMIT}" != "0" ]]; then
    docker_opts+=(--pids-limit "${PIDS_LIMIT}")
fi

# 3. Mounts
docker_opts+=(
    # --tmpfs "/tmp:rw,noexec,nosuid,nodev,size=2g"
    --tmpfs "/tmp:rw,noexec,nosuid,nodev"
    --mount "type=bind,src=${OUTPUT_DIR},dst=/output"
)
docker_opts+=("${extra_mounts[@]}")

# Run the container
docker run \
    "${docker_opts[@]}" \
    "${IMAGE_NAME}" \
    "${@}"
