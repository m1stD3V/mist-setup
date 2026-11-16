pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

// Active window title + per-window actions.
//
// The popup takes focus, which can clear Hyprland.activeToplevel, so the
// target window is snapshotted when the menu opens. Every action that needs a
// window address is disabled when the snapshot is empty: without an address
// Hyprland would apply the command to whatever is focused instead, which is how
// "close window" could close the wrong thing.
RText {
    id: root

    property var window: null
    // null for the whole window when the address is unknown
    property string targetAddress: ""
    property string targetName: ""
    property bool targetFloating: false
    property bool targetFullscreen: false
    property bool targetPinned: false

    readonly property var toplevel: Hypr.activeToplevel
    readonly property string appName: {
        const raw = Hypr.classOf(root.toplevel);
        if (root.knownApps[raw])
            return root.knownApps[raw];
        const parts = raw.split(".");
        return parts.length > 1 ? parts[parts.length - 1] : raw;
    }
    readonly property string address: Hypr.addressOf(root.toplevel)
    readonly property bool floating: root.toplevel?.lastIpcObject?.floating ?? root.toplevel?.floating ?? false
    readonly property bool fullscreen: (root.toplevel?.lastIpcObject?.fullscreen ?? root.toplevel?.fullscreen ?? 0) !== 0
    readonly property bool pinned: root.toplevel?.lastIpcObject?.pinned ?? root.toplevel?.pinned ?? false
    readonly property bool hasTarget: root.targetAddress.length > 0

    // Hoisted out of the binding: rebuilt on every class change otherwise.
    readonly property var knownApps: ({
            "COM.MITCHELLH.GHOSTTY": "GHOSTTY",
            "COM.SPOTIFY.CLIENT": "SPOTIFY",
            "ORG.MOZILLA.FIREFOX": "FIREFOX",
            "COM.GOOGLE.CHROME": "CHROME",
            "COM.MICROSOFT.EDGE": "EDGE",
            "COM.VALVESOFTWARE.STEAM": "STEAM",
            "COM.DISCORDAPP.DISCORD": "DISCORD",
            "ORG.GNOME.NAUTILUS": "FILES",
            "ORG.KDE.DOLPHIN": "FILES",
            "ORG.KDE.KONSOLE": "KONSOLE",
            "ALACRITTY": "ALACRITTY",
            "KITTY": "KITTY"
        })

    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideMiddle
    maximumLineCount: 1
    leftPadding: 7
    rightPadding: 7
    font.pixelSize: Theme.fontSmall + 2

    text: root.toplevel ? root.appName : qsTr("NO ACTIVE WINDOW")
    color: root.toplevel ? Theme.text : Theme.textMuted

    // A window title is noise once the bar has no room for it; the module is
    // hidden by the bar instead of being cut in half.

    function closePopup(): void {
        popup.open = false;
    }

    function openMenu(): void {
        if (!root.toplevel)
            return;
        root.targetAddress = root.address;
        root.targetName = root.appName;
        root.targetFloating = root.floating;
        root.targetFullscreen = root.fullscreen;
        root.targetPinned = root.pinned;
        popup.open = true;
    }

    function run(action: string): void {
        Hypr.dispatch(action);
        popup.open = false;
    }

    // `window = "address:0x…"` / `{ window = "address:0x…" }` fragments for the
    // Lua dispatcher, empty when there is no target.
    readonly property string luaWindowArg: root.hasTarget ? `, window = "address:${root.targetAddress}"` : ""
    readonly property string luaWindowTable: root.hasTarget ? `{ window = "address:${root.targetAddress}" }` : ""

    function minimizeWindow(): void {
        if (!root.hasTarget)
            return;
        root.run(Hypr.usingLua ? `hl.dsp.window.move({ workspace = "special:minimized", follow = false${root.luaWindowArg} })` : "movetoworkspacesilent special:minimized");
    }

    function toggleFloating(): void {
        if (!root.hasTarget)
            return;
        root.run(Hypr.usingLua ? `hl.dsp.window.float({ action = "toggle"${root.luaWindowArg} })` : "togglefloating");
    }

    function toggleFullscreen(): void {
        if (!root.hasTarget)
            return;
        root.run(Hypr.usingLua ? `hl.dsp.window.fullscreen({ action = "toggle"${root.luaWindowArg} })` : "fullscreen 0");
    }

    function togglePin(): void {
        if (!root.hasTarget)
            return;
        root.run(Hypr.usingLua ? `hl.dsp.window.pin({ action = "toggle"${root.luaWindowArg} })` : "pin");
    }

    function closeWindow(): void {
        if (!root.hasTarget)
            return;
        root.run(Hypr.usingLua ? `hl.dsp.window.close(${root.luaWindowTable})` : "closewindow address:" + root.targetAddress);
    }

    TapHandler {
        onPressedChanged: {
            if (pressed && root.window && root.window.armPopupGuard)
                root.window.armPopupGuard();
        }
        onTapped: {
            if (popup.open)
                popup.open = false;
            else
                root.openMenu();
        }
    }

    onVisibleChanged: if (!visible)
        popup.open = false

    BarPopup {
        id: popup

        barWindow: root.window
        screenEdge: "center"
        title: root.targetName || "WINDOW"
        contentWidth: Theme.popupWidth
        open: false

        content: Component {
            Column {
                width: parent.width
                spacing: Theme.popupRowSpacing

                MenuAction {
                    width: parent.width
                    label: "MINIMIZE"
                    hint: "SPECIAL"
                    enabled: root.hasTarget
                    onClicked: root.minimizeWindow()
                }

                MenuAction {
                    width: parent.width
                    label: "TOGGLE FLOATING"
                    hint: root.targetFloating ? "TILE" : "FLOAT"
                    enabled: root.hasTarget
                    onClicked: root.toggleFloating()
                }

                MenuAction {
                    width: parent.width
                    label: root.targetFullscreen ? "EXIT FULLSCREEN" : "FULLSCREEN"
                    hint: root.targetFullscreen ? "RESTORE" : "MAX"
                    enabled: root.hasTarget
                    onClicked: root.toggleFullscreen()
                }

                MenuAction {
                    width: parent.width
                    label: root.targetPinned ? "UNPIN" : "PIN"
                    hint: root.targetPinned ? "UNPIN" : "PIN"
                    enabled: root.hasTarget
                    onClicked: root.togglePin()
                }

                MenuAction {
                    width: parent.width
                    label: "CLOSE WINDOW"
                    hint: "KILL"
                    enabled: root.hasTarget
                    onClicked: root.closeWindow()
                }
            }
        }
    }
}
