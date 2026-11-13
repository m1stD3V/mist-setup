pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live process list for the applications panel. Polling only runs
// while the panel is open.
Singleton {
    id: root

    property var list: []
    property bool active: false

    function refresh(): void {
        if (!proc.running)
            proc.running = true;
    }

    function _killable(pid: int): bool {
        if (pid <= 1)
            return false;
        const row = list.find(p => p.pid === pid);
        return !!row && !row.name.toLowerCase().includes("quickshell");
    }

    function kill(pid: int): void {
        if (!_killable(pid))
            return;
        Quickshell.execDetached(["kill", String(pid)]);
        refreshSoon.restart();
    }

    function forceKill(pid: int): void {
        if (!_killable(pid))
            return;
        Quickshell.execDetached(["kill", "-9", String(pid)]);
        refreshSoon.restart();
    }

    function parse(text: string): void {
        const rows = [];
        for (const line of text.split("\n")) {
            const m = line.trim().match(/^(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/);
            if (!m)
                continue;
            rows.push({
                "pid": parseInt(m[1]),
                "ppid": parseInt(m[2]),
                "user": m[3],
                "status": m[4],
                "cpu": parseFloat(m[5]) || 0,
                "mem": parseFloat(m[6]) || 0,
                "rssKB": parseInt(m[7]) || 0,
                "threads": parseInt(m[8]) || 0,
                "elapsed": parseInt(m[9]) || 0,
                "name": m[10]
            });
        }
        list = rows;
    }

    Process {
        id: proc

        command: ["ps", "-eo", "pid=,ppid=,user=,stat=,pcpu=,pmem=,rss=,nlwp=,etimes=,comm=", "--sort=-pcpu"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true

        onTriggered: root.refresh()
    }

    Timer {
        id: refreshSoon

        interval: 350

        onTriggered: root.refresh()
    }
}
