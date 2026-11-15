#!/usr/bin/env bash
# Builds Equicord with the DiscordBridge userplugin and injects it into the
# local Discord install. Re-run this after a Discord update if the widget
# stops reporting state.
set -euo pipefail

BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$BRIDGE_DIR/plugin"
SRC_DIR="${EQUICORD_DIR:-$HOME/.local/share/equicord}"
DISCORD_DIR="${DISCORD_DIR:-$HOME/.config/discord}"

if ! command -v node >/dev/null 2>&1; then
    echo "node is required" >&2
    exit 1
fi
if ! command -v git >/dev/null 2>&1; then
    echo "git is required" >&2
    exit 1
fi
if [ ! -d "$DISCORD_DIR" ]; then
    echo "Discord install not found at $DISCORD_DIR (set DISCORD_DIR to override)" >&2
    exit 1
fi

if [ ! -d "$SRC_DIR/.git" ]; then
    echo "==> cloning Equicord into $SRC_DIR"
    git clone --depth 1 https://github.com/Equicord/Equicord.git "$SRC_DIR"
else
    echo "==> using existing Equicord checkout at $SRC_DIR"
fi

mkdir -p "$SRC_DIR/src/userplugins"
rm -rf "$SRC_DIR/src/userplugins/discordBridge.desktop"
cp -r "$PLUGIN_DIR" "$SRC_DIR/src/userplugins/discordBridge.desktop"

PM="pnpm"
if ! command -v pnpm >/dev/null 2>&1; then
    PM="npx --yes pnpm@latest"
fi

echo "==> installing dependencies"
$PM --dir "$SRC_DIR" install

echo "==> building Equicord + DiscordBridge"
$PM --dir "$SRC_DIR" build

echo "==> injecting into $DISCORD_DIR"
node "$SRC_DIR/scripts/runInstaller.mjs" -- --install --location "$DISCORD_DIR"

AUTO_REPAIR="${INSTALL_AUTO_REPAIR:-1}"
if [ "$AUTO_REPAIR" = "1" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    echo "==> installing auto-repair for Discord updates"
    if ! "$BRIDGE_DIR/setup-auto-repair.sh"; then
        echo "warning: could not install the auto-repair service." >&2
        echo "         run $BRIDGE_DIR/setup-auto-repair.sh manually." >&2
    fi
fi

echo
echo "Done. Restart Discord to load DiscordBridge."
echo "Then enable it under Settings > Equicord > Plugins > DiscordBridge."
if [ "$AUTO_REPAIR" = "1" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    echo "Discord updates will be re-patched automatically."
fi
