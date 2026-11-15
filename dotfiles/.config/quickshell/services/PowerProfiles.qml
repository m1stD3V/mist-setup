pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Platform power profiles from power-profiles-daemon. `powerprofilesctl list`
// marks the active profile with a leading "*"; `set` switches it.
Singleton {
    id: root

    property var profiles: []
    property string activeProfile: ""
    property bool available: false
    property bool switching: false
    property string error: ""

    function profileLabel(name: string): string {
        switch (name) {
        case "power-saver":
            return "POWER SAVER";
        case "balanced":
            return "BALANCED";
        case "performance":
            return "PERFORMANCE";
        default:
            return name.replace(/-/g, " ").toUpperCase();
        }
    }

    function parseList(text: string): void {
        const rows = [];
        let active = "";
        for (const raw of text.split("\n")) {
            // profile headers only; driver detail lines are indented further
            const m = raw.match(/^(\*?)\s*([a-z0-9][a-z0-9-]*):\s*$/);
            if (!m)
                continue;
            const name = m[2];
            if (m[1] === "*")
                active = name;
            rows.push({
                "name": name,
                "label": profileLabel(name)
            });
        }
        if (rows.length === 0) {
            available = false;
            profiles = [];
            return;
        }
        profiles = rows;
        activeProfile = active;
        available = true;
    }

    function refresh(): void {
        if (listProc.running)
            return;
        listProc.running = true;
    }

    function setProfile(name: string): void {
        if (!available || switching || name === activeProfile)
            return;
        error = "";
        switching = true;
        setProc.command = ["powerprofilesctl", "set", name];
        setProc.running = true;
    }

    Process {
        id: listProc

        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.parseList(text)
        }

        onExited: (code, status) => {
            if (code !== 0) {
                root.available = false;
                root.profiles = [];
            }
        }
    }

    Process {
        id: setProc

        onExited: (code, status) => {
            root.switching = false;
            if (code !== 0)
                root.error = "PROFILE SWITCH FAILED";
            root.refresh();
        }
    }

    Component.onCompleted: refresh()
}
