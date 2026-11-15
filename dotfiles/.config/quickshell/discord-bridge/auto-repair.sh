#!/usr/bin/env bash
# Re-patches Discord with the Equicord DiscordBridge userplugin whenever a new
# app-<version> directory appears (Discord's updater wipes the patch).
#
# Invoked by quickshell-discord-bridge.path. Safe to run by hand too.
set -uo pipefail

BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISCORD_DIR="${DISCORD_DIR:-$HOME/.config/discord}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mist"
LOG_FILE="$STATE_DIR/discord-bridge.log"
LOCK_FILE="$STATE_DIR/discord-bridge.lock"
RESTART_STAMP="$STATE_DIR/discord-bridge.restarted"
SOCKET="${XDG_RUNTIME_DIR:-/tmp}/quickshell-discord.sock"
HYPR_SIG=""

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

mkdir -p "$STATE_DIR" || exit 0

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"; }
trim_log() {
    [ -f "$LOG_FILE" ] || return 0
    [ "$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 524288 ] || return 0
    tail -n 2000 "$LOG_FILE" >"$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
}

hypr_signature() {
    [ -n "$HYPR_SIG" ] && { printf '%s\n' "$HYPR_SIG"; return 0; }
    local dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
    HYPR_SIG=$(ls -1 "$dir" 2>/dev/null | head -n1)
    [ -n "$HYPR_SIG" ]
}

notify() {
    local msg=$1 sig
    if sig=$(hypr_signature) && command -v hyprctl >/dev/null 2>&1; then
        HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl notify 1 5000 "rgb(a6d189)" "$msg" >/dev/null 2>&1 && return 0
    fi
    command -v notify-send >/dev/null 2>&1 && notify-send "DiscordBridge" "$msg" >/dev/null 2>&1
    return 0
}

# The install Discord actually launches: the "Discord" symlink wins, otherwise
# the newest app-* directory (same preference as Equilotl).
active_dir() {
    if [ -L "$DISCORD_DIR/Discord" ]; then
        local target
        target=$(readlink -f "$DISCORD_DIR/Discord" 2>/dev/null)
        if [ -n "$target" ] && [ -d "$(dirname "$target")/resources" ]; then
            printf '%s\n' "$(dirname "$target")"
            return 0
        fi
    fi
    local newest
    newest=$(find "$DISCORD_DIR" -maxdepth 1 -type d -name 'app-*' -printf '%f\n' 2>/dev/null | sort -V | tail -n1)
    [ -n "$newest" ] && printf '%s\n' "$DISCORD_DIR/$newest"
}

is_patched() { [ -f "$1/resources/_app.asar" ] && [ -f "$1/resources/app.asar" ]; }

# Discord's updater creates the directory before it finishes extracting, so
# wait until app.asar exists, has a plausible size and nothing is still being
# written inside the app directory.
app_ready() {
    local dir=$1 resources="$1/resources" s1 s2
    [ -f "$resources/app.asar" ] || return 1
    [ -n "$(find "$dir" -type f -newermt '-4 seconds' -print -quit 2>/dev/null)" ] && return 1
    s1=$(stat -c %s "$resources/app.asar" 2>/dev/null || echo 0)
    sleep 3
    s2=$(stat -c %s "$resources/app.asar" 2>/dev/null || echo 0)
    [ "$s1" = "$s2" ] && [ "$s1" -gt 1000000 ]
}

discord_main_pid() {
    local pid exe
    for pid in $(pgrep -x Discord 2>/dev/null); do
        [ -r "/proc/$pid/cmdline" ] || continue
        tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q -- '--type=' && continue
        exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null) || continue
        case "$exe" in */Discord) printf '%s\n' "$pid"; return 0 ;; esac
    done
    return 1
}

voice_active() { ss -upH 2>/dev/null | grep -q '"Discord"'; }

# A stale socket file can outlive a crashed Discord; only a listening socket
# means the plugin is actually up.
bridge_listening() { ss -xlH 2>/dev/null | grep -qF "$SOCKET"; }

