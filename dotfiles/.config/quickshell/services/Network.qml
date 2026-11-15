pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Aggregate network throughput for the default-route interface, plus the
// NetworkManager state used by the bar's connection panel: device lists,
// Wi-Fi scanning, connect/disconnect and saved-profile handling.
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

    // ---- connection management (NetworkManager) ----
    readonly property bool available: Networking.backend !== NetworkBackendType.None

    readonly property var wifiDevice: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi)
                return d;
        }
        return null;
    }

    readonly property var wiredDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property bool wifiAvailable: wifiDevice !== null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool wifiHardwareOn: Networking.wifiHardwareEnabled

    readonly property var activeWifi: {
        const d = wifiDevice;
        if (d) {
            for (const n of d.networks.values) {
                if (n.connected)
                    return n;
            }
        }
        return null;
    }

    readonly property var activeWired: {
        for (const d of wiredDevices) {
            if (d.connected)
                return d;
        }
        return null;
    }

    readonly property bool online: activeWifi !== null || activeWired !== null

    readonly property string statusText: {
        if (!available)
            return "N/A";
        if (activeWifi)
            return activeWifi.name.toUpperCase();
        if (activeWired)
            return "WIRED";
        if (!wifiAvailable)
            return "OFFLINE";
        if (!wifiOn)
            return "WI-FI OFF";
        return "DISCONNECTED";
    }

    // compact label for the overflow menu's right-hand hint
    readonly property string menuHint: {
        if (!available)
            return "N/A";
        if (activeWifi) {
            const name = activeWifi.name.toUpperCase();
            const short = name.length > 12 ? name.slice(0, 12) : name;
            return short + " " + Math.round(activeWifi.signalStrength * 100) + "%";
        }
        return statusText;
    }

    // Cached so scans updating signal strength do not rebuild the list model.
    property var wifiNetworks: []
    property bool scanDesired: false
    property string _wifiSignature: ""

    function refreshWifiNetworks(): void {
        const d = wifiDevice;
        const list = d && wifiOn ? d.networks.values.slice() : [];
        list.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return a.name.localeCompare(b.name);
        });

        const signature = list.map(n => n.name + "|" + (n.connected ? 1 : 0) + "|" + (n.known ? 1 : 0) + "|" + n.state).join("\n");
        if (signature === _wifiSignature)
            return;
        _wifiSignature = signature;
        wifiNetworks = list;
    }

    function toggleWifi(): void {
        if (!available || !wifiAvailable)
            return;
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // Scanning is only wanted while the panel is open.
    function setScanning(wanted: bool): void {
        scanDesired = wanted;
        if (wanted)
            refreshWifiNetworks();
        const d = wifiDevice;
        if (d)
            d.scannerEnabled = wanted && Networking.wifiEnabled;
    }

    function rescan(): void {
        const d = wifiDevice;
        if (!d || !wifiOn)
            return;
        d.scannerEnabled = false;
        rescanTimer.restart();
    }

    function isSecured(network: var): bool {
        if (!network)
            return false;
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    function isEnterprise(network: var): bool {
        if (!network)
            return false;
        const s = network.security;
        return s === WifiSecurityType.Wpa2Eap || s === WifiSecurityType.WpaEap || s === WifiSecurityType.Leap;
    }

    function needsPassword(network: var): bool {
        return isSecured(network) && !isEnterprise(network) && !(network?.known ?? false);
    }

    function minPasswordLength(network: var): int {
        if (!network)
            return 8;
        const s = network.security;
        if (s === WifiSecurityType.StaticWep || s === WifiSecurityType.DynamicWep)
            return 5;
        return 8;
    }

    function activate(network: var): void {
        if (!network || network.stateChanging)
            return;
        if (network.connected) {
            network.disconnect();
        } else if (network.known || !isSecured(network)) {
            network.connect();
        }
    }

    function connectWithPassword(network: var, psk: string): void {
        if (network && psk.length > 0)
            network.connectWithPsk(psk);
    }

    function forget(network: var): void {
        if (network?.known)
            network.forget();
    }

    function toggleWired(device: var): void {
        if (!device)
            return;
        if (device.connected)
            device.disconnect();
        else if (device.network)
            device.network.connect();
    }

    function securityLabel(network: var): string {
        if (!network)
            return "";
        switch (network.security) {
        case WifiSecurityType.Open:
            return "OPEN";
        case WifiSecurityType.Owe:
            return "OWE";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.Sae:
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP";
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap:
            return "802.1X";
        case WifiSecurityType.Leap:
            return "LEAP";
        default:
            return "";
        }
    }

    function stateLabel(network: var): string {
        if (!network)
            return "";
        if (network.state === ConnectionState.Connecting)
            return "CONNECTING";
        if (network.state === ConnectionState.Disconnecting)
            return "DISCONNECTING";
        return "";
    }

    function reasonLabel(reason: int): string {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return "PASSWORD REQUIRED";
        case ConnectionFailReason.WifiAuthTimeout:
        case ConnectionFailReason.WifiClientFailed:
            return "AUTHENTICATION FAILED";
        case ConnectionFailReason.WifiNetworkLost:
            return "NETWORK LOST";
        case ConnectionFailReason.WifiClientDisconnected:
            return "CONNECTION DROPPED";
        default:
            return "CONNECTION FAILED";
        }
    }

    Connections {
        function onValuesChanged(): void {
            root.refreshWifiNetworks();
        }

        target: Networking.devices
    }

    Connections {
        function onValuesChanged(): void {
            root.refreshWifiNetworks();
        }

        target: root.wifiDevice ? root.wifiDevice.networks : null
    }

    Connections {
        function onWifiEnabledChanged(): void {
            root.refreshWifiNetworks();
            if (root.scanDesired)
                root.setScanning(true);
        }

        target: Networking
    }

    Timer {
        id: rescanTimer

        interval: 300
        onTriggered: {
            if (root.scanDesired && root.wifiDevice && Networking.wifiEnabled)
                root.wifiDevice.scannerEnabled = true;
        }
    }

    // keep the visible list's ordering fresh while its panel is open
    Timer {
        interval: 2000
        repeat: true
        running: root.scanDesired
        onTriggered: root.refreshWifiNetworks()
    }

    Timer {
        interval: 1500
        repeat: true
        running: root.scanDesired
        onTriggered: {
            const d = root.wifiDevice;
            if (d && Networking.wifiEnabled && !d.scannerEnabled)
                d.scannerEnabled = true;
        }
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
