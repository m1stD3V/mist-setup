pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Aggregate read/write throughput of whole physical disks (partitions
// excluded) from /proc/diskstats.
Singleton {
    id: root

    property bool active: false
    property real readBps: 0
    property real writeBps: 0

    property real _prevRead: -1
    property real _prevWrite: -1
    property double _prevTime: 0

    function parse(text: string): void {
        const lines = text.trim().split("\n");
        if (lines.length < 2)
            return;
        const read = parseFloat(lines[0]) || 0;
        const write = parseFloat(lines[1]) || 0;
        const now = Date.now();

        if (_prevTime > 0) {
            const dt = Math.max(0.2, (now - _prevTime) / 1000);
            readBps = Math.max(0, (read - _prevRead) / dt);
            writeBps = Math.max(0, (write - _prevWrite) / dt);
        }

        _prevRead = read;
        _prevWrite = write;
        _prevTime = now;
    }

    Process {
        id: proc

        command: ["sh", "-c", "awk '$3 ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|mmcblk[0-9]+|xvd[a-z]+|md[0-9]+)$/ {r+=$6; w+=$10} END {print r*512; print w*512}' /proc/diskstats"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true

        onTriggered: {
            if (!proc.running)
                proc.running = true;
        }
    }
}
