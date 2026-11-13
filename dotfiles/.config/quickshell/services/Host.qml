pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    property real cpu: 0
    property real mem: 0
    property real memTotalKB: 0
    property real memAvailKB: 0
    property real load1: 0
    property real load5: 0
    property real load15: 0
    property int cpuFreqMHz: 0
    property int cpuCores: 0
    property int uptime: 0
    property string kernel: ""
    property string hostname: ""
    property string distro: ""

    readonly property real memUsedKB: Math.max(0, memTotalKB - memAvailKB)
    readonly property real memUsedGB: memUsedKB / 1048576
    readonly property real memTotalGB: memTotalKB / 1048576

    property var cpuPrev: null

    readonly property var battery: UPower.displayDevice
    readonly property bool batteryPresent: battery?.isLaptopBattery ?? false
    readonly property real batteryPct: battery?.percentage ?? 0
    readonly property bool batteryCharging: battery?.state === UPowerDeviceState.Charging

    function parseStat(text: string): void {
        const line = text.split("\n").find(l => l.startsWith("cpu "));
        if (!line)
            return;
        const f = line.trim().split(/\s+/).slice(1).map(Number);
        const total = f[0] + f[1] + f[2] + f[4] + f[5] + f[6] + f[7];
        const idle = f[3] + f[4];
        if (cpuPrev) {
            const dTotal = total - cpuPrev.total;
            const dIdle = idle - cpuPrev.idle;
            if (dTotal > 0)
                root.cpu = Math.max(0, Math.min(1, (dTotal - dIdle) / dTotal));
        }
        cpuPrev = {
            "total": total,
            "idle": idle
        };
    }

    function parseMem(text: string): void {
        let total = 0;
        let avail = 0;
        for (const line of text.split("\n")) {
            if (line.startsWith("MemTotal:"))
                total = parseInt(line.split(/\s+/)[1]);
            else if (line.startsWith("MemAvailable:"))
                avail = parseInt(line.split(/\s+/)[1]);
        }
        if (total > 0) {
            root.memTotalKB = total;
            root.memAvailKB = avail;
            root.mem = Math.max(0, Math.min(1, (total - avail) / total));
        }
    }

    function parseLoad(text: string): void {
        const f = text.trim().split(/\s+/);
        root.load1 = parseFloat(f[0]) || 0;
        root.load5 = parseFloat(f[1]) || 0;
        root.load15 = parseFloat(f[2]) || 0;
    }

    function parseFreq(text: string): void {
        const khz = parseInt(text.trim());
        if (!isNaN(khz))
            root.cpuFreqMHz = Math.round(khz / 1000);
    }

    function parseUptime(text: string): void {
        const f = parseFloat(text.split(" ")[0]);
        if (!isNaN(f))
            root.uptime = Math.floor(f);
    }

    function formatUptime(secs: int): string {
        const d = Math.floor(secs / 86400);
        const h = Math.floor((secs % 86400) / 3600);
        const m = Math.floor((secs % 3600) / 60);
        if (d > 0)
            return `${d}d ${h}h ${m}m`;
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            statProc.running = true;
            memProc.running = true;
            uptimeProc.running = true;
            loadProc.running = true;
            freqProc.running = true;
        }
    }

    Process {
        id: statProc

        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStat(text)
        }
    }

    Process {
        id: memProc

        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: root.parseMem(text)
        }
    }

    Process {
        id: uptimeProc

        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: root.parseUptime(text)
        }
    }

    Process {
        id: loadProc

        command: ["cat", "/proc/loadavg"]
        stdout: StdioCollector {
            onStreamFinished: root.parseLoad(text)
        }
    }

    Process {
        id: freqProc

        command: ["cat", "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"]
        stdout: StdioCollector {
            onStreamFinished: root.parseFreq(text)
        }
    }

    Process {
        id: coresProc

        command: ["nproc"]
        stdout: StdioCollector {
            onStreamFinished: root.cpuCores = parseInt(text.trim()) || 0
        }
    }

    Process {
        id: unameProc

        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.kernel = text.trim()
        }
    }

    FileView {
        path: "/proc/sys/kernel/hostname"
        preload: true
        printErrors: false
        onLoaded: root.hostname = text().trim()
    }

    FileView {
        path: "/etc/os-release"
        preload: true
        printErrors: false
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("PRETTY_NAME="));
            if (line)
                root.distro = line.slice("PRETTY_NAME=".length).replace(/"/g, "");
        }
    }

    Component.onCompleted: {
        unameProc.running = true;
        coresProc.running = true;
    }
}
