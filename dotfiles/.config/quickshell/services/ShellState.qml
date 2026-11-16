pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property bool launcherOpen: false
    property bool sysmonOpen: false
    property bool sessionOpen: false
    property bool wallpaperOpen: false
    property bool appsOpen: false
    property bool settingsOpen: false
    property bool clipboardOpen: false
    property string appsTab: "processes"
    // small bar popup currently open; opening another closes it first. The
    // "don't dismiss the popup this click just opened" guard lives on each Bar
    // (timestamped), because popups are per screen and a global flag let one
    // monitor swallow another's clicks.
    property var activePopup: null

    // OSD state
    property string osdKind: ""
    property real osdValue: 0
    property bool osdMuted: false
    property bool osdVisible: false

    function showOsd(kind: string, value: real, muted: bool): void {
        osdKind = kind;
        osdValue = value;
        osdMuted = muted;
        osdVisible = true;
        osdTimer.restart();
    }

    // Centred overlays are mutually exclusive: opening one closes the rest.
    function closeOverlays(keep: string): void {
        if (keep !== "launcher")
            launcherOpen = false;
        if (keep !== "sysmon")
            sysmonOpen = false;
        if (keep !== "session")
            sessionOpen = false;
        if (keep !== "wallpaper")
            wallpaperOpen = false;
        if (keep !== "apps")
            appsOpen = false;
        if (keep !== "settings")
            settingsOpen = false;
        if (keep !== "clipboard")
            clipboardOpen = false;
    }

    function toggleLauncher(): void {
        const open = !launcherOpen;
        if (open) {
            dismissPopup();
            closeOverlays("launcher");
        }
        launcherOpen = open;
    }

    function toggleSysmon(): void {
        const open = !sysmonOpen;
        if (open) {
            dismissPopup();
            closeOverlays("sysmon");
        }
        sysmonOpen = open;
    }

    function toggleSession(): void {
        const open = !sessionOpen;
        if (open) {
            dismissPopup();
            closeOverlays("session");
        }
        sessionOpen = open;
    }

    function toggleWallpaper(): void {
        const open = !wallpaperOpen;
        if (open) {
            dismissPopup();
            closeOverlays("wallpaper");
        }
        wallpaperOpen = open;
    }

    function toggleSettings(): void {
        const open = !settingsOpen;
        if (open) {
            dismissPopup();
            closeOverlays("settings");
        }
        settingsOpen = open;
    }

    function toggleClipboard(): void {
        const open = !clipboardOpen;
        if (open) {
            dismissPopup();
            closeOverlays("clipboard");
        }
        clipboardOpen = open;
    }

    function toggleApps(): void {
        if (appsOpen) {
            appsOpen = false;
            return;
        }
        appsTab = "processes";
        dismissPopup();
        closeOverlays("apps");
        appsOpen = true;
    }

    function openApps(tab: string): void {
        appsTab = tab;
        dismissPopup();
        closeOverlays("apps");
        appsOpen = true;
    }

    function closeAll(): void {
        dismissPopup();
        closeOverlays("");
    }

    function dismissPopup(): void {
        if (activePopup)
            activePopup.open = false;
    }

    function activatePopup(popup: var): void {
        if (activePopup && activePopup !== popup)
            activePopup.open = false;
        activePopup = popup;
    }

    function deactivatePopup(popup: var): void {
        if (activePopup === popup)
            activePopup = null;
    }

    Timer {
        id: osdTimer

        interval: 1600
        onTriggered: root.osdVisible = false
    }

    // Volume OSD follows live audio state
    property real _lastVolume: -1
    property bool _lastMuted: false
    property real _bootTime: Date.now()

    function _audioChanged(): void {
        if (Date.now() - _bootTime < 8000)
            return;
        if (Audio.volume !== _lastVolume || Audio.muted !== _lastMuted) {
            _lastVolume = Audio.volume;
            _lastMuted = Audio.muted;
            showOsd("volume", Audio.volume, Audio.muted);
        }
    }

    onLauncherOpenChanged: {
        if (!launcherOpen)
            Launcher.query = "";
    }

    Component.onCompleted: {
        Audio.volumeChanged.connect(_audioChanged);
        Audio.mutedChanged.connect(_audioChanged);
    }
}
