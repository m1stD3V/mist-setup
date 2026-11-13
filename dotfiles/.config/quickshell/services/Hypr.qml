pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    readonly property var activeToplevel: Hyprland.activeToplevel ?? focusedToplevel
    readonly property var focusedToplevel: {
        const tops = Hyprland.toplevels?.values ?? [];
        for (const t of tops) {
            const obj = t?.lastIpcObject;
            if (obj && obj.focusHistoryID === 0 && obj.mapped !== false && obj.hidden !== true)
                return t;
        }
        return null;
    }
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor

    readonly property int activeWsId: focusedWorkspace?.id ?? 1
    readonly property bool usingLua: Hyprland.usingLua

    signal configReloaded

    function dispatch(request: string): void {
        Hyprland.dispatch(request);
    }

    function focusWorkspace(ws: var): void {
        dispatch(usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
    }

    function addressOf(win: var): string {
        const ipcAddr = win?.lastIpcObject?.address;
        if (ipcAddr)
            return ipcAddr;
        const raw = win?.address ?? "";
        return raw.length > 0 && !raw.startsWith("0x") ? "0x" + raw : raw;
    }

    function classOf(win: var): string {
        return String(win?.lastIpcObject?.class ?? win?.class ?? "").toUpperCase();
    }

    function workspaceNameOf(win: var): string {
        return String(win?.lastIpcObject?.workspace?.name ?? win?.workspace?.name ?? "");
    }

    function isMinimized(win: var): bool {
        return workspaceNameOf(win).toLowerCase() === "special:minimized";
    }

    function findToplevelByClass(fragment: string): var {
        const needle = fragment.toUpperCase();
        for (const t of (toplevels?.values ?? [])) {
            if (classOf(t).includes(needle))
                return t;
        }
        return null;
    }

    // Windows minimized by the context menu live on special:minimized.
    // Bring one back to the active workspace and focus it.
    function restoreWindow(win: var): bool {
        const addr = addressOf(win);
        if (addr.length === 0)
            return false;
        const ws = activeWsId;
        dispatch(usingLua ? `hl.dsp.window.move({ workspace = ${ws}, follow = false, window = "address:${addr}" })` : `movetoworkspacesilent ${ws},address:${addr}`);
        dispatch(usingLua ? `hl.dsp.focus({ window = "address:${addr}" })` : `focuswindow address:${addr}`);
        return true;
    }

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;

            if (n === "configreloaded") {
                root.configReloaded();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors();
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces();
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels();
            }
        }

        target: Hyprland
    }
}
