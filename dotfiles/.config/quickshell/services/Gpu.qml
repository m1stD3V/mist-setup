pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// AMD/DRM GPU metrics sourced from sysfs. Polls only while the
// task manager is open.
Singleton {
    id: root

    property bool active: false
    property bool present: false

    property real usage: 0
    property real vramUsedGB: 0
    property real vramTotalGB: 0
    property real gttUsedGB: 0
    property real gttTotalGB: 0
    property real memBusy: 0
    property real tempC: 0
    property real powerW: 0
    property real sclkMHz: 0

    function parse(text: string): void {
        const map = {};
        for (const line of text.trim().split("\n")) {
            const i = line.indexOf("=");
            if (i > 0)
                map[line.slice(0, i)] = line.slice(i + 1);
        }
        present = map.present === "1";
        if (!present)
            return;
        usage = (parseFloat(map.usage) || 0) / 100;
        vramUsedGB = (parseFloat(map.vramUsed) || 0) / 1073741824;
        vramTotalGB = (parseFloat(map.vramTotal) || 0) / 1073741824;
        gttUsedGB = (parseFloat(map.gttUsed) || 0) / 1073741824;
        gttTotalGB = (parseFloat(map.gttTotal) || 0) / 1073741824;
        memBusy = (parseFloat(map.memBusy) || 0) / 100;
        tempC = (parseFloat(map.temp) || 0) / 1000;
        powerW = (parseFloat(map.power) || 0) / 1000000;
        sclkMHz = parseFloat(map.sclk) || 0;
    }

    Process {
        id: proc

        command: ["sh", "-c", "d=$(for p in /sys/class/drm/card*/device; do [ -r $p/gpu_busy_percent ] && { echo $p; break; }; done); if [ -z $d ]; then echo present=0; exit 0; fi; echo present=1; echo usage=$(cat $d/gpu_busy_percent); echo vramUsed=$(cat $d/mem_info_vram_used); echo vramTotal=$(cat $d/mem_info_vram_total); echo gttUsed=$(cat $d/mem_info_gtt_used 2>/dev/null || echo 0); echo gttTotal=$(cat $d/mem_info_gtt_total 2>/dev/null || echo 0); echo memBusy=$(cat $d/mem_busy_percent 2>/dev/null || echo 0); echo temp=$(cat $d/hwmon/hwmon*/temp1_input 2>/dev/null || echo 0); echo power=$(cat $d/hwmon/hwmon*/power1_average 2>/dev/null || echo 0); echo sclk=$(grep '[*]' $d/pp_dpm_sclk 2>/dev/null | head -1 | cut -d' ' -f2)"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true

        onTriggered: {
            if (!proc.running)
                proc.running = true;
        }
    }
}
