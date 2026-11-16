pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Theme
import qs.services

// Persisted user settings for the bar and shell. Kept separate from Theme so
// the settings panel can update live values without rebuilding the shell.
//
// The file is per user (XDG_STATE_HOME) and every field is validated on load,
// so a hand-edited, truncated or older file can never put the shell into an
// unusable state — important when the same dotfiles are deployed to several
// machines and user accounts.
Singleton {
    id: root

    readonly property int schemaVersion: 2
    readonly property string configDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/mist"
    readonly property string savePath: configDir + "/settings.json"

    property bool loaded: false

    property int barHeight: 40
    property real barOpacity: 0.78
    property bool showMenu: true
    property bool showSearch: true
    property bool showWorkspaces: true
    property int workspaceCount: 5
    property bool showActiveWindow: true
    property bool showTray: true
    property bool showBattery: true
    property bool showControlCenter: true
    property bool showDiscord: true
    property bool showClock: true
    property bool clock24h: true
    property bool clockSeconds: true
    property bool dnd: false
    property bool lockEnabled: true
    property int lockTimeout: 5
    property bool lockOnSleep: true

    // extra timezones shown in the clock popup's WORLD tab. Empty by default:
    // a shared dotfiles repo should not decide which cities a user cares about.
    property var worldZones: []

    // keybind id -> combo overrides, applied by the generated
    // ~/.config/hypr/keybinds.lua file
    property var keybinds: ({})

    function _zones(value: var, fallback: var): var {
        if (!Array.isArray(value))
            return fallback;
        const out = [];
        for (const zone of value) {
            if (typeof zone !== "string")
                continue;
            if (!/^[A-Za-z0-9_+\-\/]{2,48}$/.test(zone))
                continue;
            if (out.indexOf(zone) !== -1)
                continue;
            out.push(zone);
            if (out.length >= 8)
                break;
        }
        return out;
    }

    function _keybinds(value: var): var {
        if (!value || typeof value !== "object" || Array.isArray(value))
            return {};
        const out = {};
        for (const key of Object.keys(value)) {
            if (!/^[a-z0-9-]{1,64}$/.test(key))
                continue;
            const combo = value[key];
            if (typeof combo !== "string" || combo.length === 0 || combo.length > 80)
                continue;
            if (!/^[A-Za-z0-9_+ :\-]+$/.test(combo))
                continue;
            out[key] = combo;
        }
        return out;
    }

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
        workspaceCount = 5;
        showActiveWindow = true;
        showTray = true;
        showBattery = true;
        showControlCenter = true;
        showDiscord = true;
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
        if (!data || typeof data !== "object" || Array.isArray(data))
            data = {};

        barHeight = _int(data.barHeight, barHeight);
        barOpacity = Math.max(0.05, Math.min(1, _real(data.barOpacity, barOpacity)));
        showMenu = _bool(data.showMenu, showMenu);
        showSearch = _bool(data.showSearch, showSearch);
        showWorkspaces = _bool(data.showWorkspaces, showWorkspaces);
        workspaceCount = Math.max(1, Math.min(32, _int(data.workspaceCount, workspaceCount)));
        showActiveWindow = _bool(data.showActiveWindow, showActiveWindow);
        showTray = _bool(data.showTray, showTray);
        showBattery = _bool(data.showBattery, showBattery);
        showControlCenter = _bool(data.showControlCenter, showControlCenter);
        showDiscord = _bool(data.showDiscord, showDiscord);
        showClock = _bool(data.showClock, showClock);
        clock24h = _bool(data.clock24h, clock24h);
        clockSeconds = _bool(data.clockSeconds, clockSeconds);
        dnd = _bool(data.dnd, dnd);
        lockEnabled = _bool(data.lockEnabled, lockEnabled);
        lockTimeout = Math.max(1, Math.min(60, _int(data.lockTimeout, lockTimeout)));
        lockOnSleep = _bool(data.lockOnSleep, lockOnSleep);
        worldZones = _zones(data.worldZones, worldZones);
        keybinds = _keybinds(data.keybinds);

        loaded = true;
        applyBarHeight();
        applyBarOpacity();
        applyDnd();
    }

    function toObject(): var {
        return {
            "version": schemaVersion,
            "barHeight": barHeight,
            "barOpacity": barOpacity,
            "showMenu": showMenu,
            "showSearch": showSearch,
            "showWorkspaces": showWorkspaces,
            "workspaceCount": workspaceCount,
            "showActiveWindow": showActiveWindow,
            "showTray": showTray,
            "showBattery": showBattery,
            "showControlCenter": showControlCenter,
            "showDiscord": showDiscord,
            "showClock": showClock,
            "clock24h": clock24h,
            "clockSeconds": clockSeconds,
            "dnd": dnd,
            "lockEnabled": lockEnabled,
            "lockTimeout": lockTimeout,
            "lockOnSleep": lockOnSleep,
            "worldZones": worldZones,
            "keybinds": keybinds
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
    onWorkspaceCountChanged: root.changed()
    onShowActiveWindowChanged: root.changed()
    onShowTrayChanged: root.changed()
    onShowBatteryChanged: root.changed()
    onShowControlCenterChanged: root.changed()
    onShowDiscordChanged: root.changed()
    onShowClockChanged: root.changed()
    onClock24hChanged: root.changed()
    onClockSecondsChanged: root.changed()
    onLockEnabledChanged: root.changed()
    onLockTimeoutChanged: root.changed()
    onLockOnSleepChanged: root.changed()
    onWorldZonesChanged: root.changed()
    onKeybindsChanged: root.changed()

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
