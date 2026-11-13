pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property real level: -1

    function show(): void {
        readProc.running = true;
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
                    ShellState.showOsd("brightness", root.level, false);
                }
            }
        }
    }
}
