#!/usr/bin/env bash
# Installs the systemd user path unit that re-patches Discord whenever it
# updates. Re-run safely; unit files are regenerated in place.
set -euo pipefail

BRIDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_PATH="quickshell-discord-bridge.path"

if [ ! -d "$BRIDGE_DIR/systemd" ]; then
    echo "missing $BRIDGE_DIR/systemd" >&2
    exit 1
fi
if [ ! -x "$BRIDGE_DIR/auto-repair.sh" ]; then
    chmod +x "$BRIDGE_DIR/auto-repair.sh"
fi

mkdir -p "$UNIT_DIR"
for unit in quickshell-discord-bridge.service quickshell-discord-bridge.path; do
    sed "s|@BRIDGE_DIR@|${BRIDGE_DIR//&/\\&}|g" \
        "$BRIDGE_DIR/systemd/$unit.in" >"$UNIT_DIR/$unit"
done

if ! systemctl --user daemon-reload; then
    echo "systemd --user is not available; units were written to $UNIT_DIR" >&2
    exit 1
fi
systemctl --user enable --now "$UNIT_PATH"

echo "Discord update auto-repair is enabled ($UNIT_PATH)."
echo "Check it with: systemctl --user status $UNIT_PATH"
