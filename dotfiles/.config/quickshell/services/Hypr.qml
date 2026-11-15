pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    // Hyprland posts "activewindowv2" with an empty address when a workspace
    // runs out of windows, but quickshell cannot parse the empty payload and
    // drops the event, so Hyprland.activeToplevel keeps pointing at the window
    // that was focused before the switch. Reject it once it no longer lives on
    // the focused workspace and fall back to that workspace's own last focused
    // window, which is what the bar should show after switching to an empty
    // workspace (nothing) instead of the application that was left behind.
    readonly property var activeToplevel: {
        const workspace = focusedWorkspace;
        const active = Hyprland.activeToplevel;
        if (!workspace)
            return active;
        if (isOnWorkspace(active, workspace))
            return active;
        return focusedToplevel;
    }
    readonly property var focusedToplevel: {
        const workspace = focusedWorkspace;
        if (!workspace)
            return null;
        const lastAddress = String(workspace.lastIpcObject?.lastwindow ?? "");
        if (lastAddress.length === 0)
            return null;
        for (const t of (workspace.toplevels?.values ?? [])) {
            if (addressOf(t) === lastAddress)
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

    function isOnWorkspace(win: var, workspace: var): bool {
        if (!win || !workspace)
            return false;
        // Prefer the live workspace link over lastIpcObject, which stays stale
        // until the toplevel list is refreshed after a move.
        const winWorkspace = win.workspace ?? win.lastIpcObject?.workspace;
        if (!winWorkspace)
            return false;
        return String(winWorkspace.name ?? "") === String(workspace.name ?? "");
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
