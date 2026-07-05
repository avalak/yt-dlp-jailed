#!/bin/bash
# yt-dlp-jailed environment overview
set -euo pipefail
# set -x

echo "yt-dlp-jailed environment"
echo "========================="

# Installation method
if command -v python &>/dev/null; then
    echo "Install method : pip"
    echo "Python         : $(python --version 2>&1)"
else
    echo "Install method : prebuilt (no Python)"
fi

# yt-dlp version
echo "yt-dlp         : $(yt-dlp --version 2>&1)"

# ffmpeg / ffprobe
echo "ffmpeg         : $(ffmpeg -version 2>&1 | head -n1)"
echo "ffprobe        : $(ffprobe -version 2>&1 | head -n1)"

echo "========================="

# JS runtime
echo "JS runtime     : ${JS_RUNTIME:-not set}"
case "${JS_RUNTIME:-}" in
    nodejs | node)
        echo "Node.js        : $(node --version 2>&1)"
        ;;
    quickjs)
        echo "QuickJS        : $(qjs -h 2>&1 | head -n1)"
        ;;
    deno)
        echo "Deno           : $(deno --version 2>&1 | head -n1)"
        ;;
    none | "")
        echo "JS engine      : none"
        ;;
    *)
        echo "JS engine      : unknown"
        ;;
esac

# bash
echo "bash           : ${BASH_VERSION}"

# System info
echo "Alpine         : $(cat /etc/alpine-release 2>/dev/null || echo unknown)"
echo "Kernel         : $(uname -r)"

echo ""
echo "Configuration"
echo "-------------"
echo "Base config    : /etc/yt-dlp.base.conf"
echo "Active config  : /etc/yt-dlp.conf"
if [ -L /etc/yt-dlp.conf ]; then
    echo "Config source  : symlink -> $(readlink /etc/yt-dlp.conf)"
fi
echo "Scripts        : /opt/yt-dlp-jailed/scripts"
echo "External       : /opt/yt-dlp-jailed/scripts-external (mounted at runtime)"

# Plugin listing using shared library
source /opt/yt-dlp-jailed/lib/plugins.sh

echo ""
echo "Built-in plugins"
echo "----------------"
list_plugins "/opt/yt-dlp-jailed/scripts"

if [ -d "/opt/yt-dlp-jailed/scripts-external" ]; then
    echo ""
    echo "External plugins"
    echo "----------------"
    list_plugins "/opt/yt-dlp-jailed/scripts-external"
fi