launch_discord() {
    local sig out
    if sig=$(hypr_signature) && command -v hyprctl >/dev/null 2>&1; then
        # Hyprland 0.5x with a Lua config takes a Lua dispatcher expression;
        # older/simple configs take the classic "exec <cmd>" keyword.
        if out=$(HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl dispatch 'hl.dsp.exec_cmd("/usr/bin/discord")' 2>&1) \
            && ! grep -q '^error' <<<"$out"; then
            return 0
        fi
        if out=$(HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl dispatch exec /usr/bin/discord 2>&1) \
            && ! grep -q '^error' <<<"$out"; then
            return 0
        fi
    fi
    return 1
}

# Restart only when the *running* instance is the directory we just patched and
# has no bridge socket (i.e. it came up unpatched). Never touch a call, never
# kill a Discord that is still mid-update on a different version.
maybe_restart() {
    local dir=$1 pid running_dir age
    pid=$(discord_main_pid) || return 0
    running_dir=$(dirname "$(readlink -f "/proc/$pid/exe" 2>/dev/null)")
    [ "$running_dir" = "$dir" ] || return 0
    bridge_listening && return 0

    if voice_active; then
        log "voice connection active; leaving Discord running"
        notify "Discord patched — restart Discord when your call ends"
        return 0
    fi

    if [ -f "$RESTART_STAMP" ]; then
        age=$(( $(date +%s) - $(stat -c %Y "$RESTART_STAMP" 2>/dev/null || echo 0) ))
        if [ "$age" -lt 300 ]; then
            log "restarted $age s ago; not restarting again"
            return 0
        fi
    fi

    log "restarting Discord (pid $pid) to load the patched bridge"
    kill "$pid" 2>/dev/null
    for _ in $(seq 1 20); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.5
    done
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    touch "$RESTART_STAMP"
    sleep 1

    if launch_discord; then
        log "Discord relaunched"
        notify "Discord updated — bridge re-patched and restarted"
    else
        log "could not relaunch Discord automatically"
        notify "Discord patched — start Discord again"
    fi
}

main() {
    trim_log

    exec 9>"$LOCK_FILE" || exit 0
    if ! flock -n 9; then
        log "another repair is already running; skipping"
        exit 0
    fi

    local dir attempt=0 deadline=$((SECONDS + 600))
    while [ "$SECONDS" -lt "$deadline" ]; do
        dir=$(active_dir) || dir=""

        if [ -z "$dir" ]; then
            log "no Discord install under $DISCORD_DIR yet; waiting"
            sleep 3
            continue
        fi

        if is_patched "$dir"; then
            log "active install ${dir#"$DISCORD_DIR"/} is already patched; nothing to do"
            return 0
        fi

        if ! app_ready "$dir"; then
            sleep 2
            continue
        fi

        attempt=$((attempt + 1))
        log "attempt $attempt: patching ${dir#"$DISCORD_DIR"/}"
        if DISCORD_DIR="$DISCORD_DIR" INSTALL_AUTO_REPAIR=0 bash "$BRIDGE_DIR/install.sh" >>"$LOG_FILE" 2>&1 \
            && is_patched "$dir"; then
            local latest
            latest=$(active_dir) || latest=""
            if [ -n "$latest" ] && [ "$latest" != "$dir" ] && ! is_patched "$latest"; then
                log "active install changed to ${latest#"$DISCORD_DIR"/} while patching; continuing"
                continue
            fi
            log "patched ${dir#"$DISCORD_DIR"/}"
            notify "Discord ${dir##*/} patched — DiscordBridge ready"
            maybe_restart "$dir"
            return 0
        fi

        log "attempt $attempt failed"
        [ "$attempt" -ge 3 ] && break
        sleep 15
    done

    log "auto-repair gave up; see above"
    notify "DiscordBridge auto-repair failed — see $LOG_FILE"
    return 1
}

main "$@"
