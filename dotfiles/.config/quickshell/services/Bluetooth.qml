pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Bluetooth control through bluetoothctl. Quickshell 0.3 has no Bluetooth
// service, so the adapter state and the device list are polled from the CLI;
// every invocation is bounded by `timeout` and gets /dev/null on stdin,
// because bluetoothctl otherwise sits in its interactive loop forever.
Singleton {
    id: root

    // ---- adapter ----
    property bool available: false
    property bool powered: false
    property bool discovering: false

    // ---- devices: [{ mac, name, paired, connected }] ----
    property var devices: []

    // scanning is only wanted while the panel is open
    property bool wantScan: false

    // ---- feedback for the panel ----
    property bool busy: false
    property string message: ""
    property bool messageError: false

    property string _signature: ""

    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property int connectedCount: connectedDevices.length

    // bluetoothctl prints ANSI colour codes even without a tty
    function _clean(text: string): string {
        return text.replace(/\u001b\[[0-9;]*m/g, "");
    }

    function _macs(block: string): var {
        const out = {};
        for (const raw of block.split("\n")) {
            const m = _clean(raw).match(/^Device ([0-9A-Fa-f:]{17})/);
            if (m)
                out[m[1].toUpperCase()] = true;
        }
        return out;
    }

    function _ingest(raw: string): void {
        const blocks = _clean(raw).split("@@\n");
        const show = blocks[0] ?? "";
        const all = blocks[1] ?? "";
        const pairedBlock = blocks[2] ?? "";
        const connectedBlock = blocks[3] ?? "";

        let hasAdapter = false;
        let isPowered = false;
        let isDiscovering = false;

        for (const line of show.split("\n")) {
            const text = line.trim();
            if (text.startsWith("Controller "))
                hasAdapter = true;
            else if (text.startsWith("Powered:"))
                isPowered = text.slice(8).trim() === "yes";
            else if (text.startsWith("Discovering:"))
                isDiscovering = text.slice(12).trim() === "yes";
        }

        const paired = _macs(pairedBlock);
        const connected = _macs(connectedBlock);

        const names = {};
        for (const raw2 of all.split("\n")) {
            const line = _clean(raw2).trim();
            const m = line.match(/^Device ([0-9A-Fa-f:]{17})\s*(.*)$/);
            if (m)
                names[m[1].toUpperCase()] = m[2].trim();
        }

        const list = [];
        for (const key of Object.keys(names)) {
            const name = names[key] ?? "";
            const isPaired = paired[key] === true;
            const isConnected = connected[key] === true;
            // bluez names unseen devices after their address; those are only
            // worth showing once they are actually paired
            if (!isPaired && !isConnected && /^([0-9A-F]{2}-){5}[0-9A-F]{2}$/.test(name))
                continue;
            list.push({
                "mac": key,
                "name": name.length > 0 ? name : key,
                "paired": isPaired,
                "connected": isConnected
            });
        }
        for (const key of Object.keys(connected)) {
            if (!list.some(d => d.mac === key))
                list.push({
                    "mac": key,
                    "name": key,
                    "paired": paired[key] === true,
                    "connected": true
                });
        }

        list.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return a.name.localeCompare(b.name);
        });

        available = hasAdapter;
        powered = isPowered;
        discovering = isDiscovering;

        const signature = list.map(d => d.mac + "|" + d.name + "|" + (d.paired ? 1 : 0) + "|" + (d.connected ? 1 : 0)).join("\n");
        if (signature !== _signature) {
            _signature = signature;
            devices = list;
        }

        // a vanished adapter means scanning cannot make progress either
        if (!hasAdapter && wantScan)
            setScanning(false);
    }

    function refresh(): void {
        if (infoProc.running)
            return;
        infoProc.running = true;
    }

    function setScanning(wanted: bool): void {
        wantScan = wanted;
        if (wanted) {
            refresh();
            if (powered && available && !scanProc.running)
                scanProc.running = true;
        } else {
            if (scanProc.running)
                scanProc.running = false;
            scanTimer.stop();
            refresh();
        }
    }

    function togglePower(): void {
        if (!available || busy)
            return;
        const on = !powered;
        if (!on)
            setScanning(false);
        _run("timeout 10 bluetoothctl power " + (on ? "on" : "off") + " < /dev/null");
    }

    function connect(mac: string, alreadyPaired: bool): void {
        if (busy)
            return;
        const steps = [];
        if (!alreadyPaired)
            steps.push("timeout 30 bluetoothctl pair " + mac + " < /dev/null");
        steps.push("timeout 10 bluetoothctl trust " + mac + " < /dev/null");
        steps.push("timeout 25 bluetoothctl connect " + mac + " < /dev/null");
        _run(steps.join("; "));
    }

    function disconnect(mac: string): void {
        if (busy)
            return;
        _run("timeout 15 bluetoothctl disconnect " + mac + " < /dev/null");
    }

    function forget(mac: string): void {
        if (busy)
            return;
        _run("timeout 10 bluetoothctl disconnect " + mac + " < /dev/null; timeout 10 bluetoothctl remove " + mac + " < /dev/null");
    }

    function toggleDevice(device: var): void {
        if (!device || busy)
            return;
        if (device.connected)
            disconnect(device.mac);
        else
            connect(device.mac, device.paired);
    }

    function _run(script: string): void {
        if (actionProc.running)
            return;
        busy = true;
        message = "";
        messageError = false;
        actionProc.command = ["sh", "-c", script];
        actionProc.running = true;
    }

    function _actionFinished(raw: string): void {
        busy = false;
        const lines = _clean(raw).split("\n").map(l => l.trim()).filter(l => l.length > 0);
        const bad = lines.find(l => /failed|error|not available|invalid|not found|no such/i.test(l));
        if (bad) {
            message = bad.toUpperCase().slice(0, 64);
            messageError = true;
            messageTimer.restart();
        }
        refresh();
    }

    function clearMessage(): void {
        message = "";
        messageError = false;
    }

    Process {
        id: infoProc

        command: ["sh", "-c", "if ! command -v bluetoothctl >/dev/null 2>&1; then exit 0; fi; timeout 6 bluetoothctl show </dev/null | grep -E 'Controller |Powered:|Discovering:'; echo '@@'; timeout 6 bluetoothctl devices </dev/null; echo '@@'; timeout 6 bluetoothctl devices Paired </dev/null; echo '@@'; timeout 6 bluetoothctl devices Connected </dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root._ingest(text)
        }
    }

    Process {
        id: actionProc

        stdout: StdioCollector {
            onStreamFinished: root._actionFinished(text)
        }
    }

    // one long discovery session per panel visit: restarting it would purge
    // bluez's device cache in between and make the list flicker. `exec` keeps
    // bluetoothctl as the direct child, so closing the panel kills the scan
    // and bluez stops discovery when its last client goes away.
    Process {
        id: scanProc

        command: ["sh", "-c", "exec bluetoothctl --timeout 900 scan on < /dev/null"]

        onExited: {
            if (root.wantScan && root.powered)
                scanTimer.restart();
        }
    }

    Timer {
        id: scanTimer

        interval: 300
        onTriggered: {
            if (root.wantScan && root.powered && !scanProc.running)
                scanProc.running = true;
        }
    }

    Timer {
        id: messageTimer

        interval: 5000
        onTriggered: root.clearMessage()
    }

    // 2s while the panel is open, a lazy 20s otherwise (the bar only needs
    // the connected device name)
    Timer {
        interval: root.wantScan ? 2000 : 20000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: root.refresh()
    }

    onPoweredChanged: {
        if (!powered && wantScan)
            setScanning(false);
        else if (powered && wantScan && !scanProc.running)
            scanProc.running = true;
    }

    Component.onCompleted: refresh()
}
