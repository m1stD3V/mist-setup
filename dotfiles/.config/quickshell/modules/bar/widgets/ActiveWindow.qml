pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Theme
import qs.components
import qs.services

RText {
    id: root

    property PanelWindow window

    readonly property var toplevel: Hypr.activeToplevel
    readonly property string rawClass: String(toplevel?.lastIpcObject?.class ?? toplevel?.class ?? "").toUpperCase()
    readonly property string appName: {
        const known = {
            "COM.MITCHELLH.GHOSTTY": "GHOSTTY",
            "COM.SPOTIFY.CLIENT": "SPOTIFY",
            "ORG.MOZILLA.FIREFOX": "FIREFOX",
            "COM.GOOGLE.CHROME": "CHROME",
            "COM.MICROSOFT.EDGE": "EDGE",
            "COM.VALVESOFTWARE.STEAM": "STEAM",
            "COM.DISCORDAPP.DISCORD": "DISCORD",
            "ORG.GNOME.NAUTILUS": "FILES"
        };
        if (known[rawClass])
            return known[rawClass];
        const parts = rawClass.split(".");
        return parts.length > 1 ? parts[parts.length - 1] : rawClass;
    }

    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideMiddle
    maximumLineCount: 1
    font.pixelSize: Theme.fontSmall + 2

    text: toplevel ? appName : "NO ACTIVE WINDOW"
    color: toplevel ? Theme.text : Theme.textMuted

    readonly property bool floating: toplevel?.lastIpcObject?.floating ?? toplevel?.floating ?? false
    readonly property bool fullscreen: (toplevel?.lastIpcObject?.fullscreen ?? toplevel?.fullscreen ?? 0) !== 0
    readonly property bool pinned: toplevel?.lastIpcObject?.pinned ?? toplevel?.pinned ?? false
    readonly property string address: {
        const ipcAddr = toplevel?.lastIpcObject?.address;
        if (ipcAddr)
            return ipcAddr;
        const raw = toplevel?.address ?? "";
        return raw.length > 0 && !raw.startsWith("0x") ? "0x" + raw : raw;
    }

    // The popup grabs keyboard focus, which can clear Hypr.activeToplevel.
    // Snapshot the target window so the actions keep working while it is open.
    property string targetAddress: ""
    property string targetName: ""
    property bool targetFloating: false
    property bool targetFullscreen: false
    property bool targetPinned: false

    readonly property string windowArg: targetAddress.length > 0 ? `, window = "address:${targetAddress}"` : ""
    readonly property string windowTable: targetAddress.length > 0 ? `{ window = "address:${targetAddress}" }` : ""

    function closePopup(): void {
        popup.open = false;
    }

    function openMenu(): void {
        if (!toplevel)
            return;
        targetAddress = address;
        targetName = appName;
        targetFloating = floating;
        targetFullscreen = fullscreen;
        targetPinned = pinned;
        popup.open = true;
    }

    function run(action: string): void {
        Hypr.dispatch(action);
        popup.open = false;
    }

    function minimizeWindow(): void {
        run(Hypr.usingLua ? `hl.dsp.window.move({ workspace = "special:minimized", follow = false${windowArg} })` : "movetoworkspacesilent special:minimized");
    }

    function toggleFloating(): void {
        run(Hypr.usingLua ? `hl.dsp.window.float({ action = "toggle"${windowArg} })` : "togglefloating");
    }

    function toggleFullscreen(): void {
        run(Hypr.usingLua ? `hl.dsp.window.fullscreen({ action = "toggle"${windowArg} })` : "fullscreen 0");
    }

    function togglePin(): void {
        run(Hypr.usingLua ? `hl.dsp.window.pin({ action = "toggle"${windowArg} })` : "pin");
    }

    function closeWindow(): void {
        run(Hypr.usingLua ? `hl.dsp.window.close(${windowTable})` : "closewindow address:" + targetAddress);
    }

    TapHandler {
        onPressedChanged: if (pressed)
            ShellState.popupClickGuard = true

        onTapped: {
            if (popup.open)
                popup.open = false;
            else
                root.openMenu();
        }
    }

    BarPopup {
        id: popup

        barWindow: root.window
        screenEdge: "center"
        title: root.targetName || "WINDOW"
        contentWidth: Theme.popupWidth
        contentHeight: 5 * Theme.popupRowHeight + 4 * Theme.popupRowSpacing + Theme.popupChromeHeight
        open: false

        content: Component {
            Column {
                anchors.fill: parent
                spacing: 4

                MenuAction {
                    width: parent.width
                    label: "MINIMIZE"
                    hint: "SPECIAL"
                    onClicked: root.minimizeWindow()
                }

                MenuAction {
                    width: parent.width
                    label: "TOGGLE FLOATING"
                    hint: root.targetFloating ? "TILE" : "FLOAT"
                    onClicked: root.toggleFloating()
                }

                MenuAction {
                    width: parent.width
                    label: root.targetFullscreen ? "EXIT FULLSCREEN" : "FULLSCREEN"
                    hint: root.targetFullscreen ? "RESTORE" : "MAX"
                    onClicked: root.toggleFullscreen()
                }

                MenuAction {
                    width: parent.width
                    label: root.targetPinned ? "UNPIN" : "PIN"
                    hint: root.targetPinned ? "UNPIN" : "PIN"
                    onClicked: root.togglePin()
                }

                MenuAction {
                    width: parent.width
                    label: "CLOSE WINDOW"
                    hint: "KILL"
                    onClicked: root.closeWindow()
                }
            }
        }
    }
}
