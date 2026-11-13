pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Aggregate network throughput for the default-route interface.
Singleton {
    id: root

    property bool active: false
    property string iface: ""
    property real rxBps: 0
    property real txBps: 0

    property real _prevRx: -1
    property real _prevTx: -1
    property double _prevTime: 0
    property string _prevIface: ""

    function parse(text: string): void {
        const map = {};
        for (const line of text.trim().split("\n")) {
            const i = line.indexOf("=");
            if (i > 0)
                map[line.slice(0, i)] = line.slice(i + 1);
        }
        const name = map.iface ?? "";
        const rx = parseFloat(map.rx) || 0;
        const tx = parseFloat(map.tx) || 0;
        const now = Date.now();

        if (name !== _prevIface) {
            iface = name;
            _prevIface = name;
            _prevRx = rx;
            _prevTx = tx;
            _prevTime = now;
            rxBps = 0;
            txBps = 0;
            return;
        }

        if (_prevTime > 0) {
            const dt = Math.max(0.2, (now - _prevTime) / 1000);
            rxBps = Math.max(0, (rx - _prevRx) / dt);
            txBps = Math.max(0, (tx - _prevTx) / dt);
        }

        _prevRx = rx;
        _prevTx = tx;
        _prevTime = now;
    }

    Process {
        id: proc

        command: ["sh", "-c", "iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}'); [ -z $iface ] && iface=$(ls /sys/class/net | grep -v lo | head -1); echo iface=$iface; echo rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0); echo tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)"]
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
