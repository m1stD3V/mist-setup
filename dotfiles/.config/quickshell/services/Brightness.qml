pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property real level: -1

    // true only for a keybind/OSD-style request; a quiet refresh from the
    // control center must not pop the OSD every time the panel opens
    property bool _announce: false
    property real _pending: -1

    function show(): void {
        _announce = true;
        readProc.running = true;
    }

    function refresh(): void {
        _announce = false;
        readProc.running = true;
    }

    // Drag-friendly setter: brightnessctl is spawned at most once per timer
    // tick so a slider drag does not fork a process per mouse move.
    function setLevel(value: real): void {
        const pct = Math.max(0, Math.min(1, value));
        if (Math.abs(pct - level) < 0.005)
            return;
        level = pct;
        _pending = pct;
    }

    Process {
        id: readProc

        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] ?? "";
                const parts = line.split(",");
                const pct = parseInt(parts[3]);
                if (!isNaN(pct)) {
                    root.level = pct / 100;
                    if (root._announce)
                        ShellState.showOsd("brightness", root.level, false);
                }
            }
        }
    }

    Timer {
        id: setTimer

        interval: 60
        repeat: true
        running: root._pending >= 0

        onTriggered: {
            if (setProc.running)
                return;
            setProc.command = ["brightnessctl", "set", Math.round(root._pending * 100) + "%"];
            setProc.running = true;
            root._pending = -1;
        }
    }

    Process {
        id: setProc
    }
}
