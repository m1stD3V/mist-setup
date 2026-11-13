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
    property string appsTab: "processes"
    // set at press-time by popup buttons so the bar background tap
    // does not close the very popup the same click just opened
    property bool popupClickGuard: false

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

    function toggleLauncher(): void {
        launcherOpen = !launcherOpen;
        if (launcherOpen) {
            sysmonOpen = false;
            sessionOpen = false;
            appsOpen = false;
            settingsOpen = false;
        }
    }

    function toggleSysmon(): void {
        sysmonOpen = !sysmonOpen;
        if (sysmonOpen) {
            launcherOpen = false;
            sessionOpen = false;
            appsOpen = false;
            settingsOpen = false;
        }
    }

    function toggleSession(): void {
        sessionOpen = !sessionOpen;
        if (sessionOpen) {
            launcherOpen = false;
            sysmonOpen = false;
            appsOpen = false;
            settingsOpen = false;
        }
    }

    function closeAll(): void {
        launcherOpen = false;
        sysmonOpen = false;
        sessionOpen = false;
        wallpaperOpen = false;
        appsOpen = false;
        settingsOpen = false;
    }

    function toggleWallpaper(): void {
        wallpaperOpen = !wallpaperOpen;
        if (wallpaperOpen) {
            launcherOpen = false;
            sysmonOpen = false;
            sessionOpen = false;
            appsOpen = false;
            settingsOpen = false;
        }
    }

    function toggleSettings(): void {
        settingsOpen = !settingsOpen;
        if (settingsOpen) {
            launcherOpen = false;
            sysmonOpen = false;
            sessionOpen = false;
            wallpaperOpen = false;
            appsOpen = false;
        }
    }

    function toggleApps(): void {
        if (appsOpen) {
            appsOpen = false;
            return;
        }
        appsTab = "processes";
        appsOpen = true;
        launcherOpen = false;
        sysmonOpen = false;
        sessionOpen = false;
        wallpaperOpen = false;
        settingsOpen = false;
    }

    function openApps(tab: string): void {
        appsTab = tab;
        appsOpen = true;
        launcherOpen = false;
        sysmonOpen = false;
        sessionOpen = false;
        wallpaperOpen = false;
        settingsOpen = false;
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
