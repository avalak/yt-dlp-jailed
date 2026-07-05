#!/bin/bash
# Plugin discovery and execution functions for yt-dlp-jailed

_plugin_supported() {
    local ext="$1"
    case "${ext}" in
        sh) return 0 ;;
        py) command -v python &>/dev/null && return 0 || return 1 ;;
        js)
            [ "${JS_RUNTIME:-none}" != "none" ] && return 0 || return 1
            ;;
        *) return 1 ;;
    esac
}

find_plugin() {
    local cmd="$1"
    local dir="$2"

    for ext in sh py js; do
        local script="${dir}/${cmd}.${ext}"
        if [ -f "${script}" ] && [ -r "${script}" ]; then
            echo "${script}"
            return 0
        fi
    done

    for ext in sh py js; do
        local script="${dir}/${cmd}/plugin.${ext}"
        if [ -f "${script}" ] && [ -r "${script}" ]; then
            echo "${script}"
            return 0
        fi
    done

    return 1
}

list_plugins() {
    local dir="$1"
    if [ ! -d "${dir}" ]; then
        echo "  (directory not found)"
        return
    fi

    for script in "${dir}"/*.sh "${dir}"/*.py "${dir}"/*.js; do
        [ -f "${script}" ] || continue
        [ -r "${script}" ] || continue
        local name="${script##*/}"
        name="${name%.*}"
        local ext="${script##*.}"
        local status="unsupported"
        _plugin_supported "${ext}" && status="supported"
        printf "  %-20s script (%-4s) [%s]\n" "${name}" ".${ext}" "${status}"
    done

    for plugdir in "${dir}"/*/; do
        [ -d "${plugdir}" ] || continue
        local plugname="$(basename "${plugdir}")"
        local found=false
        for ext in sh py js; do
            local plugfile="${plugdir}/plugin.${ext}"
            if [ -f "${plugfile}" ] && [ -r "${plugfile}" ]; then
                local status="unsupported"
                _plugin_supported "${ext}" && status="supported"
                printf "  %-20s plugin (%-4s) [%s]\n" "${plugname}" ".${ext}" "${status}"
                found=true
            fi
        done
        ${found} || printf "  %-20s plugin (no readable file found)\n" "${plugname}"
    done
}

execute_plugin() {
    local script="$1"; shift
    local ext="${script##*.}"
    case "${ext}" in
        sh) exec bash "${script}" "${@}" ;;
        py)
            # Ensure the virtual environment is active
            if [ -f /opt/venv/bin/activate ]; then
                export VIRTUAL_ENV=/opt/venv
                export PATH="/opt/venv/bin:${PATH}"
            fi
            exec python "${script}" "${@}"
            ;;
        js)
            if [ "${JS_RUNTIME:-none}" = "none" ]; then
                echo "Error: No JS runtime available to execute ${script}" >&2
                exit 1
            fi
            case "${JS_RUNTIME}" in
                nodejs|node) exec node "${script}" "${@}" ;;
                quickjs)     exec qjs "${script}" "${@}" ;;
                deno)        exec deno run "${script}" "${@}" ;;
                *)           echo "Error: Unknown JS_RUNTIME ${JS_RUNTIME}" >&2; exit 1 ;;
            esac
            ;;
        *) echo "Error: Unsupported script type: ${ext}" >&2; exit 1 ;;
    esac
}
