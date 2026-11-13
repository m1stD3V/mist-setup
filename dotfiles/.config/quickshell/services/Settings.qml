pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Theme
import qs.services

// Persisted user settings for the bar and shell. Kept separate from Theme so
// the settings panel can update live values without rebuilding the shell.
Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/mist"
    readonly property string savePath: configDir + "/settings.json"

    property bool loaded: false

    property int barHeight: 40
    property real barOpacity: 0.78
    property bool showMenu: true
    property bool showSearch: true
    property bool showWorkspaces: true
    property bool showActiveWindow: true
    property bool showTray: true
    property bool showBattery: true
    property bool showNotifications: true
    property bool showDiscord: true
    property bool showVolume: true
    property bool showClock: true
    property bool clock24h: true
    property bool clockSeconds: true
    property bool dnd: false

    function _bool(value: var, fallback: bool): bool {
        return typeof value === "boolean" ? value : fallback;
    }

    function _int(value: var, fallback: int): int {
        return typeof value === "number" && isFinite(value) ? Math.round(value) : fallback;
    }

    function _real(value: var, fallback: real): real {
        return typeof value === "number" && isFinite(value) ? value : fallback;
    }

    function resetBar(): void {
        barHeight = 40;
        barOpacity = 0.78;
        showMenu = true;
        showSearch = true;
        showWorkspaces = true;
        showActiveWindow = true;
        showTray = true;
        showBattery = true;
        showNotifications = true;
        showDiscord = true;
        showVolume = true;
        showClock = true;
        clock24h = true;
        clockSeconds = true;
    }

    function applyBarHeight(): void {
        Theme.barHeight = Math.max(28, Math.min(64, barHeight));
    }

    function applyBarOpacity(): void {
        Theme.barOpacity = Math.max(0.05, Math.min(1, barOpacity));
    }

    function applyDnd(): void {
        Notifs.dnd = dnd;
    }

    function loadFrom(text: string): void {
        let data = {};
        try {
            data = JSON.parse(text);
        } catch (e) {
            data = {};
        }

        barHeight = _int(data.barHeight, barHeight);
        barOpacity = Math.max(0.05, Math.min(1, _real(data.barOpacity, barOpacity)));
        showMenu = _bool(data.showMenu, showMenu);
        showSearch = _bool(data.showSearch, showSearch);
        showWorkspaces = _bool(data.showWorkspaces, showWorkspaces);
        showActiveWindow = _bool(data.showActiveWindow, showActiveWindow);
        showTray = _bool(data.showTray, showTray);
        showBattery = _bool(data.showBattery, showBattery);
        showNotifications = _bool(data.showNotifications, showNotifications);
        showDiscord = _bool(data.showDiscord, showDiscord);
        showVolume = _bool(data.showVolume, showVolume);
        showClock = _bool(data.showClock, showClock);
        clock24h = _bool(data.clock24h, clock24h);
        clockSeconds = _bool(data.clockSeconds, clockSeconds);
        dnd = _bool(data.dnd, dnd);

        loaded = true;
        applyBarHeight();
        applyBarOpacity();
        applyDnd();
    }

    function toObject(): var {
        return {
            "barHeight": barHeight,
            "barOpacity": barOpacity,
            "showMenu": showMenu,
            "showSearch": showSearch,
            "showWorkspaces": showWorkspaces,
            "showActiveWindow": showActiveWindow,
            "showTray": showTray,
            "showBattery": showBattery,
            "showNotifications": showNotifications,
            "showDiscord": showDiscord,
            "showVolume": showVolume,
            "showClock": showClock,
            "clock24h": clock24h,
            "clockSeconds": clockSeconds,
            "dnd": dnd
        };
    }

    function save(): void {
        if (!loaded)
            return;
        stateFile.setText(JSON.stringify(toObject(), null, 2) + "\n");
    }

    function changed(): void {
        if (loaded)
            saveTimer.restart();
    }

    onBarHeightChanged: {
        root.applyBarHeight();
        root.changed();
    }

    onBarOpacityChanged: {
        root.applyBarOpacity();
        root.changed();
    }

    onDndChanged: {
        root.applyDnd();
        root.changed();
    }

    onShowMenuChanged: root.changed()
    onShowSearchChanged: root.changed()
    onShowWorkspacesChanged: root.changed()
    onShowActiveWindowChanged: root.changed()
    onShowTrayChanged: root.changed()
    onShowBatteryChanged: root.changed()
    onShowNotificationsChanged: root.changed()
    onShowDiscordChanged: root.changed()
    onShowVolumeChanged: root.changed()
    onShowClockChanged: root.changed()
    onClock24hChanged: root.changed()
    onClockSecondsChanged: root.changed()

    Connections {
        function onDndChanged(): void {
            if (root.loaded && root.dnd !== Notifs.dnd)
                root.dnd = Notifs.dnd;
        }

        target: Notifs
    }

    Timer {
        id: saveTimer

        interval: 180
        onTriggered: root.save()
    }

    FileView {
        id: stateFile

        path: root.savePath
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.configDir]);
        root.loadFrom(stateFile.text());
    }
}
