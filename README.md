# yt-dlp jailed

[![docker-build](https://github.com/avalak/yt-dlp-jailed/actions/workflows/docker-build.yml/badge.svg)](https://github.com/avalak/yt-dlp-jailed/actions/workflows/docker-build.yml)

---

## Setup

### 1. Install the launcher script

Download `yt-dlp.sh` and make it executable. It’s best placed in a directory
that is on your `PATH`, e.g. `~/.local/bin`.

```bash
curl -o ~/.local/bin/yt-dlp https://raw.githubusercontent.com/avalak/yt-dlp-jailed/main/yt-dlp.sh
chmod +x ~/.local/bin/yt-dlp
```

### 2. Configuration (optional)

User settings are read from `~/.config/yt-dlp-jailed/config`. If the file
does not exist, sensible defaults are used.

Example `~/.config/yt-dlp-jailed/config`:
```
OUTPUT_DIR="$HOME/YouTube"
SCRIPTS_DIR="$HOME/Projects/yt-dlp-scripts"
USE_CACHE=true
```

**Common variables**

| Variable | Default | Description |
|---|---|---|
| `IMAGE_NAME` | `ghcr.io/avalak/yt-dlp-jailed:latest` | Docker image to use |
| `OUTPUT_DIR` | `~/YouTube` | Where downloaded files are saved |
| `SCRIPTS_DIR` | `~/.config/yt-dlp-jailed/extra` | External scripts / plugins directory |
| `MEMORY` | `4096m` | Memory limit for the container (set to `"0"` to disable) |
| `CPU_LIMIT` | *(no limit)* | CPU limit, e.g. `"2"` |
| `PIDS_LIMIT` | `64` | Maximum number of processes in the container |
| `USE_CACHE` | `false` | Enable persistent yt-dlp cache (`"1"`, `"true"`, `"yes"`, `"on"`) |
| `CACHE_DIR` | `~/.cache/yt-dlp-jailed/yt-dlp` | Persistent cache location |

### 3. Custom scripts (plugins)

Place your own scripts in `~/.config/yt-dlp-jailed/extra/` (or the directory
pointed to by `SCRIPTS_DIR`). They are automatically mounted into the
container and can be invoked as commands.

Supported types: `.sh` (always), `.py` (pip image only), `.js` (if a JS
runtime is available).

Directory layout:
```
~/.config/yt-dlp-jailed/extra/
├── myscript.sh          # run with: yt-dlp myscript
└── myplugin/
    └── plugin.sh        # run with: yt-dlp myplugin
```
