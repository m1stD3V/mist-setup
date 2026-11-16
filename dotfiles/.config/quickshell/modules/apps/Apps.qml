pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Theme
import qs.components
import qs.services

// Task-manager style panel: sortable process list with details,
// open windows, and live performance graphs.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool onFocused: {
        const fm = Hypr.focusedMonitor;
        return !!fm && fm.name === (Hypr.monitorFor(modelData)?.name ?? "");
    }
    readonly property bool showHere: ShellState.appsOpen && onFocused
    readonly property int frameWidth: 700
    readonly property int frameHeight: 600

    property string mode: "processes"
    property var windows: []

    property string procFilter: ""
    property string procSort: "cpu"
    property bool procDesc: true
    property var procView: []
    property int selectedPid: -1
    property string selectedCmd: ""

    property int confirmPid: 0
    property string confirmAction: ""

    property var cpuHistory: []
    property var memHistory: []
    property var gpuHistory: []
    property var netHistory: []
    property var diskHistory: []

    readonly property var selectedProc: root.selectedPid > 0 ? (Processes.list.find(p => p.pid === root.selectedPid) ?? null) : null

    readonly property var topCpu: {
        const a = Processes.list.slice();
        a.sort((x, y) => y.cpu - x.cpu);
        return a.slice(0, 5);
    }
    readonly property var topMem: {
        const a = Processes.list.slice();
        a.sort((x, y) => y.rssKB - x.rssKB);
        return a.slice(0, 5);
    }
    readonly property var sysInfo: [{
            "k": "HOST",
            "v": (Host.hostname || "-").toUpperCase()
        }, {
            "k": "OS",
            "v": (Host.distro || "-").toUpperCase()
        }, {
            "k": "KERNEL",
            "v": Host.kernel || "-"
        }, {
            "k": "UPTIME",
            "v": Host.formatUptime(Host.uptime).toUpperCase()
        }, {
            "k": "WINDOWS",
            "v": String(root.windows.length)
        }, {
            "k": "PROCESSES",
            "v": String(Processes.list.length)
        }, {
            "k": "BATTERY",
            "v": Host.batteryPresent ? Math.round(Host.batteryPct * 100) + "%" : "N/A"
        }]

    screen: modelData
    visible: showHere
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "#b0050505"
    focusable: showHere

    WlrLayershell.layer: WlrLayer.Overlay

    onShowHereChanged: {
        Processes.active = showHere;
        updatePerfActive();
        if (showHere) {
            mode = ShellState.appsTab;
            refreshWindows();
            Processes.refresh();
        }
    }

    onModeChanged: updatePerfActive()

    onProcFilterChanged: rebuildProcView()

    Component.onCompleted: {
        seedHistory();
        if (showHere) {
            Processes.active = true;
            mode = ShellState.appsTab;
            refreshWindows();
            Processes.refresh();
        }
        updatePerfActive();
    }

    function updatePerfActive(): void {
        const on = showHere && mode === "performance";
        Gpu.active = on;
        Network.active = on;
        Disk.active = on;
    }

    // ---- windows ----
    function addressOf(win: var): string {
        const ipcAddr = win?.lastIpcObject?.address;
        if (ipcAddr)
            return ipcAddr;
        const raw = win?.address ?? "";
        return raw.length > 0 && !raw.startsWith("0x") ? "0x" + raw : raw;
    }

    function classOf(win: var): string {
        return String(win?.lastIpcObject?.class ?? win?.class ?? "");
    }

    function titleOf(win: var): string {
        return String(win?.lastIpcObject?.title ?? win?.title ?? "");
    }

    function wsOf(win: var): int {
        return win?.lastIpcObject?.workspace?.id ?? win?.workspace?.id ?? 0;
    }

    function pidOf(win: var): int {
        return win?.lastIpcObject?.pid ?? -1;
    }

    function procOf(win: var): var {
        const pid = pidOf(win);
        return pid > 0 ? (Processes.list.find(p => p.pid === pid) ?? null) : null;
    }

    function refreshWindows(): void {
        const list = Hypr.toplevels.values.slice();
        list.sort((a, b) => {
            const wa = root.wsOf(a);
            const wb = root.wsOf(b);
            if (wa !== wb)
                return wa - wb;
            return root.classOf(a).localeCompare(root.classOf(b));
        });
        windows = list;
    }

    function focusWindow(win: var): void {
        const addr = addressOf(win);
        if (addr.length > 0)
            Hypr.dispatch("focuswindow address:" + addr);
        ShellState.appsOpen = false;
    }

    function closeWindow(win: var): void {
        const addr = addressOf(win);
        if (addr.length > 0)
            Hypr.dispatch("closewindow address:" + addr);
        refreshWindows();
    }

    // ---- processes ----
    function statusText(stat: string): string {
        switch (stat.charAt(0)) {
        case "R":
            return "RUNNING";
        case "S":
            return "SLEEPING";
        case "D":
            return "WAITING";
        case "T":
            return "STOPPED";
        case "Z":
            return "ZOMBIE";
        default:
            return "IDLE";
        }
    }

    function memoryMB(row: var): string {
        return (row.rssKB / 1024).toFixed(1) + " MB";
    }

    function elapsedText(secs: int): string {
        const d = Math.floor(secs / 86400);
        const h = Math.floor((secs % 86400) / 3600);
        const m = Math.floor((secs % 3600) / 60);
        if (d > 0)
            return d + "d " + h + "h";
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    function setProcSort(key: string): void {
        if (procSort === key) {
            procDesc = !procDesc;
        } else {
            procSort = key;
            procDesc = key === "cpu" || key === "mem" || key === "rss" || key === "pid";
        }
        rebuildProcView();
    }

    function rebuildProcView(): void {
        const scrollY = procList ? procList.contentY : 0;
        const q = procFilter.trim().toLowerCase();
        const arr = Processes.list.filter(p => q.length === 0 || p.name.toLowerCase().includes(q) || String(p.pid).includes(q) || p.user.toLowerCase().includes(q));
        const dir = procDesc ? -1 : 1;
        arr.sort((a, b) => {
            switch (procSort) {
            case "name":
                return dir * a.name.localeCompare(b.name);
            case "user":
                return dir * a.user.localeCompare(b.user);
            case "pid":
                return dir * (a.pid - b.pid);
            case "mem":
                return dir * (a.mem - b.mem);
            case "rss":
                return dir * (a.rssKB - b.rssKB);
            case "status":
                return dir * a.status.localeCompare(b.status);
            default:
                return dir * (a.cpu - b.cpu);
            }
        });
        procView = arr;
        if (procList)
            Qt.callLater(() => {
                procList.contentY = scrollY;
            });
    }

    function selectProcess(pid: int): void {
        selectedPid = pid;
        selectedCmd = "";
        cmdProc.pid = pid;
        cmdProc.running = false;
        if (pid > 0)
            cmdProc.running = true;
    }

    function requestKill(pid: int, force: bool): void {
        const action = force ? "force" : "end";
        if (confirmPid === pid && confirmAction === action) {
            if (force)
                Processes.forceKill(pid);
            else
                Processes.kill(pid);
            confirmPid = 0;
            confirmAction = "";
            if (selectedPid === pid) {
                selectedPid = -1;
                selectedCmd = "";
            }
        } else {
            confirmPid = pid;
            confirmAction = action;
            confirmTimer.restart();
        }
    }

    // ---- performance history ----
    function seedHistory(): void {
        const zeros = [];
        for (let i = 0; i < 60; ++i)
            zeros.push(0);
        cpuHistory = zeros;
        memHistory = zeros.slice();
        gpuHistory = zeros.slice();
        netHistory = zeros.slice();
        diskHistory = zeros.slice();
    }

    function sampleHistory(): void {
        const c = cpuHistory.slice(1);
        c.push(Host.cpu);
        const m = memHistory.slice(1);
        m.push(Host.mem);
        const g = gpuHistory.slice(1);
        g.push(Gpu.present ? Gpu.usage : 0);
        const n = netHistory.slice(1);
        n.push(logScale(Network.rxBps + Network.txBps, 8));
        const d = diskHistory.slice(1);
        d.push(logScale(Disk.readBps + Disk.writeBps, 9));
        cpuHistory = c;
        memHistory = m;
        gpuHistory = g;
        netHistory = n;
        diskHistory = d;
    }

    function logScale(v: real, maxExp: real): real {
        return Math.min(1, Math.log10(1 + Math.max(0, v)) / maxExp);
    }

    function rateText(bps: real): string {
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(1) + " MB/s";
        if (bps >= 1024)
            return Math.round(bps / 1024) + " KB/s";
        return Math.round(bps) + " B/s";
    }

    MouseArea {
        anchors.fill: parent

        onClicked: ShellState.appsOpen = false
    }

    Shortcut {
        sequences: ["Escape"]

        onActivated: ShellState.appsOpen = false
    }

    Timer {
        interval: 500
        repeat: true
        running: showHere
        triggeredOnStart: true

        onTriggered: root.refreshWindows()
    }

    Timer {
        interval: 2000
        repeat: true
        running: showHere && root.mode === "performance"
        triggeredOnStart: true

        onTriggered: root.sampleHistory()
    }

    Timer {
        id: confirmTimer

        interval: 3000

        onTriggered: {
            root.confirmPid = 0;
            root.confirmAction = "";
        }
    }

    Connections {
        target: Processes

        function onListChanged(): void {
            root.rebuildProcView();
        }
    }

    Process {
        id: cmdProc

        property int pid: 0

        command: pid > 0 ? ["sh", "-c", "tr '\\0' ' ' < /proc/" + pid + "/cmdline"] : ["true"]
        stdout: StdioCollector {
            onStreamFinished: root.selectedCmd = text.trim()
        }
    }

    Box {
        anchors.centerIn: parent
        width: root.frameWidth
        height: root.frameHeight
        title: "TASK MANAGER"
        focus: root.showHere

        Column {
            anchors.fill: parent
            spacing: 6

            Row {
                width: parent.width
                spacing: 4

                TextButton {
                    label: "PROCESSES " + Processes.list.length
                    active: root.mode === "processes"
                    onClicked: root.mode = "processes"
                }

                TextButton {
                    label: "WINDOWS " + root.windows.length
                    active: root.mode === "windows"
                    onClicked: root.mode = "windows"
                }

                TextButton {
                    label: "PERFORMANCE"
                    active: root.mode === "performance"
                    onClicked: root.mode = "performance"
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Item {
                width: parent.width
                height: parent.height - 39

                // ================= PROCESSES =================
                Column {
                    anchors.fill: parent
                    spacing: 4
                    visible: root.mode === "processes"

                    RowLayout {
                        width: parent.width
                        height: 28
                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: 240
                            height: 26
                            color: Theme.surfaceHigh
                            border.width: 1
                            border.color: search.activeFocus ? Theme.textHigh : Theme.borderHigh

                            TextInput {
                                id: search

                                anchors.fill: parent
                                anchors.margins: 3
                                color: Theme.text
                                font.family: Theme.family
                                font.pixelSize: Theme.fontSmall
                                selectByMouse: true
                                clip: true

                                onTextChanged: root.procFilter = text

                                Keys.onEscapePressed: {
                                    text = "";
                                    root.procFilter = "";
                                }
                            }

                            RText {
                                visible: search.text.length === 0
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: "FILTER NAME / PID / USER"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontExtraSmall + 2
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        RText {
                            text: root.procView.length + " / " + Processes.list.length + " PROCESSES"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }
                    }

                    RowLayout {
                        x: 4
                        width: parent.width - 8
                        height: 18
                        spacing: 6

                        TableHeader {
                            Layout.fillWidth: true
                            label: "NAME"
                            active: root.procSort === "name"
                            descending: root.procDesc
                            onClicked: root.setProcSort("name")
                        }

                        TableHeader {
                            Layout.preferredWidth: 78
                            label: "USER"
                            active: root.procSort === "user"
                            descending: root.procDesc
                            onClicked: root.setProcSort("user")
                        }

                        TableHeader {
                            Layout.preferredWidth: 64
                            label: "PID"
                            numeric: true
                            active: root.procSort === "pid"
                            descending: root.procDesc
                            onClicked: root.setProcSort("pid")
                        }

                        TableHeader {
                            Layout.preferredWidth: 52
                            label: "CPU"
                            numeric: true
                            active: root.procSort === "cpu"
                            descending: root.procDesc
                            onClicked: root.setProcSort("cpu")
                        }

                        TableHeader {
                            Layout.preferredWidth: 52
                            label: "MEM"
                            numeric: true
                            active: root.procSort === "mem"
                            descending: root.procDesc
                            onClicked: root.setProcSort("mem")
                        }

                        TableHeader {
                            Layout.preferredWidth: 76
                            label: "RSS"
                            numeric: true
                            active: root.procSort === "rss"
                            descending: root.procDesc
                            onClicked: root.setProcSort("rss")
                        }

                        TableHeader {
                            Layout.preferredWidth: 74
                            label: "STATUS"
                            active: root.procSort === "status"
                            descending: root.procDesc
                            onClicked: root.setProcSort("status")
                        }
                    }

                    ListView {
                        id: procList

                        width: parent.width
                        height: parent.height - 152
                        clip: true
                        spacing: 1
                        model: root.procView

                        delegate: Item {
                            id: procRow

                            required property var modelData

                            readonly property bool selected: root.selectedPid === procRow.modelData.pid

                            width: ListView.view.width
                            height: 27

                            Rectangle {
                                anchors.fill: parent
                                color: procRow.selected ? Theme.surfaceHigh : (procHover.hovered ? Theme.surface : "transparent")
                            }

                            HoverHandler {
                                id: procHover
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 6

                                RText {
                                    Layout.fillWidth: true
                                    text: procRow.modelData.name
                                    color: procRow.selected ? Theme.textHigh : Theme.text
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSmall
                                }

                                RText {
                                    Layout.preferredWidth: 78
                                    text: procRow.modelData.user
                                    color: Theme.textDim
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                RText {
                                    Layout.preferredWidth: 64
                                    text: procRow.modelData.pid
                                    color: Theme.textMuted
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                RText {
                                    Layout.preferredWidth: 52
                                    text: Math.round(procRow.modelData.cpu) + "%"
                                    color: procRow.modelData.cpu >= 20 ? Theme.textHigh : Theme.textDim
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                RText {
                                    Layout.preferredWidth: 52
                                    text: Math.round(procRow.modelData.mem) + "%"
                                    color: Theme.textDim
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                RText {
                                    Layout.preferredWidth: 76
                                    text: (procRow.modelData.rssKB / 1024).toFixed(1)
                                    color: Theme.textDim
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                RText {
                                    Layout.preferredWidth: 74
                                    text: root.statusText(procRow.modelData.status)
                                    color: procRow.modelData.status.charAt(0) === "R" ? Theme.textHigh : Theme.textMuted
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontExtraSmall
                                }
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: root.selectProcess(procRow.modelData.pid)
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 92
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.border

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 3

                            RowLayout {
                                width: parent.width

                                RText {
                                    Layout.fillWidth: true
                                    text: root.selectedProc ? root.selectedProc.name.toUpperCase() : "NO PROCESS SELECTED"
                                    color: root.selectedProc ? Theme.textHigh : Theme.textMuted
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSmall + 2
                                }

                                TextButton {
                                    visible: !!root.selectedProc
                                    label: root.confirmPid === root.selectedPid && root.confirmAction === "end" ? "SURE" : "END"
                                    danger: true
                                    onClicked: root.requestKill(root.selectedPid, false)
                                }

                                TextButton {
                                    visible: !!root.selectedProc
                                    label: root.confirmPid === root.selectedPid && root.confirmAction === "force" ? "SURE" : "FORCE"
                                    danger: true
                                    onClicked: root.requestKill(root.selectedPid, true)
                                }
                            }

                            RText {
                                width: parent.width
                                visible: !!root.selectedProc
                                text: {
                                    const p = root.selectedProc;
                                    if (!p)
                                        return "";
                                    return "PID " + p.pid + "   PPID " + p.ppid + "   USER " + p.user + "   " + root.statusText(p.status) + "   THREADS " + p.threads + "   " + root.memoryMB(p) + "   UP " + root.elapsedText(p.elapsed);
                                }
                                color: Theme.textDim
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontExtraSmall
                            }

                            RText {
                                width: parent.width
                                text: root.selectedProc ? (root.selectedCmd.length > 0 ? root.selectedCmd : "[NO COMMAND LINE AVAILABLE]") : "SELECT A PROCESS TO INSPECT IT"
                                color: Theme.textMuted
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontExtraSmall
                            }
                        }
                    }
                }

                // ================= WINDOWS =================
                Column {
                    anchors.fill: parent
                    spacing: 4
                    visible: root.mode === "windows"

                    RowLayout {
                        x: 4
                        width: parent.width - 8
                        height: 18
                        spacing: 6

                        RText {
                            Layout.preferredWidth: 44
                            text: "WS"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        RText {
                            Layout.preferredWidth: 130
                            text: "APP"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        RText {
                            Layout.fillWidth: true
                            text: "TITLE"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        RText {
                            Layout.preferredWidth: 60
                            text: "PID"
                            color: Theme.textMuted
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        RText {
                            Layout.preferredWidth: 45
                            text: "CPU"
                            color: Theme.textMuted
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        RText {
                            Layout.preferredWidth: 50
                            text: "MEM"
                            color: Theme.textMuted
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.fontExtraSmall + 2
                        }

                        Item {
                            Layout.preferredWidth: 96
                        }
                    }

                    ListView {
                        width: parent.width
                        height: parent.height - 22
                        clip: true
                        spacing: 2
                        model: root.windows

                        delegate: Item {
                            id: winRow

                            required property var modelData

                            readonly property string addr: root.addressOf(winRow.modelData)
                            readonly property bool isActive: addr.length > 0 && addr === root.addressOf(Hypr.activeToplevel)
                            readonly property var proc: root.procOf(winRow.modelData)
                            readonly property int pid: root.pidOf(winRow.modelData)

                            width: ListView.view.width
                            height: 34

                            Rectangle {
                                anchors.fill: parent
                                color: winRow.isActive ? Theme.surfaceHigh : (winHover.hovered ? Theme.surface : "transparent")
                            }

                            HoverHandler {
                                id: winHover
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 6

                                RText {
                                    Layout.preferredWidth: 44
                                    text: "WS" + root.wsOf(winRow.modelData)
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                RText {
                                    Layout.preferredWidth: 130
                                    text: root.classOf(winRow.modelData).toUpperCase()
                                    color: winRow.isActive ? Theme.textHigh : Theme.text
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSmall
                                }

                                RText {
                                    Layout.fillWidth: true
                                    text: root.titleOf(winRow.modelData)
                                    color: Theme.textDim
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSmall
                                }

                                RText {
                                    Layout.preferredWidth: 60
                                    text: winRow.pid > 0 ? winRow.pid : "-"
                                    color: Theme.textMuted
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                RText {
                                    Layout.preferredWidth: 45
                                    text: winRow.proc ? Math.round(winRow.proc.cpu) + "%" : "-"
                                    color: winRow.proc && winRow.proc.cpu >= 20 ? Theme.textHigh : Theme.textDim
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                RText {
                                    Layout.preferredWidth: 50
                                    text: winRow.proc ? (winRow.proc.rssKB / 1024).toFixed(0) : "-"
                                    color: Theme.textDim
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: Theme.fontExtraSmall
                                }

                                Item {
                                    Layout.preferredWidth: 96
                                    Layout.preferredHeight: 22

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        TextButton {
                                            visible: winRow.pid > 0
                                            label: root.confirmPid === winRow.pid && root.confirmAction === "end" ? "SURE" : "END"
                                            danger: true
                                            onClicked: root.requestKill(winRow.pid, false)
                                        }

                                        TextButton {
                                            label: "X"
                                            danger: true
                                            onClicked: root.closeWindow(winRow.modelData)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 100
                                cursorShape: Qt.PointingHandCursor

                                onClicked: root.focusWindow(winRow.modelData)
                            }
                        }
                    }
                }

                // ================= PERFORMANCE =================
                Column {
                    anchors.fill: parent
                    spacing: 8
                    visible: root.mode === "performance"

                    Row {
                        width: parent.width
                        spacing: 8

                        PerfPanel {
                            width: (parent.width - 16) / 3
                            height: 175
                            title: "CPU"
                            value: Math.round(Host.cpu * 100) + "%"
                            values: root.cpuHistory
                            graphColor: Theme.accent
                            detail1: (Host.cpuFreqMHz > 0 ? Host.cpuFreqMHz + " MHZ  ·  " : "") + Host.cpuCores + " THREADS"
                            detail2: "LOAD " + Host.load1.toFixed(2) + "  " + Host.load5.toFixed(2) + "  " + Host.load15.toFixed(2)
                        }

                        PerfPanel {
                            width: (parent.width - 16) / 3
                            height: 175
                            title: "MEMORY"
                            value: Math.round(Host.mem * 100) + "%"
                            values: root.memHistory
                            graphColor: Theme.textDim
                            detail1: Host.memUsedGB.toFixed(1) + " / " + Host.memTotalGB.toFixed(1) + " GB USED"
                            detail2: (Host.memAvailKB / 1048576).toFixed(1) + " GB AVAILABLE"
                        }

                        PerfPanel {
                            width: (parent.width - 16) / 3
                            height: 175
                            title: "GPU"
                            value: Gpu.present ? Math.round(Gpu.usage * 100) + "%" : "--"
                            values: root.gpuHistory
                            graphColor: Theme.textHigh
                            detail1: Gpu.present ? (Math.round(Gpu.tempC) + " C  ·  " + Gpu.powerW.toFixed(0) + " W  ·  " + Math.round(Gpu.sclkMHz) + " MHZ") : "NO GPU DETECTED"
                            detail2: Gpu.present ? ("VRAM " + Gpu.vramUsedGB.toFixed(1) + " / " + Gpu.vramTotalGB.toFixed(1) + " GB") : ""
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        PerfPanel {
                            width: (parent.width - 16) / 3
                            height: 175
                            title: "NETWORK"
                            value: root.rateText(Network.rxBps + Network.txBps)
                            values: root.netHistory
                            graphColor: Theme.textHigh
                            detail1: "RX " + root.rateText(Network.rxBps) + "   TX " + root.rateText(Network.txBps)
                            detail2: (Network.iface || "-").toUpperCase()
                        }

                        PerfPanel {
                            width: (parent.width - 16) / 3
                            height: 175
                            title: "DISK"
                            value: root.rateText(Disk.readBps + Disk.writeBps)
                            values: root.diskHistory
                            graphColor: Theme.textDim
                            detail1: "READ " + root.rateText(Disk.readBps) + "   WRITE " + root.rateText(Disk.writeBps)
                            detail2: "PHYSICAL DISK THROUGHPUT"
                        }

                        Rectangle {
                            width: (parent.width - 16) / 3
                            height: 175
                            color: Theme.surface
                            border.width: 1
                            border.color: Theme.border

                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 2

                                RText {
                                    text: "SYSTEM"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontSmall
                                }

                                Repeater {
                                    model: root.sysInfo

                                    delegate: Row {
                                        required property var modelData

                                        width: parent.width
                                        spacing: 4

                                        RText {
                                            width: 62
                                            text: parent.modelData.k
                                            color: Theme.textMuted
                                            font.pixelSize: Theme.fontExtraSmall
                                        }

                                        RText {
                                            width: parent.width - 66
                                            text: parent.modelData.v
                                            color: Theme.textDim
                                            elide: Text.ElideRight
                                            font.pixelSize: Theme.fontExtraSmall
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 16

                        Column {
                            Layout.fillWidth: true
                            spacing: 3

                            RText {
                                text: "TOP CPU"
                                color: Theme.textHigh
                                font.pixelSize: Theme.fontSmall
                            }

                            Repeater {
                                model: root.topCpu

                                delegate: Row {
                                    required property var modelData

                                    width: parent.width
                                    spacing: 4

                                    RText {
                                        width: parent.width - 44
                                        text: parent.modelData.name
                                        color: Theme.textDim
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontExtraSmall
                                    }

                                    RText {
                                        text: Math.round(parent.modelData.cpu) + "%"
                                        color: Theme.textHigh
                                        font.pixelSize: Theme.fontExtraSmall
                                    }
                                }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 3

                            RText {
                                text: "TOP MEMORY"
                                color: Theme.textHigh
                                font.pixelSize: Theme.fontSmall
                            }

                            Repeater {
                                model: root.topMem

                                delegate: Row {
                                    required property var modelData

                                    width: parent.width
                                    spacing: 4

                                    RText {
                                        width: parent.width - 64
                                        text: parent.modelData.name
                                        color: Theme.textDim
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontExtraSmall
                                    }

                                    RText {
                                        text: (parent.modelData.rssKB / 1024).toFixed(0) + "M"
                                        color: Theme.textHigh
                                        font.pixelSize: Theme.fontExtraSmall
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
